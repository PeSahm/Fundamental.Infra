# GitHub Actions Secrets Configuration

This document lists all secrets required for GitHub Actions CI/CD pipelines.

> ⚠️ **SECURITY WARNING**: Never commit actual secret values. This document only describes what secrets are needed and where to get them.

## 🤖 Automated vs Manual Secrets

| Secret | Automated | Manual Setup Required |
|--------|-----------|----------------------|
| `REGISTRY_USERNAME` | ✅ Ansible generates | ❌ |
| `REGISTRY_PASSWORD` | ✅ Ansible generates | ❌ |
| `SENTRY_AUTH_TOKEN` | ✅ Ansible creates & updates GitHub | ❌ |
| `SENTRY_DSN` | ✅ Ansible creates & updates GitHub | ❌ |
| `INFRA_REPO_TOKEN` | ❌ | ✅ GitHub PAT required |

## 📋 Table of Contents

- [Automated Secrets](#automated-secrets)
- [Manual Secrets](#manual-secrets)
- [Backend Repository Secrets](#backend-repository-secrets)
- [Frontend Repository Secrets](#frontend-repository-secrets)
- [Credentials Reference](#credentials-reference)

---

## Automated Secrets

These secrets are automatically created and configured by Ansible playbooks:

### Registry Credentials
- **Created by**: `ansible/playbooks/setup-registry-proxy.yaml`
- **Saved to**: `/root/.fundamental-credentials/registry-credentials.txt`
- **GitHub update**: Must be done manually (or via Terraform)

### Sentry Credentials
- **Created by**: `ansible/playbooks/deploy-sentry.yaml`
- **Saved to**: `/root/.fundamental-credentials/sentry-credentials.txt`
- **GitHub update**: ✅ **Automatic** - Ansible updates GitHub secrets directly

The Sentry playbook automatically:
1. Creates `fundamental` organization in Sentry
2. Creates `fundamental-backend` and `fundamental-angular-admin` projects
3. Generates API auth token with CI/CD scopes
4. Updates `SENTRY_AUTH_TOKEN` and `SENTRY_DSN` in both GitHub repos

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

### Check Current Secrets

```bash
# List secrets (names only, not values)
gh api repos/PeSahm/Fundamental.Backend/actions/secrets --jq '.secrets[].name'
gh api repos/PeSahm/Fundamental.FrontEnd/actions/secrets --jq '.secrets[].name'
```
