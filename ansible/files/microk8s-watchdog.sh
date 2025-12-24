#!/bin/bash
# =============================================================================
# MicroK8s Watchdog Script
# =============================================================================
# Monitors MicroK8s cluster health and auto-recovers from common issues:
# - MicroK8s stopped
# - Node NotReady (containerd issues)
# - Stuck pods in Unknown/Failed state
#
# Logs to: /var/log/microk8s-watchdog.log
# =============================================================================

LOG=/var/log/microk8s-watchdog.log

log() {
    echo "$(date "+%Y-%m-%d %H:%M:%S") - $1" >> $LOG
}

restart_cluster() {
    log "Attempting cluster recovery..."
    snap restart microk8s
    sleep 60
    snap restart microk8s.daemon-containerd
    sleep 30
}

check_node_ready() {
    microk8s kubectl get nodes --no-headers 2>/dev/null | grep -q " Ready"
}

check_critical_pods() {
    # Check if critical namespaces have too many unhealthy pods
    local failed=0
    for ns in sentry fundamental-dev fundamental-prod; do
        pending=$(microk8s kubectl get pods -n $ns --no-headers 2>/dev/null | grep -cE "Pending|Unknown|Error" || echo "0")
        if [ "$pending" -gt 2 ]; then
            log "Namespace $ns has $pending unhealthy pods"
            failed=1
        fi
    done
    return $failed
}

fix_stuck_pods() {
    log "Cleaning stuck pods..."
    for ns in sentry fundamental-dev fundamental-prod; do
        # Delete pods stuck in Unknown state (typically after node restart)
        microk8s kubectl delete pods -n $ns --field-selector=status.phase=Unknown --force --grace-period=0 2>/dev/null
        # Delete pods in Failed state
        microk8s kubectl delete pods -n $ns --field-selector=status.phase=Failed --force --grace-period=0 2>/dev/null
    done
}

check_kafka_health() {
    # Check for Kafka cluster ID mismatch (common after Zookeeper data loss)
    local kafka_pod=$(microk8s kubectl get pods -n sentry -l app=sentry-kafka -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$kafka_pod" ]; then
        local kafka_status=$(microk8s kubectl get pod $kafka_pod -n sentry -o jsonpath='{.status.phase}' 2>/dev/null)
        if [ "$kafka_status" = "Error" ] || [ "$kafka_status" = "CrashLoopBackOff" ]; then
            local logs=$(microk8s kubectl logs $kafka_pod -n sentry --tail=10 2>/dev/null)
            if echo "$logs" | grep -q "InconsistentClusterIdException"; then
                log "Kafka cluster ID mismatch detected, clearing meta.properties..."
                local pv_path=$(find /var/snap/microk8s/common/default-storage -name "meta.properties" -path "*kafka*" 2>/dev/null | head -1)
                if [ -n "$pv_path" ]; then
                    rm -f "$pv_path"
                    microk8s kubectl delete pod $kafka_pod -n sentry --force --grace-period=0
                    log "Kafka meta.properties cleared and pod restarted"
                fi
            fi
        fi
    fi
}

log "Watchdog started"

while true; do
    # Check 1: Is MicroK8s running?
    if ! microk8s status 2>/dev/null | grep -q "microk8s is running"; then
        log "ERROR: MicroK8s is not running!"
        restart_cluster
        sleep 120
        continue
    fi

    # Check 2: Is node Ready?
    if ! check_node_ready; then
        log "ERROR: Node is NotReady!"
        snap restart microk8s.daemon-containerd
        sleep 60
        if ! check_node_ready; then
            log "Node still NotReady after containerd restart, doing full restart..."
            restart_cluster
        fi
        sleep 120
        continue
    fi

    # Check 3: Kafka health (cluster ID mismatch)
    check_kafka_health

    # Check 4: Are critical pods healthy?
    if ! check_critical_pods; then
        fix_stuck_pods
        sleep 30
    fi

    sleep 60
done
