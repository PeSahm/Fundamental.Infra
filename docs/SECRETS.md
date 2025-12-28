# Secrets & Environment Variables Configuration

Complete reference for all secrets, environment variables, and credentials required for the Fundamental infrastructure.

> ⚠️ **SECURITY WARNING**: Never commit actual secret values. This document only describes what is needed and where to find them.

---

## 📋 Table of Contents

- [Quick Reference](#quick-reference)
- [Local Environment Variables (.env)](#local-environment-variables-env)
- [GitHub Actions Secrets](#github-actions-secrets)
- [Kubernetes Secrets (Helm)](#kubernetes-secrets-helm)
- [Automated Secrets](#automated-secrets)
- [Manual Secrets](#manual-secrets)
- [Backend Repository Secrets](#backend-repository-secrets)
- [Frontend Repository Secrets](#frontend-repository-secrets)
- [Credentials Reference](#credentials-reference)

---

## Quick Reference

### Automation Summary

| Secret Category | Auto-Generated | Auto-Deployed to GitHub | Manual Setup |
|-----------------|----------------|-------------------------|--------------|
| Registry credentials | ✅ Ansible | ✅ Terraform | - |
| Sentry credentials | ✅ Ansible | ✅ Ansible | - |
| ArgoCD password | ✅ Ansible | N/A (K8s only) | - |
| K8s Dashboard token | ✅ Ansible | N/A (K8s only) | - |
| Database passwords | ✅ Helm | N/A (K8s only) | - |
| Cloudflare tokens | ❌ Manual | - | `.env` file |
| GitHub PAT | ❌ Manual | - | `.env` file + GitHub secrets |

---

## Local Environment Variables (.env)

Required for running Terraform/Terragrunt and Ansible locally.

### Setup

```bash
# Copy template and fill in values
cp infrastructure/.env.example infrastructure/.env

# Load before running commands
source infrastructure/.env
```

### Required Variables

#### Cloudflare (DNS Management)

| Variable | Description | How to Get |
|----------|-------------|------------|
| `CLOUDFLARE_API_TOKEN_DEV` | API token for academind.ir | [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens) → Create Token → "Edit zone DNS" template |
| `CLOUDFLARE_ZONE_ID_DEV` | Zone ID for academind.ir | Cloudflare Dashboard → academind.ir → Right sidebar → Zone ID |
| `CLOUDFLARE_API_TOKEN_PROD` | API token for sahmbaz.ir | Same as above, for production domain |
| `CLOUDFLARE_ZONE_ID_PROD` | Zone ID for sahmbaz.ir | Same as above, for production domain |

**Token Permissions Required:**
- Zone: DNS: Edit
- Zone: Zone: Read
- Zone Resources: Include → Specific zone → (your zone)

#### GitHub (Terraform)

| Variable | Description | How to Get |
|----------|-------------|------------|
| `GITHUB_TOKEN` | Personal Access Token | [GitHub Settings](https://github.com/settings/tokens) → Generate new token (classic) |

**Token Permissions Required (Classic):**
- `repo` (Full control of private repositories)
- `admin:repo_hook` (Admin access to repository hooks)
- `workflow` (Update GitHub Action workflows)

#### Container Registry (Terraform)

| Variable | Description | How to Get |
|----------|-------------|------------|
| `REGISTRY_USER` | Registry username | Default: `fundamental` |
| `REGISTRY_PASSWORD` | Registry password | `ssh root@VPS cat /root/.fundamental-credentials/registry-credentials.txt` |

#### Sentry (Terraform)

| Variable | Description | How to Get |
|----------|-------------|------------|
| `SENTRY_DSN` | Data Source Name | Sentry → Project Settings → Client Keys |
| `SENTRY_AUTH_TOKEN` | API auth token | `ssh root@VPS cat /root/.fundamental-credentials/sentry-credentials.txt` |

#### SSH (VPS Access)

| Variable | Description | How to Get |
|----------|-------------|------------|
| `SSH_PRIVATE_KEY` | Private key (base64 encoded) | `cat ~/.ssh/id_rsa \| base64 -w0` |

---

## Kubernetes Secrets (Helm)

Secrets referenced via `existingSecret` pattern in Helm values.

### Namespace: `fundamental-dev` / `fundamental-prod`

| Secret Name | Keys | Created By | Referenced In |
|-------------|------|------------|---------------|
| `registry-credentials` | `.dockerconfigjson` | Ansible | `imagePullSecrets` |
| `postgresql-credentials` | `password` | Helm | `backend.database.existingSecret` |
| `redis-credentials` | `password` | Helm | `backend.redis.existingSecret` |

### Namespace: `sentry`

| Secret Name | Keys | Created By |
|-------------|------|------------|
| `sentry-secrets` | `secret-key`, `postgres-password`, `redis-password`, `admin-email`, `admin-password` | Ansible |

### Namespace: `argocd`

| Secret Name | Keys | Created By |
|-------------|------|------------|
| `argocd-initial-admin-secret` | `password` | ArgoCD |
| `argocd-repo-creds-fundamental` | `password` (GitHub token) | Ansible |

---

## Base Images Required in Registry

The following images must be available in `registry.academind.ir` for CI/CD:

| Image | Tag | Used By | How to Add |
|-------|-----|---------|------------|
| `library/nginx` | `1.27-alpine` | Frontend Dockerfile | See commands below |

```bash
# On VPS: Pull from Docker Hub and push to local registry
docker pull nginx:1.27-alpine
docker tag nginx:1.27-alpine localhost:32000/library/nginx:1.27-alpine
docker push localhost:32000/library/nginx:1.27-alpine
```

> Note: Backend uses Microsoft Container Registry (`mcr.microsoft.com`) which is accessible.

---

## Automated Secrets

These secrets are automatically created and configured by Ansible playbooks:

### Registry Credentials
- **Created by**: `ansible/playbooks/setup-registry-proxy.yaml`
- **Saved to**: `/root/.fundamental-credentials/registry-credentials.txt`
- **GitHub update**: Via Terraform (`infrastructure/live/development/github/`)

### Sentry Credentials
- **Created by**: `ansible/playbooks/deploy-sentry.yaml`
- **Saved to**: `/root/.fundamental-credentials/sentry-credentials.txt`
- **GitHub update**: ✅ **Automatic** - Ansible updates GitHub secrets directly via `gh secret set`

The Sentry playbook automatically:
1. Creates `fundamental` organization in Sentry
2. Creates `fundamental-backend` and `fundamental-angular-admin` projects
3. Generates API auth token with CI/CD scopes
4. Updates `SENTRY_AUTH_TOKEN` and `SENTRY_DSN` in both GitHub repos

---

## GitHub Actions Variables (Non-Secret)

These are set by Terraform and visible in repository settings:

| Variable | Value | Purpose |
|----------|-------|---------|
| `CONTAINER_REGISTRY` | `registry.academind.ir` | Docker registry URL |
| `DOMAIN` | `dev.academind.ir` / `sahmbaz.ir` | Deployment domain |
| `SENTRY_ENABLED` | `true` | Enable/disable Sentry |
| `SENTRY_UPLOAD_SOURCEMAPS` | `true` | Enable/disable source map upload |

---

## Manual Secrets

### INFRA_REPO_TOKEN

A GitHub Personal Access Token (PAT) that allows Backend/Frontend repos to trigger workflows in the Infra repo.

**Required permissions:**
- `repo` (Full control of private repositories)
- `workflow` (Update GitHub Action workflows)

**How to create:**
1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with `repo` and `workflow` scopes
3. Set expiration as needed (recommend 90 days)
4. Copy token and set in both repos:
   ```bash
   echo "<YOUR_PAT>" | gh secret set INFRA_REPO_TOKEN --repo PeSahm/Fundamental.Backend
   echo "<YOUR_PAT>" | gh secret set INFRA_REPO_TOKEN --repo PeSahm/Fundamental.FrontEnd
   ```

---

## Backend Repository Secrets

Repository: `PeSahm/Fundamental.Backend`

| Secret Name | Description | Auto | Source |
|-------------|-------------|------|--------|
| `REGISTRY_USERNAME` | Container registry username | ✅ | `registry-credentials.txt` |
| `REGISTRY_PASSWORD` | Container registry password | ✅ | `registry-credentials.txt` |
| `SENTRY_AUTH_TOKEN` | Sentry API auth token | ✅ | Ansible → GitHub |
| `SENTRY_DSN` | Sentry DSN for backend | ✅ | Ansible → GitHub |
| `INFRA_REPO_TOKEN` | GitHub PAT | ❌ | Manual |

**Sentry Configuration:**
- Organization: `fundamental`
- Project: `fundamental-backend`
- Platform: `.NET`

---

## Frontend Repository Secrets

Repository: `PeSahm/Fundamental.FrontEnd`

| Secret Name | Description | Auto | Source |
|-------------|-------------|------|--------|
| `REGISTRY_USERNAME` | Container registry username | ✅ | `registry-credentials.txt` |
| `REGISTRY_PASSWORD` | Container registry password | ✅ | `registry-credentials.txt` |
| `SENTRY_AUTH_TOKEN` | Sentry API auth token | ✅ | Ansible → GitHub |
| `SENTRY_DSN` | Sentry DSN for frontend | ✅ | Ansible → GitHub |
| `INFRA_REPO_TOKEN` | GitHub PAT | ❌ | Manual |

**Sentry Configuration:**
- Organization: `fundamental`
- Project: `fundamental-angular-admin`
- Platform: `javascript-angular`

---

## Infra Repository Secrets

Repository: `PeSahm/Fundamental.Infra`

| Secret Name | Description | Where to Get |
|-------------|-------------|--------------|
| `SSH_PRIVATE_KEY` | Base64-encoded SSH private key for VPS | Your SSH key (base64 encoded) |
| `VPS_HOST` | VPS IP address | Server IP |
| `VPS_USER` | SSH user | Usually `root` |

---

## How to Set Secrets

### Via GitHub CLI

```bash
# Set a secret
echo "secret-value" | gh secret set SECRET_NAME --repo PeSahm/<repo>

# Set from file
gh secret set SECRET_NAME --repo PeSahm/<repo> < file.txt

# List secrets
gh api repos/PeSahm/<repo>/actions/secrets --jq '.secrets[].name'
```

### Via GitHub Web UI

1. Go to repository → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Enter name and value
4. Click "Add secret"

---

## Credentials Reference

### Server Credentials Location

All credentials are saved on the VPS at:
```
/root/.fundamental-credentials/
├── argocd-credentials.txt     # ArgoCD admin password
├── k8s-dashboard-credentials.txt  # K8s dashboard token
├── registry-credentials.txt   # Container registry credentials
└── sentry-credentials.txt     # Sentry admin + API tokens + DSNs
```

### Container Registry

- **URL**: `registry.academind.ir`
- **Username**: `fundamental`
- **Password**: See `/root/.fundamental-credentials/registry-credentials.txt`

```bash
# Test login
docker login registry.academind.ir -u fundamental -p '<password>'
```

### Sentry

- **URL**: `https://sentry.academind.ir`
- **Admin User**: `admin@academind.ir`
- **Organization**: `sentry`
- **Projects**:
  - `backend` (ID: 2) - .NET backend
  - `frontend` (ID: 3) - Angular frontend

#### Creating a New Auth Token (if needed)

```bash
ssh root@<VPS_IP> 'microk8s kubectl exec -n sentry deployment/sentry-web -- sentry django shell -c "
from django.contrib.auth import get_user_model
from sentry.models.apitoken import ApiToken
User = get_user_model()
user = User.objects.get(email=\"admin@academind.ir\")
token = ApiToken.objects.create(user=user, scope_list=[\"project:read\", \"project:write\", \"project:releases\", \"org:read\"])
print(f\"Token: {token.token}\")
"'
```

---

## Quick Setup Script

After fresh infrastructure deployment, run this to configure all GitHub secrets:

```bash
#!/bin/bash
# Usage: ./setup-secrets.sh <VPS_IP>

VPS_IP=${1:-"5.10.248.55"}

# Fetch credentials from server
REGISTRY_USER="fundamental"
REGISTRY_PASS=$(ssh root@$VPS_IP "grep 'Password:' /root/.fundamental-credentials/registry-credentials.txt | awk '{print \$2}'")
SENTRY_TOKEN=$(ssh root@$VPS_IP "grep 'Auth Token:' /root/.fundamental-credentials/sentry-credentials.txt | awk '{print \$3}'")
BACKEND_DSN=$(ssh root@$VPS_IP "grep 'Backend DSN:' /root/.fundamental-credentials/sentry-credentials.txt | awk '{print \$3}'")
FRONTEND_DSN=$(ssh root@$VPS_IP "grep 'Frontend DSN:' /root/.fundamental-credentials/sentry-credentials.txt | awk '{print \$3}'")

# Set Backend secrets
echo "$REGISTRY_USER" | gh secret set REGISTRY_USERNAME --repo PeSahm/Fundamental.Backend
echo "$REGISTRY_PASS" | gh secret set REGISTRY_PASSWORD --repo PeSahm/Fundamental.Backend
echo "$SENTRY_TOKEN" | gh secret set SENTRY_AUTH_TOKEN --repo PeSahm/Fundamental.Backend
echo "$BACKEND_DSN" | gh secret set SENTRY_DSN --repo PeSahm/Fundamental.Backend

# Set Frontend secrets
echo "$REGISTRY_USER" | gh secret set REGISTRY_USERNAME --repo PeSahm/Fundamental.FrontEnd
echo "$REGISTRY_PASS" | gh secret set REGISTRY_PASSWORD --repo PeSahm/Fundamental.FrontEnd
echo "$SENTRY_TOKEN" | gh secret set SENTRY_AUTH_TOKEN --repo PeSahm/Fundamental.FrontEnd
echo "$FRONTEND_DSN" | gh secret set SENTRY_DSN --repo PeSahm/Fundamental.FrontEnd

echo "All secrets configured!"
```

---

## Automation Status

| Credential | Auto-Generated | Auto-Saved | Manual Setup |
|------------|----------------|------------|--------------|
| Registry credentials | ✅ Ansible | ✅ Server file | GitHub secrets |
| ArgoCD password | ✅ Ansible | ✅ Server file | N/A |
| K8s Dashboard token | ✅ Ansible | ✅ Server file | N/A |
| Sentry admin | ✅ Ansible | ✅ Server file | N/A |
| Sentry auth token | ❌ Manual | ✅ Server file | GitHub secrets |
| Sentry DSNs | ❌ Manual | ✅ Server file | GitHub secrets |
| GitHub PAT (INFRA_REPO_TOKEN) | ❌ Manual | ❌ | GitHub secrets |

### Future Improvements

1. **Ansible automation**: Add tasks to create Sentry projects and tokens automatically
2. **GitHub secrets**: Use Terraform/Terragrunt to manage GitHub secrets
3. **External Secrets Operator**: Pull secrets from vault into Kubernetes

---

## Troubleshooting

### Registry Login Fails (401 Unauthorized)

```bash
# Check registry password on server
ssh root@<VPS_IP> cat /root/.fundamental-credentials/registry-credentials.txt

# Update GitHub secret
echo "<password>" | gh secret set REGISTRY_PASSWORD --repo PeSahm/Fundamental.Backend
```

### Sentry Auth Token Invalid (401)

```bash
# Create new token on server (see above)
# Then update GitHub secrets
echo "<new-token>" | gh secret set SENTRY_AUTH_TOKEN --repo PeSahm/Fundamental.Backend
echo "<new-token>" | gh secret set SENTRY_AUTH_TOKEN --repo PeSahm/Fundamental.FrontEnd
```

### Cloudflare API Token Invalid

1. Go to [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Create new token with "Edit zone DNS" template
3. Scope to specific zone
4. Update `infrastructure/.env` with new token
5. Re-run Terraform: `cd infrastructure/live/development/dns && terragrunt apply`

### Missing Local Environment Variables

```bash
# Check which variables are set
env | grep -E "CLOUDFLARE|GITHUB|REGISTRY|SENTRY|SSH"

# Source the .env file
source infrastructure/.env
```

### Check Current Secrets

```bash
# List secrets (names only, not values)
gh api repos/PeSahm/Fundamental.Backend/actions/secrets --jq '.secrets[].name'
gh api repos/PeSahm/Fundamental.FrontEnd/actions/secrets --jq '.secrets[].name'
```
