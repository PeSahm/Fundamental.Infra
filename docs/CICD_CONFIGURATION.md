# CI/CD Configuration Reference

This document describes the CI/CD configuration derived from `config.yaml`.

## Branch Strategy

| Branch | Environment | Domain | Image Tag | Namespace |
|--------|-------------|--------|-----------|-----------|
| `develop` | Development | dev.academind.ir | `dev-latest` | fundamental-dev |
| `main` | Production | sahmbaz.ir | `prod-latest` | fundamental-prod |

## Container Registry

- **Registry URL**: `registry.academind.ir`
- **Backend Image**: `registry.academind.ir/fundamental-backend`
- **Frontend Image**: `registry.academind.ir/fundamental-frontend`
- **Migrations Image**: `registry.academind.ir/fundamental-migrations`

## GitHub Actions Workflow Configuration

### Backend Workflow Triggers

```yaml
on:
  push:
    branches:
      - develop    # Triggers dev deployment
      - main   # Triggers prod deployment
```

### Image Tagging Logic

```yaml
env:
  IMAGE_TAG: ${{ github.ref == 'refs/heads/main' && 'prod-latest' || 'dev-latest' }}
```

### Environment Detection

```yaml
env:
  ENVIRONMENT: ${{ github.ref == 'refs/heads/main' && 'production' || 'development' }}
```

## Deployment Flow

1. **Push to `develop`**:
   - Build images with tag `dev-latest`
   - Push to `registry.academind.ir`
   - ArgoCD detects change → deploys to `fundamental-dev`

2. **Push to `main`**:
   - Build images with tag `prod-latest`
   - Push to `registry.academind.ir`
   - ArgoCD detects change → deploys to `fundamental-prod`

## Secrets Required

GitHub repository secrets needed:

- `REGISTRY_USERNAME`: Container registry username
- `REGISTRY_PASSWORD`: Container registry password
- `REGISTRY_URL`: `registry.academind.ir`

---

*Auto-generated from config.yaml - Run `./scripts/generate-config.sh` to regenerate*
