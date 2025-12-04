# GitHub Configuration Module

This Terraform module manages GitHub repository configuration for the Fundamental application stack.

## Features

- References existing repositories (or creates new ones)
- Creates deployment environments (dev, production)
- Configures Actions secrets for CI/CD deployments
- Supports environment-specific secrets
- Optional production deployment protection

## Usage

```hcl
module "github" {
  source = "../../modules/github-config"

  github_owner    = "PeSahm"
  vps_ip          = "5.10.248.55"
  ssh_user        = "deploy"
  ssh_private_key = var.ssh_private_key

  repositories = {
    "Fundamental.Backend" = {
      description     = "Backend API (.NET)"
      has_deployments = true
    }
    "Fundamental.FrontEnd" = {
      description     = "Frontend (Angular)"
      has_deployments = true
    }
    "Fundamental.Infra" = {
      description     = "Infrastructure as Code"
      has_deployments = false
    }
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| github | ~> 6.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| github_owner | GitHub organization or username | `string` | n/a | yes |
| vps_ip | IP address of the VPS server | `string` | n/a | yes |
| ssh_user | SSH username for deployment | `string` | `"deploy"` | no |
| ssh_private_key | SSH private key for deployment | `string` | n/a | yes |
| repositories | Map of repository configurations | `map(object)` | See variables.tf | no |
| require_production_approval | Require approval for prod deployments | `bool` | `false` | no |
| production_reviewers | GitHub user IDs for production reviewers | `list(number)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| repositories | Map of repository information |
| environments | Map of created environments |
| deployable_repos | List of repos configured for deployments |
| secrets_configured | List of secrets configured per repo |

## GitHub Token

Create a Personal Access Token (PAT) with the following permissions:

### Fine-grained Token (Recommended)

1. Go to GitHub → Settings → Developer Settings → Personal Access Tokens → Fine-grained tokens
2. Select repositories: `Fundamental.Backend`, `Fundamental.FrontEnd`, `Fundamental.Infra`
3. Permissions:
   - **Repository permissions**:
     - Actions: Read and write
     - Environments: Read and write
     - Metadata: Read-only
     - Secrets: Read and write
   - **Organization permissions** (if using org):
     - Members: Read-only

### Classic Token (Alternative)

Scopes needed:
- `repo` (Full control of private repositories)
- `admin:repo_hook` (Admin webhooks)

## Importing Existing Repositories

If repositories already exist (they do in this case):

```bash
# The module uses data sources, so no import needed for repos
# Environments might need to be imported if they exist:
terraform import 'github_repository_environment.environments["Fundamental.Backend-production"]' Fundamental.Backend/production
terraform import 'github_repository_environment.environments["Fundamental.Backend-dev"]' Fundamental.Backend/dev
```

## Security Notes

1. **SSH Private Key**: Store securely, never commit
2. **GitHub Token**: Use fine-grained tokens with minimal permissions
3. **Secrets**: Terraform state contains secrets - secure your state file
4. **Environment Protection**: Enable `require_production_approval` for safety
