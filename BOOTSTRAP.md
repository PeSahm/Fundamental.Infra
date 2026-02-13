# Fundamental Platform - Bootstrap Guide

Zero-touch setup for the Fundamental platform from bare Ubuntu to running production.

## Prerequisites

Before starting, you need:

| Item | How to Get |
|------|-----------|
| **VPS** | Ubuntu 22.04+ with SSH root access, min 4GB RAM, 50GB disk |
| **Cloudflare API Token** | Cloudflare Dashboard → My Profile → API Tokens → Create Token → Zone:DNS:Edit for both zones |
| **GitHub PAT** | GitHub Settings → Developer Settings → Fine-grained tokens → `repo`, `workflow`, `admin:org` scopes |
| **SSH public key** | Added to VPS `~/.ssh/authorized_keys` |

### Domains

| Environment | Domain | Cloudflare Zone |
|-------------|--------|-----------------|
| Development | dev.academind.ir | academind.ir |
| Production | sahmbaz.ir | sahmbaz.ir |
| ArgoCD | argocd.academind.ir | academind.ir |
| Registry | registry.academind.ir | academind.ir |

---

## Quick Start

### First Node (Control Plane)

```bash
ssh root@<VPS_IP>
apt-get update && apt-get install -y git
git clone https://github.com/PeSahm/Fundamental.Infra.git
cd Fundamental.Infra
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh --role control-plane
```

The script will prompt for:
- `CLOUDFLARE_API_TOKEN` - Your Cloudflare API token
- `GITHUB_TOKEN` - Your GitHub PAT
- `REGISTRY_PASSWORD` - Will be auto-generated if not provided

### Adding a Worker Node (Future)

```bash
# On the control plane, get the join token:
cat /root/.fundamental-credentials/join-command.txt

# On the new worker VPS:
ssh root@<WORKER_IP>
apt-get update && apt-get install -y git
git clone https://github.com/PeSahm/Fundamental.Infra.git
cd Fundamental.Infra
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh --role worker --join-token <TOKEN_FROM_CONTROL_PLANE>
```

---

## What Bootstrap Does

### Control Plane Steps

| Step | Action | Duration |
|------|--------|----------|
| 0 | Validate prerequisites (root, OS) | ~10s |
| 1 | Install system dependencies (yq, Ansible, gh CLI) | ~5min |
| 2 | Gather credentials (Cloudflare token, GitHub PAT, auto-discover zone IDs) | ~30s |
| 3 | Configure DNS via Cloudflare API (A records, proxy disabled) | ~30s |
| 4 | Generate configuration (config.yaml → terragrunt.hcl) | ~10s |
| 5 | Set up VPS infrastructure (MicroK8s, UFW, Docker) | ~3min |
| 6 | Set up container registry (nginx proxy, basic auth, TLS) | ~2min |
| 7 | Set up cert-manager + Let's Encrypt cluster issuer | ~1min |
| 8 | Create Kubernetes secrets (DB passwords, JWT keys, registry creds) | ~30s |
| 9 | Install ArgoCD | ~2min |
| 10 | Install Kubernetes Dashboard | ~1min |
| 11 | Deploy Sentry (optional, skip with `--skip-sentry`) | ~5min |
| 12 | Set up GitHub Actions self-hosted runner | ~2min |
| 13 | Deploy applications via ArgoCD (dev + prod) | ~2min |
| 14 | Configure GitHub secrets (registry, Sentry token, INFRA_REPO_TOKEN) | ~30s |
| 15 | Trigger initial CI/CD builds (Backend + Frontend) | ~1min |
| 16 | Generate worker join token | ~10s |
| 17 | Verify deployment (health checks) | ~30s |

**Total: ~25 minutes**

### Worker Node Steps

| Step | Action | Duration |
|------|--------|----------|
| 0 | Validate prerequisites | ~10s |
| 1 | Install dependencies (snapd, MicroK8s) | ~5min |
| 2 | Join MicroK8s cluster using join token | ~1min |
| 3 | Configure UFW for inter-node communication | ~30s |
| 4 | Label node and verify cluster membership | ~10s |

---

## Bootstrap Options

```bash
./scripts/bootstrap.sh                         # Default: control-plane
./scripts/bootstrap.sh --role control-plane    # Explicit control-plane
./scripts/bootstrap.sh --role worker --join-token TOKEN
./scripts/bootstrap.sh --skip-sentry           # Skip Sentry deployment
./scripts/bootstrap.sh --dev-only              # Only deploy dev environment
./scripts/bootstrap.sh --prod-only             # Only deploy prod environment
./scripts/bootstrap.sh --step 5                # Resume from step 5
./scripts/bootstrap.sh --dry-run               # Show what would be done
```

---

## Architecture

```
                    ┌──────────────────────────────────────┐
                    │     Cloudflare (DNS only, no proxy)   │
                    │  dev.academind.ir  │  sahmbaz.ir     │
                    └─────────┬────────────────┬───────────┘
                              │                │
                    ┌─────────▼────────────────▼───────────┐
                    │         VPS (5.10.248.55)             │
                    │         Ubuntu + MicroK8s             │
                    │                                       │
                    │  ┌─────────────────────────────────┐  │
                    │  │    Ingress Controller (nginx)    │  │
                    │  └─────┬───────────────────┬───────┘  │
                    │        │                   │          │
                    │  ┌─────▼────────┐  ┌──────▼───────┐  │
                    │  │fundamental-dev│  │fundamental-  │  │
                    │  │  Backend     │  │prod          │  │
                    │  │  Frontend    │  │  Backend     │  │
                    │  │  PostgreSQL  │  │  Frontend    │  │
                    │  │  Redis       │  │  PostgreSQL  │  │
                    │  └──────────────┘  │  Redis       │  │
                    │                    └──────────────┘  │
                    │  ┌──────────┐  ┌──────────────────┐  │
                    │  │  ArgoCD  │  │  Container       │  │
                    │  │          │  │  Registry        │  │
                    │  └──────────┘  └──────────────────┘  │
                    │  ┌──────────┐  ┌──────────────────┐  │
                    │  │  Sentry  │  │  cert-manager    │  │
                    │  └──────────┘  └──────────────────┘  │
                    └──────────────────────────────────────┘
```

---

## GitOps Flow

```
Developer pushes code
        │
        ▼
GitHub Actions CI/CD
  ├─ Build & Test
  ├─ Build Docker Image
  ├─ Push to registry.academind.ir
  └─ Trigger repository_dispatch to Fundamental.Infra
        │
        ▼
ArgoCD detects change
  ├─ Syncs Helm chart
  ├─ Updates deployments
  └─ Verifies health
```

**Branch Strategy:**
- `develop` → `dev-latest` tag → fundamental-dev namespace → dev.academind.ir
- `main` → `prod-latest` tag → fundamental-prod namespace → sahmbaz.ir

---

## Post-Bootstrap Verification

```bash
# Run the verification playbook
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/verify-deployment.yaml

# Or check manually
microk8s kubectl get pods -A | grep -v Running | grep -v Completed

# Check URLs
curl -s -o /dev/null -w "%{http_code}" https://dev.academind.ir
curl -s -o /dev/null -w "%{http_code}" https://sahmbaz.ir
curl -s -o /dev/null -w "%{http_code}" https://argocd.academind.ir
```

---

## Credential Storage

After bootstrap, credentials are saved to `/root/.fundamental-credentials/`:

| File | Contents |
|------|----------|
| `argocd-password.txt` | ArgoCD admin password |
| `registry-password` | Container registry password |
| `registry-credentials.txt` | Full registry login info |
| `secrets.txt` | Generated Kubernetes secret values |
| `sentry-credentials.txt` | Sentry DSN and auth token |
| `kubernetes-dashboard-token` | Dashboard access token |
| `join-command.txt` | MicroK8s join command for workers |

---

## Troubleshooting

### Bootstrap fails at a step
Resume from the failed step:
```bash
./scripts/bootstrap.sh --step <STEP_NUMBER>
```

### Pods in CrashLoopBackOff
```bash
microk8s kubectl describe pod <POD_NAME> -n <NAMESPACE>
microk8s kubectl logs <POD_NAME> -n <NAMESPACE> --previous
```

### ArgoCD sync issues
```bash
# Check ArgoCD app status
microk8s kubectl get applications -n argocd
# Force sync
ARGOCD_PASSWORD=$(cat /root/.fundamental-credentials/argocd-password.txt)
argocd login argocd.academind.ir --username admin --password "$ARGOCD_PASSWORD" --grpc-web
argocd app sync fundamental-dev
```

### Certificate issues
```bash
microk8s kubectl get certificates -A
microk8s kubectl describe certificate <NAME> -n <NAMESPACE>
# Force renewal
microk8s kubectl delete certificate <NAME> -n <NAMESPACE>
```

### Sentry services crashing

> **Note (v26.1.0):** Images are from GHCR (`ghcr.io/getsentry/*`), not DockerHub.
> Celery worker/cron replaced by `taskbroker` + `taskworker`.
> Kafka uses KRaft mode (no Zookeeper).

**Snuba consumer connecting to 127.0.0.1 instead of Kafka service:**
Snuba reads `DEFAULT_BROKERS` env var, not `KAFKA_BROKER_LIST`. Verify:
```bash
microk8s kubectl exec -n sentry deploy/sentry-snuba-consumer -- \
  python3 -c "from snuba.settings import BROKER_CONFIG; print(BROKER_CONFIG)"
# Should show: {'bootstrap.servers': 'sentry-kafka:9092', ...}
```

**Redis OOM kills (high restart count):**
Redis needs enough memory for background saves (fork doubles memory). The limit should be >= 1Gi:
```bash
microk8s kubectl get deploy sentry-redis -n sentry -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'
```

**Missing Kafka topics after Kafka restart:**
```bash
# List topics
POD=$(microk8s kubectl get pod -l app=sentry-kafka -n sentry -o jsonpath='{.items[0].metadata.name}')
microk8s kubectl exec $POD -n sentry -- kafka-topics --list --bootstrap-server localhost:9092

# Recreate missing topics
for topic in events ingest-events ingest-transactions ingest-attachments \
             outcomes outcomes-billing sessions transactions generic-events \
             profiles ingest-occurrences ingest-replay-events \
             ingest-monitors scheduled-subscriptions-events; do
  microk8s kubectl exec $POD -n sentry -- kafka-topics --create --topic $topic \
    --partitions 1 --replication-factor 1 --bootstrap-server localhost:9092 --if-not-exists
done
```

**Taskbroker/taskworker not running (replaced Celery in 26.x):**
```bash
# Check taskbroker and taskworker status
microk8s kubectl get deploy -n sentry | grep -E "task"
# Expected: sentry-taskbroker and sentry-taskworker both with 1/1

# Check taskbroker gRPC connectivity
microk8s kubectl logs deploy/sentry-taskworker -n sentry --tail=20
```

**Sentry auth token expired (CI/CD failing):**
```bash
# Generate new token from Sentry web UI:
# https://sentry.academind.ir/settings/account/api/auth-tokens/
# Then update GitHub secrets:
gh secret set SENTRY_AUTH_TOKEN --repo PeSahm/Fundamental.Backend --body "NEW_TOKEN"
gh secret set SENTRY_AUTH_TOKEN --repo PeSahm/Fundamental.FrontEnd --body "NEW_TOKEN"
```

### Registry access issues
```bash
# Test registry from VPS
PASS=$(cat /root/.fundamental-credentials/registry-password)
curl -u fundamental:$PASS https://registry.academind.ir/v2/_catalog
```
