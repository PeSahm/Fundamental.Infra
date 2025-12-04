# =============================================================================
# Production DNS Configuration (Cloudflare)
# =============================================================================
# This module creates DNS A records for the Fundamental application:
# - Root domain (@) -> VPS IP
# - www subdomain -> VPS IP
# - api subdomain -> VPS IP  
# - argocd subdomain -> VPS IP
# - registry subdomain -> VPS IP (Container Registry)
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
# These are merged with the inputs from the root terragrunt.hcl

inputs = {
  # Cloudflare API Token - Read from environment variable
  # Set via: export CLOUDFLARE_API_TOKEN="your-token"
  api_token = get_env("CLOUDFLARE_API_TOKEN", "")
  
  # Cloudflare Zone ID for academind.ir
  # Set via: export CLOUDFLARE_ZONE_ID="your-zone-id"
  zone_id = get_env("CLOUDFLARE_ZONE_ID", "")
  
  # Domain configuration (inherited from root, can override here)
  # domain_name = "academind.ir"  # Already set in root
  # vps_ip = "5.10.248.55"        # Already set in root
  
  # Subdomains to create (can override root setting)
  # subdomains = ["www", "api", "argocd"]
  
  # Enable Cloudflare proxy (orange cloud) for DDoS protection
  proxied = true
}
