#!/bin/bash
# =============================================================================
# Fundamental Platform - Zero-Touch Bootstrap
# =============================================================================
# Runs directly on the VPS (Ubuntu 22.04+)
# Provisions everything from bare OS to running production.
#
# Usage:
#   ./scripts/bootstrap.sh                              # Control plane (default)
#   ./scripts/bootstrap.sh --role control-plane         # Explicit control plane
#   ./scripts/bootstrap.sh --role worker --join-token TOKEN  # Worker node
#   ./scripts/bootstrap.sh --skip-sentry                # Skip Sentry deployment
#   ./scripts/bootstrap.sh --dev-only                   # Dev environment only
#   ./scripts/bootstrap.sh --prod-only                  # Prod environment only
#   ./scripts/bootstrap.sh --step 5                     # Resume from step 5
#
# Prerequisites:
#   - Ubuntu 22.04+ VPS with root access
#   - For control-plane: Cloudflare API token, GitHub PAT
#   - For worker: Join token from control plane
#
# Environment variables (or prompted interactively):
#   CLOUDFLARE_API_TOKEN  - Cloudflare API token with DNS edit permissions
#   GITHUB_TOKEN          - GitHub PAT with repo, workflow scopes
#   REGISTRY_PASSWORD     - Container registry password
# =============================================================================

set -euo pipefail

# --- Constants ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CREDENTIALS_DIR="/root/.fundamental-credentials"
BACKUP_DIR="/root/backups"
LOG_FILE="/var/log/fundamental-bootstrap.log"

# --- Default Parameters ---
ROLE="control-plane"
JOIN_TOKEN=""
SKIP_SENTRY=false
ENV_FILTER="all"
START_STEP=0
DRY_RUN=false

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# Utility Functions
# =============================================================================

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING:${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $*" | tee -a "$LOG_FILE"; exit 1; }
step() { echo -e "\n${CYAN}━━━ Step $1: $2 ━━━${NC}" | tee -a "$LOG_FILE"; }

prompt_if_empty() {
    local var_name="$1"
    local prompt_msg="$2"
    local is_secret="${3:-false}"

    if [ -z "${!var_name:-}" ]; then
        if [ "$is_secret" = "true" ]; then
            read -s -p "$prompt_msg: " "$var_name"
            echo ""
        else
            read -p "$prompt_msg: " "$var_name"
        fi
    fi
    export "$var_name"
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        return 1
    fi
    return 0
}

# =============================================================================
# Parse Arguments
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --role)
            ROLE="$2"
            shift 2
            ;;
        --join-token)
            JOIN_TOKEN="$2"
            shift 2
            ;;
        --skip-sentry)
            SKIP_SENTRY=true
            shift
            ;;
        --dev-only)
            ENV_FILTER="dev"
            shift
            ;;
        --prod-only)
            ENV_FILTER="prod"
            shift
            ;;
        --step)
            START_STEP="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --role TYPE        Node role: control-plane (default) or worker"
            echo "  --join-token TOKEN MicroK8s join token (required for worker)"
            echo "  --skip-sentry      Skip Sentry deployment"
            echo "  --dev-only         Deploy dev environment only"
            echo "  --prod-only        Deploy prod environment only"
            echo "  --step N           Resume from step N"
            echo "  --dry-run          Show what would be done without executing"
            echo "  --help             Show this help"
            exit 0
            ;;
        *)
            error "Unknown option: $1. Use --help for usage."
            ;;
    esac
done

# Validate role
if [[ "$ROLE" != "control-plane" && "$ROLE" != "worker" ]]; then
    error "Invalid role: $ROLE. Must be 'control-plane' or 'worker'."
fi

# Worker requires join token
if [[ "$ROLE" == "worker" && -z "$JOIN_TOKEN" ]]; then
    error "Worker role requires --join-token. Get it from the control plane."
fi

# =============================================================================
# Initialize
# =============================================================================

mkdir -p "$CREDENTIALS_DIR" "$BACKUP_DIR" "$(dirname "$LOG_FILE")"
chmod 700 "$CREDENTIALS_DIR"

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Fundamental Platform - Zero-Touch Bootstrap           ║${NC}"
echo -e "${BLUE}║       Role: ${CYAN}${ROLE}${BLUE}                                         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

log "Bootstrap started. Role: $ROLE, Log: $LOG_FILE"

# =============================================================================
# Step 0: Validate Prerequisites
# =============================================================================

if [[ $START_STEP -le 0 ]]; then
    step 0 "Validate Prerequisites"

    # Check we're running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi

    # Check OS
    if ! grep -q "Ubuntu" /etc/os-release 2>/dev/null; then
        warn "This script is designed for Ubuntu. Other distros may work but are untested."
    fi

    log "Prerequisites validated"
fi

# =============================================================================
# Step 1: Install System Dependencies
# =============================================================================

if [[ $START_STEP -le 1 ]]; then
    step 1 "Install System Dependencies"

    export DEBIAN_FRONTEND=noninteractive

    log "Updating package lists..."
    apt-get update -qq

    log "Installing base packages..."
    apt-get install -y -qq \
        curl wget git jq unzip software-properties-common \
        python3 python3-pip python3-venv \
        apt-transport-https ca-certificates gnupg lsb-release \
        htop vim net-tools socat 2>&1 | tail -1

    # Install yq
    if ! check_command yq; then
        log "Installing yq..."
        YQ_VERSION="v4.40.5"
        wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
        chmod +x /usr/local/bin/yq
    fi
    log "yq version: $(yq --version)"

    # Install Ansible
    if ! check_command ansible-playbook; then
        log "Installing Ansible..."
        pip3 install --quiet ansible
    fi
    log "Ansible version: $(ansible --version | head -1)"

    # Install GitHub CLI
    if ! check_command gh; then
        log "Installing GitHub CLI..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list >/dev/null
        apt-get update -qq && apt-get install -y -qq gh 2>&1 | tail -1
    fi
    log "gh version: $(gh --version | head -1)"

    # Install Ansible Galaxy collections
    if [ -f "$INFRA_DIR/ansible/requirements.yml" ]; then
        log "Installing Ansible collections..."
        ansible-galaxy collection install -r "$INFRA_DIR/ansible/requirements.yml" --force 2>&1 | tail -3
    fi

    log "System dependencies installed"
fi

# =============================================================================
# WORKER NODE PATH - Simple join and exit
# =============================================================================

if [[ "$ROLE" == "worker" ]]; then
    step 2 "Setup Worker Node"

    # Install Docker
    if ! check_command docker; then
        log "Installing Docker..."
        curl -fsSL https://get.docker.com | sh 2>&1 | tail -3
    fi
    log "Docker version: $(docker --version)"

    # Install MicroK8s
    if ! check_command microk8s; then
        log "Installing MicroK8s..."
        snap install microk8s --classic --channel=1.28/stable
        microk8s status --wait-ready
    fi

    step 3 "Join Cluster"
    log "Joining MicroK8s cluster with provided token..."
    microk8s join "$JOIN_TOKEN"

    step 4 "Configure Firewall"
    log "Configuring UFW for inter-node communication..."
    ufw allow 16443/tcp comment "MicroK8s API"
    ufw allow 10250/tcp comment "Kubelet"
    ufw allow 25000/tcp comment "MicroK8s cluster agent"
    ufw allow 19001/tcp comment "Dqlite"
    ufw allow 4789/udp comment "Calico VXLAN"

    step 5 "Verify"
    microk8s kubectl get nodes
    log "Worker node joined successfully!"
    exit 0
fi

# =============================================================================
# CONTROL PLANE PATH - Full setup
# =============================================================================

# =============================================================================
# Step 2: Gather Credentials
# =============================================================================

if [[ $START_STEP -le 2 ]]; then
    step 2 "Gather Credentials"

    # Load existing credentials if available
    if [ -f "$CREDENTIALS_DIR/bootstrap-env" ]; then
        log "Loading existing credentials from $CREDENTIALS_DIR/bootstrap-env"
        source "$CREDENTIALS_DIR/bootstrap-env"
    fi

    # Prompt for missing credentials
    prompt_if_empty CLOUDFLARE_API_TOKEN "Enter Cloudflare API Token" true
    prompt_if_empty GITHUB_TOKEN "Enter GitHub Personal Access Token" true
    prompt_if_empty REGISTRY_PASSWORD "Enter Container Registry Password" true

    # Auto-discover Cloudflare Zone IDs
    log "Auto-discovering Cloudflare Zone IDs..."
    if [ -z "${CLOUDFLARE_ZONE_ID_DEV:-}" ]; then
        CLOUDFLARE_ZONE_ID_DEV=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=academind.ir" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result[0].id // empty')
        if [ -z "$CLOUDFLARE_ZONE_ID_DEV" ]; then
            warn "Could not auto-discover academind.ir zone ID"
            prompt_if_empty CLOUDFLARE_ZONE_ID_DEV "Enter Cloudflare Zone ID for academind.ir"
        else
            log "Found academind.ir zone: $CLOUDFLARE_ZONE_ID_DEV"
        fi
    fi

    if [ -z "${CLOUDFLARE_ZONE_ID_PROD:-}" ]; then
        CLOUDFLARE_ZONE_ID_PROD=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=sahmbaz.ir" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result[0].id // empty')
        if [ -z "$CLOUDFLARE_ZONE_ID_PROD" ]; then
            warn "Could not auto-discover sahmbaz.ir zone ID"
            prompt_if_empty CLOUDFLARE_ZONE_ID_PROD "Enter Cloudflare Zone ID for sahmbaz.ir"
        else
            log "Found sahmbaz.ir zone: $CLOUDFLARE_ZONE_ID_PROD"
        fi
    fi

    # Validate GitHub token
    log "Validating GitHub token..."
    export GH_TOKEN="$GITHUB_TOKEN"
    if ! gh auth status &>/dev/null; then
        error "GitHub token validation failed. Ensure token has repo, workflow scopes."
    fi
    log "GitHub token is valid"

    # Export Terragrunt-compatible env vars (used by terragrunt apply)
    export CLOUDFLARE_API_TOKEN_DEV="$CLOUDFLARE_API_TOKEN"
    export CLOUDFLARE_API_TOKEN_PROD="$CLOUDFLARE_API_TOKEN"

    # Save credentials for future runs
    cat > "$CREDENTIALS_DIR/bootstrap-env" << EOF
# Bootstrap credentials - generated $(date -Iseconds)
export CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN"
export CLOUDFLARE_API_TOKEN_DEV="$CLOUDFLARE_API_TOKEN"
export CLOUDFLARE_API_TOKEN_PROD="$CLOUDFLARE_API_TOKEN"
export CLOUDFLARE_ZONE_ID_DEV="$CLOUDFLARE_ZONE_ID_DEV"
export CLOUDFLARE_ZONE_ID_PROD="$CLOUDFLARE_ZONE_ID_PROD"
export GITHUB_TOKEN="$GITHUB_TOKEN"
export REGISTRY_PASSWORD="$REGISTRY_PASSWORD"
EOF
    chmod 600 "$CREDENTIALS_DIR/bootstrap-env"
    log "Credentials saved to $CREDENTIALS_DIR/bootstrap-env"
fi

# =============================================================================
# Step 3: Configure DNS (Cloudflare)
# =============================================================================

if [[ $START_STEP -le 3 ]]; then
    step 3 "Configure DNS"

    VPS_IP=$(curl -s ifconfig.me 2>/dev/null || echo "5.10.248.55")
    log "VPS IP: $VPS_IP"

    # Configure DNS records via Cloudflare API
    # Proxy is DISABLED because Cloudflare proxy cannot reliably reach Iran-based VPS
    configure_dns() {
        local zone_id="$1"
        local domain="$2"
        shift 2
        local subdomains=("$@")

        log "Configuring DNS for $domain (zone: $zone_id)..."

        # Create/update root domain record
        local existing
        existing=$(curl -s "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A&name=$domain" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result[0].id // empty')

        if [ -n "$existing" ]; then
            curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$existing" \
                -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                -H "Content-Type: application/json" \
                --data "{\"content\":\"$VPS_IP\",\"proxied\":false,\"ttl\":300}" >/dev/null
            log "  Updated: $domain -> $VPS_IP"
        else
            curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
                -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                -H "Content-Type: application/json" \
                --data "{\"type\":\"A\",\"name\":\"@\",\"content\":\"$VPS_IP\",\"proxied\":false,\"ttl\":300}" >/dev/null
            log "  Created: $domain -> $VPS_IP"
        fi

        # Create/update subdomain records
        for sub in "${subdomains[@]}"; do
            local fqdn="$sub.$domain"
            existing=$(curl -s "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?type=A&name=$fqdn" \
                -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq -r '.result[0].id // empty')

            if [ -n "$existing" ]; then
                curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$existing" \
                    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                    -H "Content-Type: application/json" \
                    --data "{\"content\":\"$VPS_IP\",\"proxied\":false,\"ttl\":300}" >/dev/null
                log "  Updated: $fqdn -> $VPS_IP"
            else
                curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
                    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                    -H "Content-Type: application/json" \
                    --data "{\"type\":\"A\",\"name\":\"$sub\",\"content\":\"$VPS_IP\",\"proxied\":false,\"ttl\":300}" >/dev/null
                log "  Created: $fqdn -> $VPS_IP"
            fi
        done
    }

    if [[ "$ENV_FILTER" == "all" || "$ENV_FILTER" == "dev" ]]; then
        configure_dns "$CLOUDFLARE_ZONE_ID_DEV" "academind.ir" "dev" "api" "argocd" "registry" "k8s" "sentry"
    fi

    if [[ "$ENV_FILTER" == "all" || "$ENV_FILTER" == "prod" ]]; then
        configure_dns "$CLOUDFLARE_ZONE_ID_PROD" "sahmbaz.ir" "www" "api"
    fi

    log "DNS configured"
fi

# =============================================================================
# Step 4: Generate Configuration
# =============================================================================

if [[ $START_STEP -le 4 ]]; then
    step 4 "Generate Configuration"

    cd "$INFRA_DIR"

    if [ -f "$INFRA_DIR/scripts/generate-config.sh" ]; then
        log "Running config generation..."
        bash "$INFRA_DIR/scripts/generate-config.sh" 2>&1 | tail -5
    else
        warn "generate-config.sh not found, skipping config generation"
    fi

    log "Configuration generated"
fi

# =============================================================================
# Step 4: Run Ansible Playbooks
# =============================================================================

ANSIBLE_DIR="$INFRA_DIR/ansible"
INVENTORY="$ANSIBLE_DIR/inventory/hosts.ini"
PLAYBOOKS_DIR="$ANSIBLE_DIR/playbooks"

# Helper to run an Ansible playbook
run_playbook() {
    local playbook="$1"
    local extra_args="${2:-}"

    if [ ! -f "$PLAYBOOKS_DIR/$playbook" ]; then
        warn "Playbook not found: $playbook, skipping"
        return 0
    fi

    log "Running playbook: $playbook"
    if [ "$DRY_RUN" = true ]; then
        log "[DRY RUN] Would run: ansible-playbook -i $INVENTORY $PLAYBOOKS_DIR/$playbook $extra_args"
        return 0
    fi

    ansible-playbook \
        -i "$INVENTORY" \
        "$PLAYBOOKS_DIR/$playbook" \
        -e "ansible_connection=local" \
        $extra_args 2>&1 | tee -a "$LOG_FILE" | tail -20

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        warn "Playbook $playbook had errors. Check log: $LOG_FILE"
        return 1
    fi
}

if [[ $START_STEP -le 5 ]]; then
    step 5 "Setup VPS Infrastructure"
    run_playbook "setup-vps.yaml" || warn "VPS setup had issues, continuing..."
fi

if [[ $START_STEP -le 6 ]]; then
    step 6 "Setup Container Registry"
    run_playbook "setup-registry-proxy.yaml" || warn "Registry setup had issues, continuing..."
fi

if [[ $START_STEP -le 7 ]]; then
    step 7 "Setup Cert-Manager"
    run_playbook "setup-cert-manager.yaml" || warn "Cert-manager setup had issues, continuing..."
fi

if [[ $START_STEP -le 8 ]]; then
    step 8 "Create Kubernetes Secrets"
    run_playbook "setup-kubernetes-secrets.yaml" || warn "Secrets setup had issues, continuing..."
fi

if [[ $START_STEP -le 9 ]]; then
    step 9 "Install ArgoCD"
    run_playbook "setup-argocd.yaml" || warn "ArgoCD setup had issues, continuing..."
fi

if [[ $START_STEP -le 10 ]]; then
    step 10 "Install Kubernetes Dashboard"
    run_playbook "setup-kubernetes-dashboard.yaml" || warn "Dashboard setup had issues, continuing..."
fi

if [[ $START_STEP -le 11 && "$SKIP_SENTRY" != true ]]; then
    step 11 "Deploy Sentry"
    run_playbook "deploy-sentry.yaml" || warn "Sentry setup had issues, continuing..."
fi

if [[ $START_STEP -le 12 ]]; then
    step 12 "Setup GitHub Actions Runner"

    # Auto-generate runner registration token
    log "Generating GitHub runner registration token..."
    RUNNER_TOKEN=$(gh api -X POST "repos/PeSahm/Fundamental.Backend/actions/runners/registration-token" \
        --jq '.token' 2>/dev/null || echo "")

    if [ -n "$RUNNER_TOKEN" ]; then
        run_playbook "setup-github-runner.yaml" \
            "-e github_runner_token=$RUNNER_TOKEN" || warn "Runner setup had issues, continuing..."
    else
        warn "Could not generate runner token. Skipping runner setup."
        warn "You can set up the runner manually later."
    fi
fi

if [[ $START_STEP -le 13 ]]; then
    step 13 "Deploy Applications"
    run_playbook "deploy-applications.yaml" || warn "App deployment had issues, continuing..."
fi

# =============================================================================
# Step 14: Configure GitHub Secrets
# =============================================================================

if [[ $START_STEP -le 14 ]]; then
    step 14 "Configure GitHub Secrets"

    VPS_IP=$(yq '.shared.vps.ip' "$INFRA_DIR/config.yaml" 2>/dev/null || echo "5.10.248.55")
    REGISTRY_USERNAME=$(yq '.shared.registry.username' "$INFRA_DIR/config.yaml" 2>/dev/null || echo "fundamental")

    # Read Sentry auth token if available
    SENTRY_AUTH_TOKEN=""
    if [ -f "$CREDENTIALS_DIR/sentry-credentials.txt" ]; then
        SENTRY_AUTH_TOKEN=$(grep "Auth Token:" "$CREDENTIALS_DIR/sentry-credentials.txt" | head -1 | awk '{print $NF}' || echo "")
    fi

    for REPO in "Fundamental.Backend" "Fundamental.FrontEnd"; do
        log "Setting secrets for PeSahm/$REPO..."

        gh secret set REGISTRY_USERNAME --repo "PeSahm/$REPO" --body "$REGISTRY_USERNAME" 2>/dev/null || true
        gh secret set REGISTRY_PASSWORD --repo "PeSahm/$REPO" --body "$REGISTRY_PASSWORD" 2>/dev/null || true
        gh secret set VPS_IP --repo "PeSahm/$REPO" --body "$VPS_IP" 2>/dev/null || true
        gh secret set SSH_USER --repo "PeSahm/$REPO" --body "root" 2>/dev/null || true

        # Set INFRA_REPO_TOKEN for triggering Infra workflows
        gh secret set INFRA_REPO_TOKEN --repo "PeSahm/$REPO" --body "$GITHUB_TOKEN" 2>/dev/null || true

        # Set Sentry token if available (generated by deploy-sentry.yaml)
        if [ -n "$SENTRY_AUTH_TOKEN" ]; then
            gh secret set SENTRY_AUTH_TOKEN --repo "PeSahm/$REPO" --body "$SENTRY_AUTH_TOKEN" 2>/dev/null || true
        fi

        log "Secrets set for $REPO"
    done
fi

# =============================================================================
# Step 14: Trigger Initial CI/CD Builds
# =============================================================================

if [[ $START_STEP -le 15 ]]; then
    step 15 "Trigger Initial CI/CD Builds"

    if [[ "$ENV_FILTER" == "all" || "$ENV_FILTER" == "dev" ]]; then
        log "Triggering dev builds..."
        gh workflow run ci-cd.yaml --repo PeSahm/Fundamental.Backend --ref develop 2>/dev/null || \
            warn "Could not trigger Backend dev build"
        gh workflow run ci-cd.yaml --repo PeSahm/Fundamental.FrontEnd --ref develop 2>/dev/null || \
            warn "Could not trigger Frontend dev build"
    fi

    if [[ "$ENV_FILTER" == "all" || "$ENV_FILTER" == "prod" ]]; then
        log "Triggering prod builds..."
        gh workflow run ci-cd.yaml --repo PeSahm/Fundamental.Backend --ref main 2>/dev/null || \
            warn "Could not trigger Backend prod build"
        gh workflow run ci-cd.yaml --repo PeSahm/Fundamental.FrontEnd --ref main 2>/dev/null || \
            warn "Could not trigger Frontend prod build"
    fi

    log "CI/CD builds triggered (check GitHub Actions for status)"
fi

# =============================================================================
# Step 15: Generate Worker Join Token
# =============================================================================

if [[ $START_STEP -le 16 ]]; then
    step 16 "Generate Worker Join Command"

    if check_command microk8s; then
        JOIN_CMD=$(microk8s add-node --token-ttl 86400 2>/dev/null | grep "microk8s join" | head -1 || echo "")
        if [ -n "$JOIN_CMD" ]; then
            echo "$JOIN_CMD" > "$CREDENTIALS_DIR/join-command.txt"
            log "Worker join command saved to $CREDENTIALS_DIR/join-command.txt"
            log "To add a worker node, run on the new VPS:"
            log "  ./scripts/bootstrap.sh --role worker --join-token <TOKEN>"
        fi
    fi
fi

# =============================================================================
# Step 16: Verify Deployment
# =============================================================================

if [[ $START_STEP -le 17 ]]; then
    step 17 "Verify Deployment"

    if [ -f "$PLAYBOOKS_DIR/verify-deployment.yaml" ]; then
        run_playbook "verify-deployment.yaml" || warn "Some verification checks failed"
    else
        # Inline verification
        log "Running basic health checks..."
        echo ""

        # Check nodes
        echo -e "${BLUE}Kubernetes Nodes:${NC}"
        microk8s kubectl get nodes 2>/dev/null || warn "kubectl not available"
        echo ""

        # Check pods
        echo -e "${BLUE}Pod Status (non-Running):${NC}"
        UNHEALTHY=$(microk8s kubectl get pods -A 2>/dev/null | grep -v Running | grep -v Completed | grep -v NAMESPACE || echo "All pods healthy")
        echo "$UNHEALTHY"
        echo ""

        # Check ArgoCD apps
        echo -e "${BLUE}ArgoCD Applications:${NC}"
        microk8s kubectl get applications -n argocd 2>/dev/null || echo "ArgoCD not available"
        echo ""

        # Check certificates
        echo -e "${BLUE}TLS Certificates:${NC}"
        microk8s kubectl get certificates -A 2>/dev/null || echo "No certificates found"
    fi
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Bootstrap Complete!                               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}Access URLs:${NC}"
echo "  Frontend (dev):  https://dev.academind.ir"
echo "  Backend (dev):   https://dev.academind.ir/api/health/live"
echo "  Frontend (prod): https://sahmbaz.ir"
echo "  Backend (prod):  https://sahmbaz.ir/api/health/live"
echo "  ArgoCD:          https://argocd.academind.ir"
echo "  Sentry:          https://sentry.academind.ir"
echo "  K8s Dashboard:   https://k8s.academind.ir"
echo "  Registry:        https://registry.academind.ir"
echo ""

echo -e "${BLUE}Credentials:${NC}"
echo "  ArgoCD password:    $(cat $CREDENTIALS_DIR/argocd-password.txt 2>/dev/null || echo 'see $CREDENTIALS_DIR')"
echo "  Registry password:  $(cat $CREDENTIALS_DIR/registry-password 2>/dev/null || echo 'see $CREDENTIALS_DIR')"
echo "  K8s Dashboard:      see $CREDENTIALS_DIR/kubernetes-dashboard-token"
echo "  Bootstrap env:      $CREDENTIALS_DIR/bootstrap-env"
echo ""

echo -e "${BLUE}Worker Node:${NC}"
if [ -f "$CREDENTIALS_DIR/join-command.txt" ]; then
    echo "  Join command: $(cat $CREDENTIALS_DIR/join-command.txt)"
else
    echo "  Run 'microk8s add-node' to generate join token"
fi
echo ""

echo -e "${BLUE}Logs:${NC} $LOG_FILE"
echo ""
log "Bootstrap completed successfully!"
