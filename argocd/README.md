# ArgoCD Configuration

This directory contains ArgoCD Application and Project manifests for GitOps-based deployments.

## Directory Structure

```text
argocd/
├── applications/           # Application manifests
│   ├── app-dev.yaml       # Development environment app
│   └── app-prod.yaml      # Production environment app
└── projects/              # Project definitions
    └── fundamental.yaml   # Project for Fundamental apps
```

## Application Flow

```text
GitHub Push → ArgoCD Detects → Sync → Kubernetes Deploy
```

## Usage

### Apply ArgoCD Applications

```bash
# Apply project first
kubectl apply -f argocd/projects/fundamental.yaml

# Apply applications
kubectl apply -f argocd/applications/app-dev.yaml
kubectl apply -f argocd/applications/app-prod.yaml
```

### Access ArgoCD UI

```bash
# Port forward ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Sync Policies

| Environment | Auto Sync | Self Heal | Prune |
|-------------|-----------|-----------|-------|
| Development | ✅ | ✅ | ✅ |
| Production | ❌ | ✅ | ❌ |

## Image Update Strategy

1. Backend/Frontend CI pushes new image
2. CI triggers `repository_dispatch` to this repo
3. GitHub Action updates `values-{env}.yaml` with new tag
4. ArgoCD detects change and syncs
