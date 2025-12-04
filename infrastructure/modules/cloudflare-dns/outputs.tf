# =============================================================================
# Cloudflare DNS Module - Outputs
# =============================================================================

output "dns_records" {
  description = "Map of created DNS records with their details"
  value = {
    for key, record in cloudflare_record.records : key => {
      id       = record.id
      hostname = record.hostname
      name     = record.name
      content  = record.content
      type     = record.type
      proxied  = record.proxied
      ttl      = record.ttl
    }
  }
}

output "root_record_id" {
  description = "The ID of the root domain A record"
  value       = cloudflare_record.records["root"].id
}

output "root_hostname" {
  description = "The full hostname for the root domain"
  value       = cloudflare_record.records["root"].hostname
}

output "subdomain_hostnames" {
  description = "Map of subdomain names to their full hostnames"
  value = {
    for key, record in cloudflare_record.records :
    key => record.hostname if key != "root"
  }
}

output "all_hostnames" {
  description = "List of all hostnames created"
  value       = [for record in cloudflare_record.records : record.hostname]
}
