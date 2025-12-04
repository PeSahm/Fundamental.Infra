# =============================================================================
# Development GitHub Configuration
# =============================================================================
# This module configures GitHub repository settings for development:
# - Focuses on the 'dev' environment configuration
# - Sets up development-specific secrets if needed
# 
# Note: Repository creation is handled in production config.
# This config can add dev-specific environment secrets if needed.
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
# DNS should be configured before GitHub
dependency "dns" {
  config_path = "../dns"
  
  skip_outputs = true
  
  mock_outputs = {
    all_hostnames = ["dev.academind.ir", "dev-api.academind.ir", "dev-argocd.academind.ir"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# -----------------------------------------------------------------------------
# Module Inputs
# -----------------------------------------------------------------------------
inputs = {
  # GitHub Token from environment
  github_token = get_env("GITHUB_TOKEN", "")
  
  # SSH Private Key for deployment
  ssh_private_key = get_env("SSH_PRIVATE_KEY", "")
  
  # Container Registry Credentials
  registry_user     = get_env("REGISTRY_USER", "")
  registry_password = get_env("REGISTRY_PASSWORD", "")
  
  # Repository configuration - same repos but focuses on dev environment
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
  
  # Development doesn't require approval
  require_production_approval = false
}
