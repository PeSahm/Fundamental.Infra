# =============================================================================
# Root Terragrunt Configuration
# =============================================================================
# AUTO-GENERATED from config.yaml - DO NOT EDIT MANUALLY
# Run: ./scripts/generate-config.sh to regenerate
# =============================================================================

locals {
  # ==========================================================================
  # INFRASTRUCTURE CONFIGURATION (from config.yaml)
  # ==========================================================================
  
  # VPS Server Configuration
  vps_ip   = "5.10.248.55"
  ssh_user = "deploy"
  
  # Domain Configuration
  domain_name = "academind.ir"
  
  # GitHub Configuration
  github_owner = "PeSahm"
  
  # Subdomains to create DNS records for
  subdomains = ["www", "api", "dev", "argocd", "registry"]
  
  # Container Registry Configuration
  container_registry = "registry.academind.ir"
  
  # ==========================================================================
  # ENVIRONMENT CONFIGURATION
  # ==========================================================================
  environment = "production"
  
  # ==========================================================================
  # COMMON TAGS
  # ==========================================================================
  common_tags = {
    Project     = "Fundamental"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
    Repository  = "Fundamental.Infra"
  }
}

# -----------------------------------------------------------------------------
# Remote State Configuration
# -----------------------------------------------------------------------------
remote_state {
  backend = "local"
  
  config = {
    path = "${get_parent_terragrunt_dir()}/.terragrunt-cache/${path_relative_to_include()}/terraform.tfstate"
  }
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# -----------------------------------------------------------------------------
# Generate Provider Versions
# -----------------------------------------------------------------------------
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  
  contents = <<VERSIONS
terraform {
  required_version = ">= 1.5.0"
}
VERSIONS
}

# -----------------------------------------------------------------------------
# Global Inputs (Passed to all child modules)
# -----------------------------------------------------------------------------
inputs = {
  # VPS Configuration
  vps_ip   = local.vps_ip
  ssh_user = local.ssh_user
  
  # Domain Configuration
  domain_name = local.domain_name
  subdomains  = local.subdomains
  
  # GitHub Configuration
  github_owner = local.github_owner
  
  # Environment
  environment = local.environment
  
  # Tags
  common_tags = local.common_tags
}
