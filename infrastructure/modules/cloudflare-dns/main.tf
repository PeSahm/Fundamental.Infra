# =============================================================================
# Cloudflare DNS Module
# =============================================================================
# This module manages DNS records for the Fundamental application stack.
# It creates A records for the root domain and specified subdomains,
# all pointing to the VPS IP with Cloudflare proxy enabled for DDoS protection.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "cloudflare" {
  api_token = var.api_token
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------
locals {
  # Combine root domain with subdomains for unified record creation
  all_records = merge(
    # Root domain record
    {
      "root" = {
        name    = "@"
        content = var.vps_ip
        proxied = var.proxied
        ttl     = var.proxied ? 1 : var.ttl # Auto TTL when proxied
      }
    },
    # Subdomain records (proxied)
    {
      for subdomain in var.subdomains : subdomain => {
        name    = subdomain
        content = var.vps_ip
        proxied = contains(var.non_proxied_subdomains, subdomain) ? false : var.proxied
        ttl     = contains(var.non_proxied_subdomains, subdomain) ? var.ttl : (var.proxied ? 1 : var.ttl)
      }
    }
  )
}

# -----------------------------------------------------------------------------
# DNS A Records
# -----------------------------------------------------------------------------
resource "cloudflare_record" "records" {
  for_each = local.all_records

  zone_id = var.zone_id
  name    = each.value.name
  content = each.value.content
  type    = "A"
  proxied = each.value.proxied
  ttl     = each.value.ttl

  # Allow Terraform to update existing records
  allow_overwrite = true

  comment = "Managed by Terraform - Fundamental Infrastructure"
}
