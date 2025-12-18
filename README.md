# Fundamental Infrastructure

Complete infrastructure-as-code for deploying the Fundamental platform (Backend + Frontend) to a VPS with MicroK8s, GitOps, and automated CI/CD.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Directory Structure](#directory-structure)
- [Tools & Technologies](#tools--technologies)
- [Deployment Workflow](#deployment-workflow)
- [CI/CD Pipeline](#cicd-pipeline)
- [Access & Credentials](#access--credentials)
- [Common Tasks](#common-tasks)
- [Troubleshooting](#troubleshooting)

---

## Overview

This repository manages the complete infrastructure for the Fundamental platform using a **GitOps** approach:

- **Single Source of Truth**: All configuration in `config.yaml`
- **Infrastructure as Code**: Terragrunt for DNS/GitHub, Ansible for VPS setup
- **GitOps Deployment**: ArgoCD automatically syncs Kubernetes manifests
- **Automated CI/CD**: GitHub Actions build, test, and deploy on push

### What Gets Deployed

| Component | Description | Technology |
|-----------|-------------|------------|
| **Backend** | .NET 9 API | ASP.NET Core |
| **Frontend** | Angular SPA | Nginx |
| **Database** | PostgreSQL 17 | StatefulSet |
| **Cache** | Redis 7 | StatefulSet |
| **Registry** | Container images | MicroK8s built-in |
| **Ingress** | HTTPS routing | Nginx Ingress |
| **Certificates** | Auto SSL | Let's Encrypt + cert-manager |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLOUDFLARE DNS                                     │
│  dev.academind.ir  ──────────────────────────────────────┐                  │
│  argocd.academind.ir ────────────────────────────────────┤                  │
│  registry.academind.ir ──────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         VPS (5.10.248.55)                                    │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                      MicroK8s Cluster                                  │  │
│  │                                                                        │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                    Nginx Ingress Controller                      │  │  │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │  │  │
│  │  │  │ /api/* → BE  │  │ /* → FE     │  │ registry.* → registry│   │  │  │
│  │  │  └──────────────┘  └──────────────┘  └──────────────────────┘   │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                        │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                   fundamental-dev namespace                      │  │  │
│  │  │                                                                  │  │  │
│  │  │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │  │  │
│  │  │   │ Backend  │  │ Frontend │  │ Postgres │  │    Redis     │   │  │  │
│  │  │   │ (API)    │  │ (Nginx)  │  │   (DB)   │  │   (Cache)    │   │  │  │
│  │  │   └──────────┘  └──────────┘  └──────────┘  └──────────────┘   │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                        │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                      argocd namespace                            │  │  │
│  │  │   ArgoCD (GitOps Controller)                                     │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                        │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                 container-registry namespace                     │  │  │
│  │  │   Docker Registry (images storage)                               │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### CI/CD Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Git Push   │────▶│ GitHub       │────▶│ Build &      │────▶│ Push to      │
│   (main)     │     │ Actions      │     │ Test         │     │ Registry     │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                                                                       │
                                                                       ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   App Live   │◀────│ K8s Deploys  │◀────│ ArgoCD       │◀────│ GitOps       │
│   Updated    │     │ New Image    │     │ Syncs        │     │ Trigger      │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

---

## Quick Start

### Prerequisites

1. **Local Machine**:
   - `yq` - YAML processor
   - `ansible` - Configuration management
   - `terraform` & `terragrunt` - Infrastructure as code
   - `gh` - GitHub CLI (authenticated)
   - SSH access to VPS

2. **Install yq**:
   ```bash
   sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
   sudo chmod +x /usr/local/bin/yq
   ```

3. **Environment Variables**:
   ```bash
   export CLOUDFLARE_API_TOKEN="your-cloudflare-token"
   export CLOUDFLARE_ZONE_ID="your-zone-id"
   ```

### First-Time Setup

```bash
# 1. Clone the repository
git clone https://github.com/PeSahm/Fundamental.Infra.git
cd Fundamental.Infra

# 2. Review and customize config.yaml
vim config.yaml

# 3. Generate all configuration files
./scripts/generate-config.sh

# 4. Setup DNS records (Cloudflare)
cd infrastructure/live/development/dns
terragrunt apply

# 5. Deploy to VPS (full stack)
cd ../../../../ansible
ansible-playbook -i inventory/hosts.ini playbooks/full-deploy.yaml
```

---

## Configuration

### Single Source of Truth: `config.yaml`

All infrastructure configuration is centralized in one file. Edit this file and regenerate configs.

```yaml
# config.yaml - Key sections

domain:
  base: "academind.ir"              # Your domain
  subdomains:
    dev:
      frontend: "dev"               # dev.academind.ir
    prod:
      frontend: ""                  # academind.ir (root)

vps:
  ip: "5.10.248.55"                 # Your VPS IP

github:
  owner: "PeSahm"                   # GitHub username/org

registry:
  username: "fundamental"           # Registry auth username
  images:
    backend: "fundamental-backend"
    frontend: "fundamental-frontend"
```

### Changing Configuration

```bash
# 1. Edit config.yaml
vim config.yaml

# 2. Regenerate all config files
./scripts/generate-config.sh

# 3. Commit and push
git add -A && git commit -m "Update configuration" && git push

# 4. Apply changes
# For DNS changes:
cd infrastructure/live/development/dns && terragrunt apply

# For Kubernetes changes (automatic via ArgoCD, or manual):
ssh root@YOUR_VPS "microk8s kubectl -n argocd exec deploy/argocd-server -- \
  argocd app sync fundamental-dev --prune --server localhost:8080 --insecure --core"
```

### Generated Files

| File | Purpose | Generated From |
|------|---------|----------------|
| `infrastructure/live/terragrunt.hcl` | Root Terragrunt config | `config.yaml` |
| `ansible/group_vars/all.yaml` | Ansible variables | `config.yaml` |
| `charts/fundamental-stack/values-dev.yaml` | Dev Helm values | `config.yaml` |
| `charts/fundamental-stack/values-prod.yaml` | Prod Helm values | `config.yaml` |

---

## Directory Structure

```
Fundamental.Infra/
├── config.yaml                    # ⭐ SINGLE SOURCE OF TRUTH
├── scripts/
│   └── generate-config.sh         # Configuration generator
│
├── ansible/                       # VPS Setup & Configuration
│   ├── inventory/
│   │   └── hosts.ini              # VPS host definition
│   ├── group_vars/
│   │   └── all.yaml               # Generated variables
│   └── playbooks/
│       ├── full-deploy.yaml       # Complete deployment
│       ├── setup-vps.yaml         # Initial VPS setup
│       ├── setup-argocd.yaml      # ArgoCD installation
│       ├── setup-cert-manager.yaml # SSL certificates
│       ├── setup-registry-proxy.yaml # Container registry
│       ├── setup-kubernetes-secrets.yaml # K8s secrets
│       ├── setup-github-secrets.yaml # GitHub Actions secrets
│       └── deploy-applications.yaml # ArgoCD apps
│
├── charts/                        # Helm Charts
│   └── fundamental-stack/
│       ├── Chart.yaml
│       ├── values.yaml            # Default values
│       ├── values-dev.yaml        # Generated dev values
│       ├── values-prod.yaml       # Generated prod values
│       └── templates/
│           ├── backend/           # Backend deployment
│           ├── frontend/          # Frontend deployment
│           ├── postgresql/        # Database
│           ├── redis/             # Cache
│           ├── ingress-backend.yaml
│           ├── ingress-frontend.yaml
│           └── ingress-registry.yaml
│
├── infrastructure/                # Terragrunt/Terraform
│   ├── live/
│   │   ├── terragrunt.hcl         # Generated root config
│   │   ├── development/
│   │   │   ├── dns/               # Dev DNS records
│   │   │   └── github/            # GitHub secrets
│   │   └── production/
│   │       ├── dns/               # Prod DNS records
│   │       └── github/            # GitHub secrets
│   └── modules/
│       ├── cloudflare-dns/        # DNS module
│       └── github-secrets/        # GitHub module
│
├── argocd/                        # ArgoCD Applications
│   ├── applications/
│   │   └── fundamental-dev.yaml   # Dev environment app
│   └── projects/
│       └── fundamental.yaml       # ArgoCD project
│
└── environments/                  # Environment-specific configs
    ├── dev/
    └── prod/
```

---

## Tools & Technologies

| Tool | Purpose | Why |
|------|---------|-----|
| **MicroK8s** | Kubernetes | Lightweight, single-node friendly |
| **ArgoCD** | GitOps | Auto-sync K8s from Git |
| **Helm** | Package manager | Templated K8s manifests |
| **Terragrunt/Terraform** | IaC | DNS, GitHub config |
| **Ansible** | Configuration | VPS setup automation |
| **cert-manager** | SSL | Auto Let's Encrypt certs |
| **GitHub Actions** | CI/CD | Build, test, push images |

---

## Deployment Workflow

### Automated (CI/CD)

1. Developer pushes to `main` branch
2. GitHub Actions:
   - Runs tests
   - Builds Docker image
   - Pushes to registry (`registry.academind.ir`)
   - Triggers GitOps update
3. ArgoCD detects change and syncs
4. New pods deployed with new image

### Manual Deployment

```bash
# Full fresh deployment
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/full-deploy.yaml

# Just sync ArgoCD (apply Helm changes)
ssh root@5.10.248.55 "microk8s kubectl -n argocd exec deploy/argocd-server -- \
  argocd app sync fundamental-dev --prune --server localhost:8080 --insecure --core"

# Force image pull (same tag, new image)
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev rollout restart \
  deploy/fundamental-dev-fundamental-stack-backend"
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev rollout restart \
  deploy/fundamental-dev-fundamental-stack-frontend"
```

---

## CI/CD Pipeline

### Backend Pipeline (`.github/workflows/ci-cd.yaml`)

```
Push to main
    │
    ▼
┌─────────────┐
│ Build & Test│  dotnet build, dotnet test
└─────────────┘
    │
    ▼
┌─────────────┐
│ Build Image │  docker build -f Dockerfile
└─────────────┘
    │
    ▼
┌─────────────┐
│ Push Image  │  registry.academind.ir/fundamental-backend:prod-latest
└─────────────┘
    │
    ▼
┌─────────────┐
│ GitOps      │  Trigger Infra repo workflow
└─────────────┘
```

### Frontend Pipeline

Same flow, pushes to `registry.academind.ir/fundamental-frontend:prod-latest`

### Image Tags

| Tag | Meaning |
|-----|---------|
| `prod-latest` | Latest from `main` branch |
| `1.0.0-YYYYMMDD-COMMIT` | Versioned release |

---

## Access & Credentials

### URLs

| Service | URL |
|---------|-----|
| Dev Frontend | https://dev.academind.ir |
| Dev API | https://dev.academind.ir/api |
| ArgoCD | https://argocd.academind.ir |
| Registry | https://registry.academind.ir |

### Credentials

Stored on VPS at `/root/.fundamental-credentials/`:

```bash
# View all credentials
ssh root@5.10.248.55 "ls -la /root/.fundamental-credentials/"

# ArgoCD password
ssh root@5.10.248.55 "cat /root/.fundamental-credentials/argocd-password.txt"

# Registry credentials
ssh root@5.10.248.55 "cat /root/.fundamental-credentials/registry-credentials.txt"

# Database password
ssh root@5.10.248.55 "cat /root/.fundamental-credentials/postgresql-credentials.txt"
```

### Quick Reference

| Service | Username | Password Location |
|---------|----------|-------------------|
| ArgoCD | `admin` | `/root/.fundamental-credentials/argocd-password.txt` |
| Registry | `fundamental` | `/root/.fundamental-credentials/registry-credentials.txt` |
| PostgreSQL | `fundamental` | K8s secret `postgresql-credentials` |
| Redis | - | K8s secret `redis-credentials` |

---

## Common Tasks

### Change Domain

```bash
# 1. Edit config.yaml
vim config.yaml
# Change: domain.base: "newdomain.com"

# 2. Regenerate configs
./scripts/generate-config.sh

# 3. Update DNS (Cloudflare)
cd infrastructure/live/development/dns
terragrunt apply

# 4. Commit and push
git add -A && git commit -m "Change domain to newdomain.com" && git push

# 5. Re-run Ansible to update certs and ingress
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/full-deploy.yaml
```

### View Logs

```bash
# Backend logs
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev logs -f \
  deploy/fundamental-dev-fundamental-stack-backend"

# Frontend logs
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev logs -f \
  deploy/fundamental-dev-fundamental-stack-frontend"

# All pods
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev get pods"
```

### Restart Services

```bash
# Restart backend
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev rollout restart \
  deploy/fundamental-dev-fundamental-stack-backend"

# Restart all
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev rollout restart deploy --all"
```

### Database Access

```bash
# Connect to PostgreSQL
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev exec -it \
  fundamental-dev-fundamental-stack-postgresql-0 -- psql -U fundamental -d fundamental_dev"
```

### Check Certificates

```bash
ssh root@5.10.248.55 "microk8s kubectl get certificates --all-namespaces"
```

---

## Troubleshooting

### 502 Bad Gateway

**Cause**: Backend/Frontend pod not running or ingress misconfigured.

```bash
# Check pods
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev get pods"

# Check ingress
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev get ingress"

# Check backend logs
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev logs \
  deploy/fundamental-dev-fundamental-stack-backend"
```

### Certificate Issues

```bash
# Check certificate status
ssh root@5.10.248.55 "microk8s kubectl get certificates --all-namespaces"

# Check cert-manager logs
ssh root@5.10.248.55 "microk8s kubectl -n cert-manager logs deploy/cert-manager"

# Force certificate renewal
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev delete secret dev-academind-ir-tls"
```

### ArgoCD Sync Failed

```bash
# Check ArgoCD app status
ssh root@5.10.248.55 "microk8s kubectl -n argocd exec deploy/argocd-server -- \
  argocd app get fundamental-dev --server localhost:8080 --insecure --core"

# Force sync
ssh root@5.10.248.55 "microk8s kubectl -n argocd exec deploy/argocd-server -- \
  argocd app sync fundamental-dev --force --server localhost:8080 --insecure --core"
```

### Image Pull Errors

```bash
# Check registry secret
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev get secret registry-credentials -o yaml"

# Test registry login
docker login registry.academind.ir -u fundamental -p <password>
```

### Database Connection Issues

```bash
# Check PostgreSQL pod
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev get pods \
  -l app.kubernetes.io/component=postgresql"

# Check connection string in backend config
ssh root@5.10.248.55 "microk8s kubectl -n fundamental-dev get configmap \
  fundamental-dev-fundamental-stack-backend-config -o yaml"
```

---

## Environment Variables Reference

### Required for Terragrunt (DNS)

```bash
export CLOUDFLARE_API_TOKEN="your-token"
export CLOUDFLARE_ZONE_ID="your-zone-id"
```

### Required for GitHub CLI

```bash
gh auth login
```

### Optional Overrides

```bash
# Override Ansible variables
ansible-playbook playbooks/setup-kubernetes-secrets.yaml \
  -e "postgres_password=custom_password"
```

---

## Security Notes

1. **Secrets are auto-generated** - Random 24-64 character passwords
2. **Secrets stored in**:
   - VPS: `/root/.fundamental-credentials/`
   - K8s: Secrets in `fundamental-dev` namespace
   - GitHub: Repository secrets (for CI/CD)
3. **TLS everywhere** - Let's Encrypt certificates via cert-manager
4. **Network policies** - Pods can only communicate as needed
5. **Registry auth** - Basic auth required for push/pull

---

## Playbook Reference

| Playbook | Purpose | When to Use |
|----------|---------|-------------|
| `full-deploy.yaml` | Complete deployment | First-time setup, major updates |
| `setup-vps.yaml` | Initial VPS config | New VPS only |
| `setup-argocd.yaml` | Install ArgoCD | ArgoCD reinstall |
| `setup-cert-manager.yaml` | SSL setup | Certificate issues |
| `setup-registry-proxy.yaml` | Registry config | Registry issues |
| `setup-kubernetes-secrets.yaml` | K8s secrets | Password rotation |
| `setup-github-secrets.yaml` | GitHub secrets | CI/CD setup |
| `deploy-applications.yaml` | ArgoCD apps | App config changes |

---

## License

MIT License - See [LICENSE](LICENSE)
