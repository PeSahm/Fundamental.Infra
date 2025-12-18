# =============================================================================
# Production DNS Configuration (Cloudflare) - sahmbaz.ir
# =============================================================================
# This module creates DNS A records for the production environment:
# - Root domain (@) -> VPS IP
# - www subdomain -> VPS IP
# - api subdomain -> VPS IP (backend API)
# All records are proxied through Cloudflare for DDoS protection.
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
  source = "../../../modules/cloudflare-dns"
}

# -----------------------------------------------------------------------------
# Dependencies (if any)
# -----------------------------------------------------------------------------
# No dependencies for DNS module

# -----------------------------------------------------------------------------
# Module Inputs
# -----------------------------------------------------------------------------
# Production uses sahmbaz.ir domain

inputs = {
  # Cloudflare API Token for sahmbaz.ir - Read from environment variable
  # Set via: export CLOUDFLARE_API_TOKEN_PROD="your-token"
  api_token = get_env("CLOUDFLARE_API_TOKEN_PROD", "")
  
  # Cloudflare Zone ID for sahmbaz.ir
  # Set via: export CLOUDFLARE_ZONE_ID_PROD="your-zone-id"
  zone_id = get_env("CLOUDFLARE_ZONE_ID_PROD", "")
  
  # Production domain configuration
  domain_name = "sahmbaz.ir"
  
  # Production subdomains
  subdomains = ["www", "api"]
  
  # Enable Cloudflare proxy (orange cloud) for DDoS protection
  proxied = true
}
