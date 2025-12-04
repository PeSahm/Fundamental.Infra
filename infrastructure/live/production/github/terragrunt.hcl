# =============================================================================
# Production GitHub Configuration
# =============================================================================
# This module configures GitHub repositories for the Fundamental application:
# - Repository settings for Backend, Frontend, and Infra repos
# - Deployment environments (dev, production)
# - Actions secrets for CI/CD:
#   - VPS_IP, SSH_USER, SSH_KEY (deployment)
#   - REGISTRY_USER, REGISTRY_PASSWORD (container registry)
# =============================================================================

# -----------------------------------------------------------------------------
# Include Root Configuration
# -----------------------------------------------------------------------------
include "root" {
  path = find_in_parent_folders()
}

# -----------------------------------------------------------------------------
# Terraform Source
# -----------------------------------------------------------------------------
terraform {
  source = "../../../modules/github-config"
}

# -----------------------------------------------------------------------------
# Dependencies
# -----------------------------------------------------------------------------
# DNS should be configured before GitHub (for domain variables)
dependency "dns" {
  config_path = "../dns"
  
  # Skip validation during init/plan when DNS hasn't been applied yet
  skip_outputs = true
  
  mock_outputs = {
    all_hostnames = ["academind.ir", "www.academind.ir", "api.academind.ir", "argocd.academind.ir"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# -----------------------------------------------------------------------------
# Module Inputs
# -----------------------------------------------------------------------------
inputs = {
  # GitHub Token from environment variable
  # This token is used to configure repositories, environments, and secrets
  github_token = get_env("GITHUB_TOKEN", "")
  
  # GitHub owner (inherited from root)
  # github_owner = "PeSahm"
  
  # SSH Private Key for deployment
  # IMPORTANT: Set via environment variable (base64 encoded recommended)
  # export SSH_PRIVATE_KEY=$(cat ~/.ssh/deploy_key | base64 -w 0)
  # OR: export SSH_PRIVATE_KEY=$(cat ~/.ssh/deploy_key)
  ssh_private_key = get_env("SSH_PRIVATE_KEY", "")
  
  # Container Registry Credentials
  # Used by CI pipelines to push images to registry.academind.ir
  registry_user     = get_env("REGISTRY_USER", "")
  registry_password = get_env("REGISTRY_PASSWORD", "")
  
  # VPS configuration (inherited from root)
  # vps_ip = "5.10.248.55"
  # ssh_user = "deploy"
  
  # Repository configuration
  repositories = {
    "Fundamental.Backend" = {
      description     = "ASP.NET Core backend API for Fundamental application"
      visibility      = "public"
      has_deployments = true
      topics          = ["dotnet", "aspnetcore", "api", "backend", "csharp"]
    }
    "Fundamental.FrontEnd" = {
      description     = "Angular frontend for Fundamental application"
      visibility      = "public"
      has_deployments = true
      topics          = ["angular", "typescript", "frontend", "web"]
    }
    "Fundamental.Infra" = {
      description     = "Infrastructure as Code - Ansible, Helm, ArgoCD, Terraform"
      visibility      = "public"
      has_deployments = false
      topics          = ["infrastructure", "gitops", "kubernetes", "terraform", "ansible", "argocd"]
    }
  }
  
  # Optional: Require approval for production deployments
  require_production_approval = false
  # production_reviewers = []  # Add GitHub user IDs if enabling approval
}
