# =============================================================================
# Development DNS Configuration (Cloudflare) - academind.ir
# =============================================================================
# This module creates DNS A records for the development environment:
# - dev subdomain -> VPS IP (for dev frontend)
# - api subdomain -> VPS IP (for dev backend API)
# - argocd subdomain -> VPS IP (shared ArgoCD)
# - registry subdomain -> VPS IP (shared Container Registry)
# - k8s subdomain -> VPS IP (Kubernetes Dashboard)
# - sentry subdomain -> VPS IP (error tracking)
#
# Proxy is DISABLED because Cloudflare proxy cannot reliably reach
# Iran-based VPS servers (timeouts, redirect loops with SSL modes).
# TLS is handled directly by the ingress controller with Let's Encrypt.
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
  # sentry is for centralized error tracking (shared)
  # api is a dedicated backend API endpoint (separate from dev.academind.ir/api)
  subdomains = ["dev", "api", "argocd", "registry", "k8s", "sentry"]

  # Disable Cloudflare proxy - direct DNS only
  # Reason: Cloudflare proxy cannot reliably connect to Iran-based VPS
  # (causes timeouts and SSL redirect loops). TLS is handled by
  # the ingress controller with Let's Encrypt certificates.
  proxied = false
}
