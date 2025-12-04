# Infrastructure as Code - Terraform & Terragrunt

This directory contains the **Meta-Infrastructure** configuration using Terraform modules orchestrated by Terragrunt.

> **🎯 For .NET Developers**: Think of Terraform as "Entity Framework for Infrastructure" - you define the desired state, and Terraform figures out how to get there. Terragrunt is like a "wrapper/orchestrator" that keeps your Terraform DRY (similar to how you'd use base classes or shared projects in .NET).

## 📁 Directory Structure

```text
infrastructure/
├── modules/                    # Reusable Terraform modules (like Class Libraries)
│   ├── cloudflare-dns/         # DNS record management
│   └── github-config/          # GitHub repo, environments & secrets
└── live/                       # Terragrunt "live" configurations (like appsettings.json per env)
    ├── terragrunt.hcl          # Root config (shared settings, like Directory.Build.props)
    ├── development/            # Development environment
    │   ├── common.hcl          # Dev-specific settings
    │   ├── dns/
    │   │   └── terragrunt.hcl  # Dev DNS (dev.*, dev-api.*, dev-argocd.*)
    │   └── github/
    │       └── terragrunt.hcl  # Dev GitHub environment config
    └── production/             # Production environment
        ├── common.hcl          # Prod-specific settings
        ├── dns/
        │   └── terragrunt.hcl  # Prod DNS (@, www, api, argocd)
        └── github/
            └── terragrunt.hcl  # Prod GitHub environment config
```

---

## 🎓 Developer Guide (For .NET Developers)

### Concepts Mapping: .NET → Terraform

| .NET Concept | Terraform/Terragrunt Equivalent |
|--------------|--------------------------------|
| Class Library (.csproj) | Terraform Module (`modules/`) |
| NuGet Package | Terraform Provider (e.g., `cloudflare/cloudflare`) |
| `appsettings.json` | `variables.tf` + `terragrunt.hcl` inputs |
| `Directory.Build.props` | Root `terragrunt.hcl` (shared config) |
| `launchSettings.json` | `.env` file (environment variables) |
| Constructor parameters | Module `variables` (inputs) |
| Return values | Module `outputs` |
| `dotnet build` | `terraform plan` (preview changes) |
| `dotnet publish` | `terraform apply` (deploy changes) |
| EF Migrations | Terraform state (tracks what exists) |

### Key Files Explained

```text
📁 modules/cloudflare-dns/
├── main.tf          # The "implementation" - like Program.cs
├── variables.tf     # Input parameters - like constructor args
├── outputs.tf       # Return values - like method return types
└── README.md        # Documentation

📁 live/production/dns/
└── terragrunt.hcl   # "Instantiates" the module with prod values
                     # Like: new CloudflareDns(apiToken: "xxx", vpsIp: "5.10.248.55")
```

### HCL Syntax Quick Reference

```hcl
# Variables (like C# properties/parameters)
variable "vps_ip" {
  description = "IP address of the VPS"    # XML doc comment
  type        = string                      # string, number, bool, list, map
  default     = "5.10.248.55"              # Optional default value
}

# Resources (like DbSet<T> - represents real infrastructure)
resource "cloudflare_record" "api" {
  zone_id = var.zone_id          # Reference variable with var.
  name    = "api"
  content = var.vps_ip
  type    = "A"
  proxied = true
}

# Outputs (like return values)
output "api_hostname" {
  value = cloudflare_record.api.hostname   # Reference resource attribute
}

# Locals (like private readonly fields)
locals {
  environment = "production"
  full_domain = "${var.subdomain}.${var.domain}"  # String interpolation
}

# For-each (like LINQ Select)
resource "cloudflare_record" "records" {
  for_each = toset(["www", "api", "argocd"])  # Like: foreach(var sub in subdomains)
  
  name    = each.value
  content = var.vps_ip
}
```

### Common Commands Cheat Sheet

```bash
# Initialize (like dotnet restore)
terragrunt init

# Preview changes (like dotnet build --dry-run)
terragrunt plan

# Apply changes (like dotnet publish + deploy)
terragrunt apply

# Destroy resources (remove infrastructure)
terragrunt destroy

# Format code (like dotnet format)
terraform fmt

# Validate syntax (like dotnet build)
terraform validate

# Apply all modules in a folder (like dotnet build at solution level)
terragrunt run-all apply
```

### Understanding State (Like EF Migrations)

Terraform keeps track of what it has created in a **state file** (`terraform.tfstate`):

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Your Code     │     │   State File    │     │  Real Cloud     │
│   (Desired)     │ ──► │   (Known)       │ ──► │  (Actual)       │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        └───────── terraform plan ─────────────────────┘
                   (calculates diff)
```

- **Plan**: Compares your code → state → reality, shows what will change
- **Apply**: Makes the changes and updates the state
- **State is precious**: Like your database, don't lose it!

---

## 🎯 What This Manages

### 1. Cloudflare DNS (`cloudflare-dns` module)

**Production:**
- **Root domain** (`@`) → VPS IP (proxied)
- **www** subdomain → VPS IP (proxied)
- **api** subdomain → VPS IP (proxied)
- **argocd** subdomain → VPS IP (proxied)
- **registry** subdomain → VPS IP (proxied) - Container Registry

**Development:**
- **dev** subdomain → VPS IP (proxied)
- **dev-api** subdomain → VPS IP (proxied)
- **dev-argocd** subdomain → VPS IP (proxied)
- **dev-registry** subdomain → VPS IP (proxied)

### 2. GitHub Configuration (`github-config` module)

- Repository configuration for all 3 repos
- **Environments**: `dev`, `production` in Backend/Frontend repos
- **Deployment Secrets**:
  - `VPS_IP`, `SSH_USER`, `SSH_KEY` - SSH deployment
  - `REGISTRY_USER`, `REGISTRY_PASSWORD` - Container registry auth



## 🚀 Prerequisites

### Required Tools

```bash
# Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Install Terragrunt
wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.69.10/terragrunt_linux_amd64
chmod +x terragrunt_linux_amd64
sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

# Install CLI tools for credential management
gh auth login              # GitHub CLI (for GITHUB_TOKEN)
sudo npm install -g wrangler  # Cloudflare CLI (optional)
```

### Quick Setup with Script

Use the provided setup script to configure environment variables:

```bash
# Interactive setup (prompts for credentials)
source scripts/setup-env.sh

# Or manually create .env file
cp infrastructure/.env.example infrastructure/.env
# Edit infrastructure/.env with your values
source infrastructure/.env
```

### Required Environment Variables

| Variable | Source | Description |
|----------|--------|-------------|
| `CLOUDFLARE_API_TOKEN` | [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens) | Create with "Edit zone DNS" template |
| `CLOUDFLARE_ZONE_ID` | Cloudflare Dashboard → academind.ir → Overview | Right sidebar |
| `GITHUB_TOKEN` | `gh auth token` | Auto-filled if using gh CLI |
| `REGISTRY_USER` | Your choice | Container registry username |
| `REGISTRY_PASSWORD` | Your choice | Container registry password |
| `SSH_PRIVATE_KEY` | `cat ~/.ssh/id_rsa \| base64 -w 0` | Base64 encoded SSH key |

### Getting Cloudflare Credentials

```bash
# Option 1: Use Cloudflare Dashboard
# 1. Go to: https://dash.cloudflare.com/profile/api-tokens
# 2. Create Token → "Edit zone DNS" template
# 3. Zone Resources: Include → Specific zone → academind.ir
# 4. Copy the token

# Option 2: Use Wrangler CLI (interactive)
wrangler login
wrangler whoami
```

### Getting GitHub Token

```bash
# If gh CLI is installed and authenticated:
export GITHUB_TOKEN=$(gh auth token)

# Or create a Personal Access Token:
# https://github.com/settings/tokens
# Scopes needed: repo, admin:repo_hook
```


## 📋 Usage

### Initialize and Plan

```bash
# ============================================
# PRODUCTION ENVIRONMENT
# ============================================
cd infrastructure/live/production

# Apply all production modules at once
terragrunt run-all init
terragrunt run-all plan
terragrunt run-all apply

# Or apply individually
cd dns && terragrunt apply
cd ../github && terragrunt apply

# ============================================
# DEVELOPMENT ENVIRONMENT
# ============================================
cd infrastructure/live/development

# Apply all development modules at once
terragrunt run-all init
terragrunt run-all plan
terragrunt run-all apply

# Or apply individually
cd dns && terragrunt apply
cd ../github && terragrunt apply
```


### Apply Changes

```bash
# Apply all production infrastructure
cd infrastructure/live/production
terragrunt run-all apply

# Or apply individually
cd dns && terragrunt apply
cd ../github && terragrunt apply
```

### Import Existing Resources

If resources already exist, import them first:

```bash
# Import existing DNS records
cd infrastructure/live/production/dns
terragrunt import 'cloudflare_record.records["root"]' <zone_id>/<record_id>

# Import existing GitHub repos
cd infrastructure/live/production/github
terragrunt import 'github_repository.repos["Fundamental.Backend"]' Fundamental.Backend
```

## 🔐 Security Notes

1. **Never commit tokens/secrets** - Use environment variables
2. **API Token Scopes**:
   - Cloudflare: Zone:DNS:Edit (scoped to academind.ir zone)
   - GitHub: `repo`, `admin:org`, `admin:repo_hook`
3. **SSH Key**: Base64 encode when storing in GitHub Secrets
4. **State File**: Contains sensitive data - use remote backend with encryption

## 🔄 State Management

Terragrunt is configured to use local state by default. For team environments, configure remote state in the root `terragrunt.hcl`:

```hcl
# Example: S3 backend (uncomment and configure)
# remote_state {
#   backend = "s3"
#   config = {
#     bucket         = "fundamental-terraform-state"
#     key            = "${path_relative_to_include()}/terraform.tfstate"
#     region         = "eu-central-1"
#     encrypt        = true
#     dynamodb_table = "terraform-locks"
#   }
# }
```

## 📚 Module Documentation

### cloudflare-dns

| Input | Type | Description |
|-------|------|-------------|
| `api_token` | string | Cloudflare API token |
| `zone_id` | string | Cloudflare Zone ID |
| `domain_name` | string | Domain name (e.g., academind.ir) |
| `vps_ip` | string | VPS IP address |
| `subdomains` | list(string) | Subdomains to create A records for |
| `proxied` | bool | Enable Cloudflare proxy (orange cloud) |

### github-config

| Input | Type | Description |
|-------|------|-------------|
| `github_owner` | string | GitHub organization/user |
| `vps_ip` | string | VPS IP for deployment secrets |
| `ssh_user` | string | SSH user for deployment |
| `ssh_private_key` | string | SSH private key (base64 encoded) |
| `repositories` | map(object) | Repository configurations |

---

## 🔧 Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| `Error: No valid credential sources found` | Set `CLOUDFLARE_API_TOKEN` or `GITHUB_TOKEN` env var |
| `Error: Resource already exists` | Import it first: `terragrunt import <resource> <id>` |
| `Error: state lock` | Someone else is applying, or crashed. Use `terragrunt force-unlock <id>` |
| `Changes detected but shouldn't be` | Run `terragrunt refresh` to sync state with reality |
| `Module not found` | Run `terragrunt init` to download modules/providers |

### Debugging Commands

```bash
# See what Terraform thinks exists (state)
terragrunt state list

# Show details of a specific resource
terragrunt state show 'cloudflare_record.records["api"]'

# See the raw plan in JSON
terragrunt plan -out=plan.tfplan
terragrunt show -json plan.tfplan

# Enable verbose logging
export TF_LOG=DEBUG
terragrunt apply
```

### Starting Fresh (Nuclear Option)

```bash
# Remove all cached files and state (DANGEROUS - will recreate everything)
rm -rf .terragrunt-cache/
rm -f terraform.tfstate*

# Re-initialize
terragrunt init
```

---

## 📖 Learning Resources

### For .NET Developers

1. **Terraform Basics** (Start Here)
   - [HashiCorp Learn - Terraform](https://learn.hashicorp.com/terraform)
   - Think of it as "Infrastructure Entity Framework"

2. **Terragrunt** (DRY Terraform)
   - [Terragrunt Quick Start](https://terragrunt.gruntwork.io/docs/getting-started/quick-start/)
   - Like using `Directory.Build.props` for shared settings

3. **Cloudflare Provider**
   - [Terraform Cloudflare Provider Docs](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)

4. **GitHub Provider**
   - [Terraform GitHub Provider Docs](https://registry.terraform.io/providers/integrations/github/latest/docs)

### Recommended Learning Path

```
Week 1: Terraform Basics
├── Variables, Resources, Outputs
├── terraform init/plan/apply
└── State management

Week 2: Providers
├── Cloudflare provider
├── GitHub provider
└── Authentication patterns

Week 3: Terragrunt
├── DRY configuration
├── Dependencies between modules
└── Remote state management

Week 4: Advanced
├── Modules design
├── Testing infrastructure
└── CI/CD for infrastructure
```

### VS Code Extensions

- **HashiCorp Terraform** - Syntax highlighting, IntelliSense
- **Terragrunt** - Terragrunt file support
- **Even Better TOML** - For HCL formatting
