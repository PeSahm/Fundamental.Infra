# =============================================================================
# Root Terragrunt Configuration
# =============================================================================
# This is the root terragrunt.hcl file that contains:
# - Remote state configuration (local by default)
# - Global inputs that are passed down to all child modules
# - Common terraform settings
# =============================================================================

# -----------------------------------------------------------------------------
# Global Variables (DRY - Define Once, Use Everywhere)
# -----------------------------------------------------------------------------
# These values are defined here and passed to all child modules

locals {
  # ==========================================================================
  # INFRASTRUCTURE CONFIGURATION
  # ==========================================================================
  
  # VPS Server Configuration
  vps_ip   = "5.10.248.55"
  ssh_user = "deploy"
  
  # Domain Configuration
  domain_name = "academind.ir"
  
  # GitHub Configuration
  github_owner = "PeSahm"
  
  # Subdomains to create DNS records for
  subdomains = ["www", "api", "argocd", "registry"]
  
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
# Using local backend by default. For team environments, configure S3/GCS.

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
# Alternative: S3 Remote State (Uncomment for team environments)
# -----------------------------------------------------------------------------
# remote_state {
#   backend = "s3"
#   
#   config = {
#     bucket         = "fundamental-terraform-state"
#     key            = "${path_relative_to_include()}/terraform.tfstate"
#     region         = "eu-central-1"
#     encrypt        = true
#     dynamodb_table = "terraform-locks"
#   }
#   
#   generate = {
#     path      = "backend.tf"
#     if_exists = "overwrite_terragrunt"
#   }
# }

# -----------------------------------------------------------------------------
# Generate Provider Versions
# -----------------------------------------------------------------------------
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  
  contents = <<EOF
terraform {
  required_version = ">= 1.5.0"
}
EOF
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
