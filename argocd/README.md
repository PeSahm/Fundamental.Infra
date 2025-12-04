# ArgoCD GitOps Configuration

GitOps manifests for deploying the Fundamental application stack using ArgoCD.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Directory Structure](#directory-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [GitOps Workflow](#gitops-workflow)
- [Troubleshooting](#troubleshooting)

## Overview

This directory contains ArgoCD Application and Project manifests that enable:

- **Declarative Deployments**: All configuration is in Git
- **Automated Sync**: Changes trigger deployments automatically
- **Environment Separation**: Dev and Prod are isolated
- **RBAC**: Role-based access control via Projects

## Architecture

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GitOps Flow                                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Developer  │     │  CI/CD      │     │  Infra Repo │     │   ArgoCD    │
│  Commit     │────▶│  Pipeline   │────▶│  (Git)      │────▶│  Controller │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                           │                   │                   │
                           │                   │                   │
                           ▼                   ▼                   ▼
                    Build & Push         update-tag.yml       Sync & Deploy
                    to Registry          updates values        to Kubernetes
                           │                   │                   │
                           │                   │                   ▼
                           │                   │            ┌─────────────┐
                           │                   │            │ Kubernetes  │
                           └───────────────────┴───────────▶│ Cluster     │
                                                            └─────────────┘
```

## Directory Structure

```text
argocd/
├── README.md
├── applications/
│   ├── fundamental-dev.yaml    # Development environment
│   └── fundamental-prod.yaml   # Production environment
└── projects/
    └── fundamental.yaml        # RBAC and source/destination rules
```

## Prerequisites

### 1. ArgoCD Installed

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl -n argocd wait --for=condition=available --timeout=300s deployment/argocd-server
```

### 2. ArgoCD CLI (Optional but Recommended)

```bash
# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# macOS
brew install argocd
```

### 3. Update Repository URL

Before applying, update the `repoURL` in application manifests:

```yaml
# In fundamental-dev.yaml and fundamental-prod.yaml
source:
  repoURL: "https://github.com/YOUR_ORG/Fundamental.Infra.git"  # <-- Update this
```

## Installation

### Step 1: Apply Project

```bash
kubectl apply -f argocd/projects/fundamental.yaml
```

### Step 2: Apply Development Application

```bash
kubectl apply -f argocd/applications/fundamental-dev.yaml
```

### Step 3: Apply Production Application

```bash
kubectl apply -f argocd/applications/fundamental-prod.yaml
```

### Step 4: Verify

```bash
# Using ArgoCD CLI
argocd app list

# Using kubectl
kubectl -n argocd get applications
```

## Usage

### Access ArgoCD UI

```bash
# Port forward (for local access)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Or use LoadBalancer/Ingress in production
```

### Get Admin Password

```bash
# Get initial password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Login with CLI
argocd login localhost:8080 --username admin --password <password> --insecure
```

### Sync Applications

```bash
# Sync development (usually automatic)
argocd app sync fundamental-dev

# Sync production (manual required)
argocd app sync fundamental-prod

# Force sync with prune
argocd app sync fundamental-dev --prune
```

### View Application Status

```bash
# Get application details
argocd app get fundamental-dev

# Get sync status
argocd app get fundamental-dev --refresh

# View live manifests
argocd app manifests fundamental-dev
```

### Rollback

```bash
# List history
argocd app history fundamental-prod

# Rollback to specific revision
argocd app rollback fundamental-prod <revision>

# Rollback to previous
argocd app rollback fundamental-prod
```

## GitOps Workflow

### Sync Policies

| Environment | Auto Sync | Self Heal | Prune | Manual Approval |
|-------------|-----------|-----------|-------|-----------------|
| Development | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| Production | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |

### Image Update Flow

1. **CI/CD Pipeline** builds new image and pushes to registry
2. **CI triggers** `repository_dispatch` event to this repo
3. **GitHub Action** (`update-tag.yml`) updates `values-{env}.yaml`
4. **Git commit** triggers ArgoCD sync (dev) or marks out-of-sync (prod)
5. **ArgoCD** deploys new version to Kubernetes

### Triggering Image Updates

From your Backend/Frontend CI:

```bash
# Example: Update backend to v1.2.3 in prod
gh api repos/YOUR_ORG/Fundamental.Infra/dispatches \
  --method POST \
  --field event_type=update-image-tag \
  --field "client_payload[component]=backend" \
  --field "client_payload[tag]=v1.2.3" \
  --field "client_payload[environment]=prod"
```

## Troubleshooting

### Application Out of Sync

```bash
# Check what's different
argocd app diff fundamental-dev

# View detailed sync status
argocd app get fundamental-dev --show-operation
```

### Sync Failed

```bash
# Get sync result
argocd app sync-result fundamental-dev

# Check events
kubectl -n argocd get events --sort-by='.lastTimestamp'
```

### Health Status Issues

```bash
# Check resource health
argocd app resources fundamental-dev

# Get pod logs
kubectl -n fundamental-dev logs -l app.kubernetes.io/name=fundamental-backend
```

### Repository Connection Issues

```bash
# List repos
argocd repo list

# Add repo with credentials
argocd repo add https://github.com/YOUR_ORG/Fundamental.Infra.git \
  --username git \
  --password <PAT>
```

### Reset ArgoCD

```bash
# Hard refresh
argocd app get fundamental-dev --hard-refresh

# Delete and recreate app
argocd app delete fundamental-dev
kubectl apply -f argocd/applications/fundamental-dev.yaml
```

## Best Practices

1. **Never modify live resources directly** - Always change Git
2. **Use semantic versioning** for image tags
3. **Review sync status** before production deployments
4. **Enable notifications** for sync events
5. **Use Projects** to isolate teams and environments

## Notifications (Optional)

Configure ArgoCD Notifications for Slack/Teams alerts:

```bash
# Install ArgoCD Notifications
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/stable/manifests/install.yaml

# Configure Slack webhook
kubectl -n argocd create secret generic argocd-notifications-secret \
  --from-literal=slack-token=<SLACK_TOKEN>
```

## License

MIT
