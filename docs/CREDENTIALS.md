# Credentials Management Guide

This document explains where credentials are stored and how to manage them for the Fundamental infrastructure.

> ⚠️ **SECURITY WARNING**: Never commit actual credentials to version control. This file only documents **where** to store them, not the actual values.

## 📁 Credential Storage Locations

### 1. Local Development: `infrastructure/.env`

This file contains all credentials needed to run Terragrunt locally.

```bash
# Location
infrastructure/.env

# Usage
cd infrastructure && source .env
cd live/production/dns && terragrunt apply
```

**This file is in `.gitignore` - NEVER commit it!**

### 2. Template File: `infrastructure/.env.example`

A template showing all required environment variables (without actual values).

```bash
# Copy and customize
cp infrastructure/.env.example infrastructure/.env
# Edit with your values
nano infrastructure/.env
```

---

## 🔑 Required Credentials

### Cloudflare API Tokens

We use **separate tokens per domain** for better security isolation.

| Environment | Domain | Variable | Zone ID Variable |
|-------------|--------|----------|------------------|
| Development | academind.ir | `CLOUDFLARE_API_TOKEN_DEV` | `CLOUDFLARE_ZONE_ID_DEV` |
| Production | sahmbaz.ir | `CLOUDFLARE_API_TOKEN_PROD` | `CLOUDFLARE_ZONE_ID_PROD` |

**How to create API tokens:**

1. Go to [Cloudflare Dashboard → API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click "Create Token"
3. Use "Edit zone DNS" template
4. **Scope to specific zone only** (academind.ir OR sahmbaz.ir)
5. Copy the token immediately (shown only once!)

**How to get Zone ID:**

1. Go to Cloudflare Dashboard → Select your zone
2. Look at the right sidebar under "API" section
3. Copy the "Zone ID"

### GitHub Personal Access Token

| Variable | Purpose |
|----------|---------|
| `GITHUB_TOKEN` | Configure repository secrets, environments |

**Required permissions:**
- Repository: Actions (RW), Environments (RW), Metadata (R), Secrets (RW)

### Container Registry

| Variable | Purpose |
|----------|---------|
| `REGISTRY_USER` | Registry username |
| `REGISTRY_PASSWORD` | Registry password |

Used for: `registry.academind.ir`

### SSH Key

| Variable | Purpose |
|----------|---------|
| `SSH_PRIVATE_KEY` | Base64-encoded SSH private key for VPS access |

---

## 🏗️ Infrastructure Credentials in Use

### Development Environment (academind.ir)

Used by: `infrastructure/live/development/dns/terragrunt.hcl`

```hcl
api_token = get_env("CLOUDFLARE_API_TOKEN_DEV", "")
zone_id   = get_env("CLOUDFLARE_ZONE_ID_DEV", "")
```

DNS Records managed:
- `dev.academind.ir` → Frontend (dev)
- `dev-api.academind.ir` → Backend API (dev)
- `argocd.academind.ir` → ArgoCD (shared)
- `registry.academind.ir` → Container Registry (shared)

### Production Environment (sahmbaz.ir)

Used by: `infrastructure/live/production/dns/terragrunt.hcl`

```hcl
api_token = get_env("CLOUDFLARE_API_TOKEN_PROD", "")
zone_id   = get_env("CLOUDFLARE_ZONE_ID_PROD", "")
```

DNS Records managed:
- `sahmbaz.ir` → Frontend (prod)
- `www.sahmbaz.ir` → Frontend (prod)
- `api.sahmbaz.ir` → Backend API (prod)

---

## 🔄 Credential Rotation

### When to Rotate

- After team member leaves
- If credentials may have been exposed
- Every 90 days (best practice)

### How to Rotate

1. **Cloudflare Token:**
   - Create new token in Cloudflare dashboard
   - Update `infrastructure/.env`
   - Run `terragrunt plan` to verify access
   - Revoke old token

2. **GitHub Token:**
   - Create new PAT at github.com/settings/tokens
   - Update `infrastructure/.env`
   - Update GitHub Actions secrets
   - Revoke old token

3. **After any rotation:**
   ```bash
   source infrastructure/.env
   cd infrastructure/live/production/dns && terragrunt plan
   cd ../../../development/dns && terragrunt plan
   ```

---

## 📋 Quick Reference

```bash
# Check if credentials are loaded
echo "Dev Zone: ${CLOUDFLARE_ZONE_ID_DEV:0:8}..."
echo "Prod Zone: ${CLOUDFLARE_ZONE_ID_PROD:0:8}..."

# Test Cloudflare API access (dev)
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID_DEV}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN_DEV}" | jq '.result.name'

# Test Cloudflare API access (prod)
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID_PROD}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN_PROD}" | jq '.result.name'
```

---

## 🔒 Security Best Practices

1. **Least privilege**: Each token should only have access to what it needs
2. **Separate tokens per domain**: Don't use one token for all zones
3. **Environment isolation**: Dev and prod use different credentials
4. **Audit regularly**: Check Cloudflare audit logs for token usage
5. **Never commit `.env`**: It's in `.gitignore` but double-check!
