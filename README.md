# Fundamental Infrastructure

Complete infrastructure-as-code for deploying the Fundamental platform (Backend + Frontend) to a VPS with MicroK8s, GitOps, and automated CI/CD.

## 📋 Table of Contents

- [Overview](#overview)
- [Environments](#environments)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Branch Strategy](#branch-strategy)
- [Directory Structure](#directory-structure)
- [Deployment Workflow](#deployment-workflow)
- [CI/CD Pipeline](#cicd-pipeline)
- [Access & Credentials](#access--credentials)
- [Common Tasks](#common-tasks)
- [Troubleshooting](#troubleshooting)

---

## Overview

This repository manages the complete infrastructure for the Fundamental platform using a **GitOps** approach with **multi-environment** support:

- **Single Source of Truth**: All configuration in `config.yaml`
- **Multi-Environment**: Separate dev (develop branch) and prod (main branch) environments
- **Infrastructure as Code**: Ansible for VPS setup
- **GitOps Deployment**: ArgoCD automatically syncs Kubernetes manifests
- **Automated CI/CD**: GitHub Actions build, test, and deploy on push

---

## Environments

| Environment | Branch | Domain | Namespace | Purpose |
|-------------|--------|--------|-----------|---------|
| **Development** | `develop` | `dev.academind.ir` | `fundamental-dev` | Testing, integration |
| **Production** | `main` | `sahmbaz.ir` | `fundamental-prod` | Live users |

### What Gets Deployed

| Component | Description | Technology |
|-----------|-------------|------------|
| **Backend** | .NET 9 API | ASP.NET Core |
| **Frontend** | Angular SPA | Nginx |
| **Database** | PostgreSQL 17 | StatefulSet |
| **Cache** | Redis 7 | StatefulSet |
| **Registry** | Container images | MicroK8s built-in (shared) |
| **Ingress** | HTTPS routing | Nginx Ingress |
| **Certificates** | Auto SSL | Let's Encrypt + cert-manager |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
┌──────────────────────────────┐   ┌──────────────────────────────┐
│      CLOUDFLARE DNS          │   │      CLOUDFLARE DNS          │
│    (academind.ir zone)       │   │     (sahmbaz.ir zone)        │
│                              │   │                              │
│  dev.academind.ir    ───┐    │   │  sahmbaz.ir          ───┐    │
│  argocd.academind.ir ───┤    │   │  www.sahmbaz.ir      ───┤    │
│  registry.academind.ir ─┘    │   │                      ───┘    │
└──────────────────────────────┘   └──────────────────────────────┘
                    │                               │
                    └───────────────┬───────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         VPS (5.10.248.55)                                    │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                      MicroK8s Cluster                                  │  │
│  │                                                                        │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                    Nginx Ingress Controller                      │  │  │
│  │  │  Routes traffic based on hostname to appropriate namespace       │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                        │  │
│  │  ┌─────────────────────────────┐  ┌────────────────────────────────┐  │  │
│  │  │   fundamental-dev namespace │  │  fundamental-prod namespace    │  │  │
│  │  │   (dev.academind.ir)        │  │  (sahmbaz.ir)                  │  │  │
│  │  │                             │  │                                │  │  │
│  │  │  ┌─────────┐ ┌─────────┐   │  │  ┌─────────┐ ┌─────────┐      │  │  │
│  │  │  │ Backend │ │Frontend │   │  │  │ Backend │ │Frontend │      │  │  │
│  │  │  │ (API)   │ │(Nginx)  │   │  │  │ (API)   │ │(Nginx)  │      │  │  │
│  │  │  └─────────┘ └─────────┘   │  │  └─────────┘ └─────────┘      │  │  │
│  │  │  ┌─────────┐ ┌─────────┐   │  │  ┌─────────┐ ┌─────────┐      │  │  │
│  │  │  │Postgres │ │ Redis   │   │  │  │Postgres │ │ Redis   │      │  │  │
│  │  │  │  (DB)   │ │(Cache)  │   │  │  │  (DB)   │ │(Cache)  │      │  │  │
│  │  │  └─────────┘ └─────────┘   │  │  └─────────┘ └─────────┘      │  │  │
│  │  └─────────────────────────────┘  └────────────────────────────────┘  │  │
│  │                                                                        │  │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │  │
│  │  │                   Shared Services                                 │  │  │
│  │  │  ┌─────────────────┐  ┌────────────────────────────────────────┐ │  │  │
│  │  │  │ ArgoCD          │  │ Container Registry                     │ │  │  │
│  │  │  │ (GitOps)        │  │ (registry.academind.ir)                │ │  │  │
│  │  │  │ argocd namespace│  │ container-registry namespace           │ │  │  │
│  │  │  └─────────────────┘  └────────────────────────────────────────┘ │  │  │
│  │  └──────────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Branch Strategy

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         BRANCH DEPLOYMENT FLOW                                │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Fundamental.Backend / Fundamental.FrontEnd                                 │
│                                                                              │
│   develop branch ─────────────────────────┐                                  │
│        │                                  │                                  │
│        ▼                                  │                                  │
│   ┌──────────────┐    Build & Push        │                                  │
│   │ GitHub       │───▶ dev-latest tag ────┤                                  │
│   │ Actions      │                        │                                  │
│   └──────────────┘                        ▼                                  │
│                                    ┌──────────────┐                          │
│                                    │ Fundamental. │                          │
│                                    │ Infra        │                          │
│                                    │ (develop)    │                          │
│                                    └──────┬───────┘                          │
│                                           │                                  │
│                                           ▼                                  │
│                                    ┌──────────────┐                          │
│                                    │ ArgoCD       │                          │
│                                    │ fundamental- │                          │
│                                    │ dev app      │──▶ dev.academind.ir      │
│                                    └──────────────┘                          │
│                                                                              │
│   main branch ────────────────────────────┐                                  │
│        │                                  │                                  │
│        ▼                                  │                                  │
│   ┌──────────────┐    Build & Push        │                                  │
│   │ GitHub       │───▶ prod-latest tag ───┤                                  │
│   │ Actions      │                        │                                  │
│   └──────────────┘                        ▼                                  │
│                                    ┌──────────────┐                          │
│                                    │ Fundamental. │                          │
│                                    │ Infra        │                          │
│                                    │ (main)       │                          │
│                                    └──────┬───────┘                          │
│                                           │                                  │
│                                           ▼                                  │
│                                    ┌──────────────┐                          │
│                                    │ ArgoCD       │                          │
│                                    │ fundamental- │                          │
│                                    │ prod app     │──▶ sahmbaz.ir            │
│                                    └──────────────┘                          │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Image Tagging

| Branch | Image Tag | Example |
|--------|-----------|---------|
| `develop` | `dev-latest`, `dev-YYYYMMDD-SHA` | `dev-latest`, `dev-20250128-abc1234` |
| `main` | `prod-latest`, `1.0.0-YYYYMMDD-SHA` | `prod-latest`, `1.0.0-20250128-xyz9876` |

---

## Quick Start

### Prerequisites

- SSH access to VPS (5.10.248.55)
- GitHub repository access
- Cloudflare API token (for DNS management)

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/PeSahm/Fundamental.Infra.git
   cd Fundamental.Infra
   ```

2. **Review/Update configuration:**
   ```bash
   # Edit the single source of truth
   vim config.yaml
   
   # Generate all configuration files
   ./scripts/generate-config.sh
   ```

3. **Run initial VPS setup (first time only):**
   ```bash
   cd ansible
   ansible-playbook -i inventory/hosts.ini playbooks/full-deploy.yaml
   ```

4. **Apply ArgoCD applications:**
   ```bash
   # SSH to VPS
   ssh root@5.10.248.55
   
   # Apply ArgoCD apps for both environments
   microk8s kubectl apply -f /root/argocd-apps/
   ```

### Creating the Develop Branch

Both Fundamental.Backend and Fundamental.FrontEnd repositories need the `develop` branch:

```bash
# For each repo (Backend, Frontend, Infra)
git checkout main
git checkout -b develop
git push -u origin develop
```

---

## Configuration

### Single Source of Truth

All configuration is managed in `config.yaml`. After editing, regenerate derived files:

```bash
./scripts/generate-config.sh
```

This generates:
- `ansible/group_vars/all.yaml` - Ansible variables
- `charts/fundamental-stack/values-dev.yaml` - Development Helm values
- `charts/fundamental-stack/values-prod.yaml` - Production Helm values
- `argocd/applications/fundamental-dev.yaml` - ArgoCD dev application
- `argocd/applications/fundamental-prod.yaml` - ArgoCD prod application
- `docs/CICD_CONFIGURATION.md` - CI/CD reference

### Environment-Specific Configuration

The `config.yaml` defines both environments:

```yaml
environments:
  dev:
    domain:
      full: "dev.academind.ir"
    branch: "develop"
    namespace: "fundamental-dev"
    image_tag: "dev-latest"
    resources:
      # Lower resources for dev
      
  prod:
    domain:
      full: "sahmbaz.ir"
    branch: "main"
    namespace: "fundamental-prod"
    image_tag: "prod-latest"
    resources:
      # Higher resources for prod
```

---

## Directory Structure

```
Fundamental.Infra/
├── config.yaml                    # ⭐ SINGLE SOURCE OF TRUTH
├── scripts/
│   └── generate-config.sh         # Configuration generator
├── ansible/
│   ├── inventory/hosts.ini        # VPS inventory
│   ├── group_vars/all.yaml        # Generated variables
│   └── playbooks/                 # Setup playbooks
├── charts/
│   └── fundamental-stack/
│       ├── Chart.yaml
│       ├── values-dev.yaml        # Generated dev values
│       └── values-prod.yaml       # Generated prod values
├── argocd/
│   ├── applications/
│   │   ├── fundamental-dev.yaml   # Dev ArgoCD app
│   │   └── fundamental-prod.yaml  # Prod ArgoCD app
│   └── projects/
├── .github/workflows/
│   └── update-tag.yml             # Auto-update image tags
└── docs/
    └── CICD_CONFIGURATION.md      # Generated CI/CD reference
```

---

## Deployment Workflow

### Development Deployment (dev.academind.ir)

1. Push to `develop` branch in Backend/Frontend repos
2. GitHub Actions builds images with `dev-latest` tag
3. Triggers `update-image-tag` event to Infra repo
4. Infra workflow updates `values-dev.yaml` on `develop` branch
5. ArgoCD (watching `develop` branch) syncs to `fundamental-dev` namespace

### Production Deployment (sahmbaz.ir)

1. Push to `main` branch in Backend/Frontend repos
2. GitHub Actions builds images with `prod-latest` tag
3. Triggers `update-image-tag` event to Infra repo
4. Infra workflow updates `values-prod.yaml` on `main` branch
5. ArgoCD (watching `main` branch) syncs to `fundamental-prod` namespace

### Manual Deployment

```bash
# Deploy to dev
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/deploy-app.yaml \
  -e "target_env=dev"

# Deploy to prod
ansible-playbook -i inventory/hosts.ini playbooks/deploy-app.yaml \
  -e "target_env=prod"
```

---

## CI/CD Pipeline

### Backend Pipeline (Fundamental.Backend)

```yaml
on:
  push:
    branches: [main, develop]

# Branch → Environment mapping:
# - main → prod (prod-YYYYMMDD-SHA tag)
# - develop → dev (dev-YYYYMMDD-SHA tag)
```

### Frontend Pipeline (Fundamental.FrontEnd)

```yaml
on:
  push:
    branches: [main, develop]

# Same branch → environment mapping as Backend
```

### GitOps Flow (Automatic Deployment)

When code is pushed to Backend/Frontend:

1. **CI builds** Docker image with versioned tag (e.g., `dev-20251228-abc1234`)
2. **CI triggers** `repository_dispatch` → Infra repo
3. **GitOps workflow** updates `values-{env}.yaml` with new image tag
4. **ArgoCD detects** the Git change and auto-syncs
5. **Kubernetes** pulls new image and restarts pods

This flow is fully automatic - no manual intervention required.

---

## Access & Credentials

### URLs

| Service | Development | Production |
|---------|-------------|------------|
| Frontend | https://dev.academind.ir | https://sahmbaz.ir |
| Backend API | https://dev.academind.ir/api | https://sahmbaz.ir/api |
| ArgoCD | https://argocd.academind.ir | (same) |
| Registry | https://registry.academind.ir | (same) |
| K8s Dashboard | https://k8s.academind.ir | (same) |

### SSH Access

```bash
ssh root@5.10.248.55
```

### ArgoCD Dashboard

```bash
# Get initial admin password (from VPS)
cat /root/.fundamental-credentials/argocd-admin-password

# Or retrieve from secret
microk8s kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### Container Registry

```bash
# Get credentials (from VPS)
cat /root/.fundamental-credentials/registry-password

# Login
docker login registry.academind.ir
```

### Database Access (Development)

PostgreSQL can be accessed externally via port forwarding:

```bash
# SSH to VPS and start port forward (port 5433)
ssh root@5.10.248.55 '/root/scripts/pg-port-forward.sh start'

# Check status
ssh root@5.10.248.55 '/root/scripts/pg-port-forward.sh status'

# Stop when done
ssh root@5.10.248.55 '/root/scripts/pg-port-forward.sh stop'
```

**Connection Details:**
| Parameter | Value |
|-----------|-------|
| Host | `5.10.248.55` |
| Port | `5433` |
| Database | `fundamental_dev` |
| Username | `fundamental` |
| Password | `NMC1yGjPQvUnx3qhTB4xSelH` |

```bash
# Connect with psql
psql -h 5.10.248.55 -p 5433 -U fundamental -d fundamental_dev

# Or use connection string
postgresql://fundamental:NMC1yGjPQvUnx3qhTB4xSelH@5.10.248.55:5433/fundamental_dev
```

> **Note:** Port forward uses `socat` to bridge external port 5433 to the PostgreSQL pod.
> The forward is not persistent across reboots - run the start command when needed.

---

## Credential Management

### Overview

Credentials in this system are managed at multiple layers:

| Layer | Tool | Can View? | Can Change? | Persistence |
|-------|------|-----------|-------------|-------------|
| **Kubernetes Dashboard** | Web UI | ✅ Yes | ✅ Yes | ⚠️ Until sync |
| **ArgoCD Dashboard** | Web UI | ❌ No | ❌ No | N/A |
| **Kubernetes Secrets** | `kubectl` | ✅ Yes | ✅ Yes | ⚠️ Until sync |
| **Helm Values Files** | Git repo | ✅ Yes | ✅ Yes | ✅ Permanent |

### Management Tools

#### 1. Kubernetes Dashboard (Recommended for UI)

**URL:** https://k8s.academind.ir

The Kubernetes Dashboard provides a web UI to:
- View and edit Secrets (credentials)
- Monitor pods and logs
- Manage deployments
- View cluster resources

**Login:**
```bash
# Get dashboard token
ssh root@5.10.248.55
cat /root/.fundamental-credentials/kubernetes-dashboard-token

# Or retrieve directly
microk8s kubectl describe secret -n kube-system microk8s-dashboard-token | grep "^token:"
```

#### 2. kubectl (Command Line)

**View all secrets:**
```bash
# List secrets in a namespace
microk8s kubectl get secrets -n fundamental-dev
microk8s kubectl get secrets -n fundamental-prod

# View specific secret (encoded)
microk8s kubectl get secret postgresql-credentials -n fundamental-dev -o yaml

# Decode a specific value
microk8s kubectl get secret postgresql-credentials -n fundamental-dev \
  -o jsonpath='{.data.password}' | base64 -d
```

**View all credentials at once:**
```bash
# PostgreSQL
echo "Username: $(microk8s kubectl get secret postgresql-credentials -n fundamental-dev -o jsonpath='{.data.username}' | base64 -d)"
echo "Password: $(microk8s kubectl get secret postgresql-credentials -n fundamental-dev -o jsonpath='{.data.password}' | base64 -d)"

# Redis
echo "Password: $(microk8s kubectl get secret redis-credentials -n fundamental-dev -o jsonpath='{.data.password}' | base64 -d)"
```

**Change credentials (temporary - will be overwritten on ArgoCD sync):**
```bash
# Patch a secret
microk8s kubectl patch secret postgresql-credentials -n fundamental-dev \
  --type='json' -p='[{"op":"replace","path":"/data/password","value":"'$(echo -n "NEW_PASSWORD" | base64)'"}]'
```

#### 3. Helm Values (Permanent Changes)

For permanent credential changes, edit the Helm values files:

```bash
# Development credentials
vim charts/fundamental-stack/values-dev.yaml

# Production credentials
vim charts/fundamental-stack/values-prod.yaml
```

Then commit, push, and ArgoCD will sync the changes.

### Current Credentials Reference

| Service | Environment | Username | Password/Token |
|---------|-------------|----------|----------------|
| PostgreSQL | Dev/Prod | `fundamental` | `WsqVTUish0Lf8uUvzySQlskd` |
| Redis | Dev/Prod | N/A | `W3KozHkqRybVdXxeJHxThz4K` |
| Registry | Shared | `admin` | `Mostafa313@#` |
| ArgoCD | Shared | `admin` | `kKl04Nlsg8B10LbK` |
| K8s Dashboard | Shared | Token | See below |

**Kubernetes Dashboard Token:**
```
eyJhbGciOiJSUzI1NiIsImtpZCI6IkNJeXBIYTBueVVTZWtNUm9nQm1oZTdzV0REdng1MHA3M290SFotUHdtN1UifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJtaWNyb2s4cy1kYXNoYm9hcmQtdG9rZW4iLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZGVmYXVsdCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6ImFiMDUyNWZlLTgxYTMtNDBiYi04NTdhLTkwM2Q2MmY1NTUwMSIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlLXN5c3RlbTpkZWZhdWx0In0.feJ4dxFXItDMGCOQBpHqdtYC_M3HWCBc5_PKvUIW2_opH2GQUAcBgehzBl30Sg6vJb8C95Bd7vFbFZ_knIpEhBF4xQbRSoV6NEf_9Lq4BaiOKM_aicC7QwdPvLuIkxtjOIG-yqHy5qSrUVu-1W2WqVoOBgPGeYIXjANDZxNgTrQ5N6qMS_AbMPPdwe81cbPdgIJN8jbW8NeIaISE4tqmkoUvXTqaxL8zUqIHgimNC3qIHM6WkirsoNk6CxTi0ul6iL0basrRNP1XRBr83FAFAp6n3mECc6Q99wR8_N0_Sh8JJMqTL5TZSyt0NDdRDJOVZVSjDHaTde9Qm-DQoKW5Fw
```

**To refresh the token (if needed):**
```bash
ssh root@5.10.248.55 'microk8s kubectl describe secret -n kube-system microk8s-dashboard-token | grep "^token:"'
# Or from saved file:
ssh root@5.10.248.55 'cat /root/.fundamental-credentials/kubernetes-dashboard-token'
```

### Database Connection Details

| Environment | Host | Port | Database | 
|-------------|------|------|----------|
| Dev (external) | 5.10.248.55 | 30432 | fundamental_dev |
| Prod (internal) | `*.fundamental-prod.svc.cluster.local` | 5432 | fundamental_prod |

---

## Common Tasks

### Checking Deployment Status

```bash
# SSH to VPS
ssh root@5.10.248.55

# Check pods in dev
microk8s kubectl -n fundamental-dev get pods

# Check pods in prod
microk8s kubectl -n fundamental-prod get pods

# Check ArgoCD sync status
microk8s kubectl -n argocd get applications
```

### Viewing Logs

```bash
# Dev backend logs
microk8s kubectl -n fundamental-dev logs -l app.kubernetes.io/component=backend -f

# Prod backend logs
microk8s kubectl -n fundamental-prod logs -l app.kubernetes.io/component=backend -f
```

### Force Sync ArgoCD

```bash
# Sync dev
microk8s kubectl -n argocd patch application fundamental-dev \
  --type merge -p '{"operation": {"sync": {}}}'

# Sync prod
microk8s kubectl -n argocd patch application fundamental-prod \
  --type merge -p '{"operation": {"sync": {}}}'
```

### Updating Configuration

```bash
# 1. Edit config.yaml
vim config.yaml

# 2. Regenerate all files
./scripts/generate-config.sh

# 3. Commit changes
git add -A
git commit -m "chore: Update configuration"
git push
```

### Rolling Back

```bash
# Via ArgoCD UI or CLI
microk8s kubectl -n argocd patch application fundamental-dev \
  -p '{"spec": {"source": {"targetRevision": "COMMIT_SHA"}}}'
```

---

## Troubleshooting

### Pods Not Starting

```bash
# Check events
microk8s kubectl -n fundamental-dev get events --sort-by='.lastTimestamp'

# Describe failing pod
microk8s kubectl -n fundamental-dev describe pod POD_NAME
```

### Image Pull Errors

```bash
# Check registry credentials secret
microk8s kubectl -n fundamental-dev get secret registry-credentials -o yaml

# Test registry access from node
curl -u fundamental:PASSWORD https://registry.academind.ir/v2/_catalog
```

### Database Connection Issues

```bash
# Check PostgreSQL pod
microk8s kubectl -n fundamental-dev exec -it postgresql-0 -- psql -U fundamental -d fundamental_dev

# Check connection string in backend
microk8s kubectl -n fundamental-dev get secret fundamental-backend-secrets -o yaml
```

### SSL Certificate Issues

```bash
# Check certificates
microk8s kubectl get certificates -A

# Check cert-manager logs
microk8s kubectl -n cert-manager logs -l app=cert-manager -f
```

### ArgoCD Sync Issues

```bash
# Check application status
microk8s kubectl -n argocd describe application fundamental-dev

# Check ArgoCD server logs
microk8s kubectl -n argocd logs -l app.kubernetes.io/name=argocd-server -f
```

---

## GitHub Repository Secrets

The following secrets must be configured in Backend/Frontend repos:

| Secret | Description |
|--------|-------------|
| `REGISTRY_USERNAME` | Container registry username (`fundamental`) |
| `REGISTRY_PASSWORD` | Container registry password |
| `INFRA_REPO_TOKEN` | GitHub PAT for triggering Infra workflow |

---

## Related Repositories

| Repository | Description | Branch Strategy |
|------------|-------------|-----------------|
| [Fundamental.Backend](https://github.com/PeSahm/Fundamental.Backend) | .NET 9 API | develop → dev, main → prod |
| [Fundamental.FrontEnd](https://github.com/PeSahm/Fundamental.FrontEnd) | Angular frontend | develop → dev, main → prod |
| [Fundamental.Infra](https://github.com/PeSahm/Fundamental.Infra) | This repo | develop → dev values, main → prod values |

---

## License

MIT License - see [LICENSE](LICENSE) for details.
