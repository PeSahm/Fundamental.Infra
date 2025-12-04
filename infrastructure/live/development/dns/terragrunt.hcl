# =============================================================================
# Development DNS Configuration (Cloudflare)
# =============================================================================
# This module creates DNS A records for the development environment:
# - dev subdomain -> VPS IP (for dev frontend)
# - dev-api subdomain -> VPS IP (for dev backend API)
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
# Module Inputs
# -----------------------------------------------------------------------------
# Development uses different subdomains to separate from production

inputs = {
  # Cloudflare API Token - Read from environment variable
  # Set via: export CLOUDFLARE_API_TOKEN="your-token"
  api_token = get_env("CLOUDFLARE_API_TOKEN", "")
  
  # Cloudflare Zone ID for academind.ir
  # Set via: export CLOUDFLARE_ZONE_ID="your-zone-id"
  zone_id = get_env("CLOUDFLARE_ZONE_ID", "")
  
  # Development subdomains (different from production)
  subdomains = ["dev", "dev-api", "dev-argocd", "dev-registry"]
  
  # Enable Cloudflare proxy (orange cloud) for DDoS protection
  proxied = true
}
