# =============================================================================
# Development Environment - Common Configuration
# =============================================================================
# This file contains development-specific settings that are inherited by
# all modules in the development environment.
# =============================================================================

locals {
  environment = "dev"
  
  # Development-specific overrides
  # Uses different subdomains to separate from production
}

# Include the root terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

# Development-specific inputs (merged with root inputs)
inputs = {
  environment = local.environment
}
