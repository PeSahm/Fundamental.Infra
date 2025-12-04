# Cloudflare DNS Module

This Terraform module manages DNS A records in Cloudflare for the Fundamental application stack.

## Features

- Creates A record for root domain (`@`)
- Creates A records for specified subdomains
- Enables Cloudflare proxy (orange cloud) for DDoS protection
- Supports importing existing records

## Usage

```hcl
module "dns" {
  source = "../../modules/cloudflare-dns"

  api_token   = var.cloudflare_api_token
  zone_id     = var.cloudflare_zone_id
  domain_name = "academind.ir"
  vps_ip      = "5.10.248.55"

  subdomains = ["www", "api", "argocd"]
  proxied    = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| cloudflare | ~> 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| api_token | Cloudflare API token with Zone:DNS:Edit permissions | `string` | n/a | yes |
| zone_id | Cloudflare Zone ID for the domain | `string` | n/a | yes |
| domain_name | The domain name (e.g., academind.ir) | `string` | n/a | yes |
| vps_ip | IP address of the VPS server | `string` | n/a | yes |
| subdomains | List of subdomains to create A records for | `list(string)` | `["www", "api", "argocd"]` | no |
| proxied | Enable Cloudflare proxy (orange cloud) | `bool` | `true` | no |
| ttl | TTL for DNS records (when not proxied) | `number` | `300` | no |

## Outputs

| Name | Description |
|------|-------------|
| dns_records | Map of created DNS records with their details |
| root_record_id | The ID of the root domain A record |
| root_hostname | The full hostname for the root domain |
| subdomain_hostnames | Map of subdomain names to their full hostnames |
| all_hostnames | List of all hostnames created |

## Cloudflare API Token

Create an API token with the following permissions:

1. Go to Cloudflare Dashboard → Profile → API Tokens
2. Create Token → Custom Token
3. Permissions:
   - **Zone** → **DNS** → **Edit**
4. Zone Resources:
   - **Include** → **Specific zone** → **academind.ir**

## Importing Existing Records

If DNS records already exist, import them before applying:

```bash
# Get record IDs from Cloudflare API
curl -X GET "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records" \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json"

# Import each record
terraform import 'cloudflare_record.records["root"]' {zone_id}/{record_id}
terraform import 'cloudflare_record.records["www"]' {zone_id}/{record_id}
terraform import 'cloudflare_record.records["api"]' {zone_id}/{record_id}
terraform import 'cloudflare_record.records["argocd"]' {zone_id}/{record_id}
```
