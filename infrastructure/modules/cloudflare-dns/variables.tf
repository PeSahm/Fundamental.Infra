# =============================================================================
# Cloudflare DNS Module - Variables
# =============================================================================

variable "api_token" {
  description = "Cloudflare API token with Zone:DNS:Edit permissions"
  type        = string
  sensitive   = true
}

variable "zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
}

variable "domain_name" {
  description = "The domain name (e.g., academind.ir)"
  type        = string
}

variable "vps_ip" {
  description = "IP address of the VPS server"
  type        = string

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.vps_ip))
    error_message = "The vps_ip must be a valid IPv4 address."
  }
}

variable "subdomains" {
  description = "List of subdomains to create A records for"
  type        = list(string)
  default     = ["www", "api", "argocd"]
}

variable "proxied" {
  description = "Whether to enable Cloudflare proxy (orange cloud) for DDoS protection"
  type        = bool
  default     = true
}

variable "ttl" {
  description = "TTL for DNS records (only used when proxied = false)"
  type        = number
  default     = 300

  validation {
    condition     = var.ttl >= 60 && var.ttl <= 86400
    error_message = "TTL must be between 60 and 86400 seconds."
  }
}
