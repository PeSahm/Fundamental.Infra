# =============================================================================
# Development DNS Configuration (Cloudflare) - academind.ir
# =============================================================================
# This module creates DNS A records for the development environment:
# - dev subdomain -> VPS IP (for dev frontend)
# - dev-api subdomain -> VPS IP (for dev backend API)
# - argocd subdomain -> VPS IP (shared ArgoCD)
# - registry subdomain -> VPS IP (shared Container Registry)
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
# Development uses academind.ir domain with dev subdomains

inputs = {
  # Cloudflare API Token for academind.ir - Read from environment variable
  # Set via: export CLOUDFLARE_API_TOKEN_DEV="your-token"
  api_token = get_env("CLOUDFLARE_API_TOKEN_DEV", "")
  
  # Cloudflare Zone ID for academind.ir
  # Set via: export CLOUDFLARE_ZONE_ID_DEV="your-zone-id"
  zone_id = get_env("CLOUDFLARE_ZONE_ID_DEV", "")
  
  # Development domain configuration
  domain_name = "academind.ir"
  
  # Development subdomains (different from production)
  # registry and argocd are shared between dev/prod
  # k8s is for Kubernetes Dashboard
  subdomains = ["dev", "dev-api", "argocd", "registry", "k8s"]
  
  # Enable Cloudflare proxy (orange cloud) for DDoS protection
  proxied = true
  
  # Registry must NOT be proxied - Docker registry doesn't work through Cloudflare proxy
  # Cloudflare intercepts HTTPS and breaks Docker's authentication flow
  # k8s dashboard must NOT be proxied - Kubernetes Dashboard uses websockets
  non_proxied_subdomains = ["registry", "k8s"]
}
