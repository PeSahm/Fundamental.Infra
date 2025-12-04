# =============================================================================
# Production Environment - Common Configuration
# =============================================================================
# This file contains production-specific settings that are inherited by
# all modules in the production environment.
# =============================================================================

locals {
  environment = "production"
  
  # Production-specific overrides (if needed)
  # These can override root-level settings
}

# Include the root terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

# Production-specific inputs (merged with root inputs)
inputs = {
  environment = local.environment
}
