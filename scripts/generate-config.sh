#!/usr/bin/env bash
# =============================================================================
# Configuration Generator Script
# =============================================================================
# This script reads config.yaml and generates configuration files for:
#   - Terragrunt (infrastructure/live/)
#   - Ansible (ansible/group_vars/)
#   - Helm values (charts/fundamental-stack/)
#
# Usage:
#   ./scripts/generate-config.sh
#
# Requirements:
#   - yq (YAML processor)
#   - bash 4.0+
# =============================================================================

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Config file
CONFIG_FILE="${ROOT_DIR}/config.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log_info "Checking requirements..."
    
    if ! command -v yq &> /dev/null; then
        log_error "yq is not installed. Install with: sudo snap install yq"
        exit 1
    fi
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_error "Config file not found: ${CONFIG_FILE}"
        exit 1
    fi
    
    log_success "All requirements met"
}

# Read value from config.yaml
cfg() {
    yq eval "$1" "${CONFIG_FILE}"
}

# -----------------------------------------------------------------------------
# Generate Terragrunt Configuration
# -----------------------------------------------------------------------------

generate_terragrunt() {
    log_info "Generating Terragrunt configuration..."
    
    local domain_base=$(cfg '.domain.base')
    local vps_ip=$(cfg '.vps.ip')
    local ssh_user=$(cfg '.vps.deploy_user')
    local github_owner=$(cfg '.github.owner')
    local registry_subdomain=$(cfg '.domain.subdomains.prod.registry')
    
    cat > "${ROOT_DIR}/infrastructure/live/terragrunt.hcl" << EOF
# =============================================================================
# Root Terragrunt Configuration
# =============================================================================
# AUTO-GENERATED from config.yaml - DO NOT EDIT MANUALLY
# Run: ./scripts/generate-config.sh to regenerate
# =============================================================================

locals {
  # ==========================================================================
  # INFRASTRUCTURE CONFIGURATION (from config.yaml)
  # ==========================================================================
  
  # VPS Server Configuration
  vps_ip   = "${vps_ip}"
  ssh_user = "${ssh_user}"
  
  # Domain Configuration
  domain_name = "${domain_base}"
  
  # GitHub Configuration
  github_owner = "${github_owner}"
  
  # Subdomains to create DNS records for
  subdomains = ["www", "api", "dev", "argocd", "registry"]
  
  # Container Registry Configuration
  container_registry = "${registry_subdomain}.${domain_base}"
  
  # ==========================================================================
  # ENVIRONMENT CONFIGURATION
  # ==========================================================================
  environment = "production"
  
  # ==========================================================================
  # COMMON TAGS
  # ==========================================================================
  common_tags = {
    Project     = "Fundamental"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
    Repository  = "Fundamental.Infra"
  }
}

# -----------------------------------------------------------------------------
# Remote State Configuration
# -----------------------------------------------------------------------------
remote_state {
  backend = "local"
  
  config = {
    path = "\${get_parent_terragrunt_dir()}/.terragrunt-cache/\${path_relative_to_include()}/terraform.tfstate"
  }
  
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# -----------------------------------------------------------------------------
# Generate Provider Versions
# -----------------------------------------------------------------------------
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  
  contents = <<VERSIONS
terraform {
  required_version = ">= 1.5.0"
}
VERSIONS
}

# -----------------------------------------------------------------------------
# Global Inputs (Passed to all child modules)
# -----------------------------------------------------------------------------
inputs = {
  # VPS Configuration
  vps_ip   = local.vps_ip
  ssh_user = local.ssh_user
  
  # Domain Configuration
  domain_name = local.domain_name
  subdomains  = local.subdomains
  
  # GitHub Configuration
  github_owner = local.github_owner
  
  # Environment
  environment = local.environment
  
  # Tags
  common_tags = local.common_tags
}
EOF

    log_success "Generated: infrastructure/live/terragrunt.hcl"
}

# -----------------------------------------------------------------------------
# Generate Ansible Variables
# -----------------------------------------------------------------------------

generate_ansible_vars() {
    log_info "Generating Ansible variables..."
    
    local domain_base=$(cfg '.domain.base')
    local vps_ip=$(cfg '.vps.ip')
    local registry_subdomain=$(cfg '.domain.subdomains.prod.registry')
    local argocd_subdomain=$(cfg '.domain.subdomains.prod.argocd')
    local registry_username=$(cfg '.registry.username')
    local github_owner=$(cfg '.github.owner')
    local ingress_class=$(cfg '.kubernetes.ingress_class')
    local cluster_issuer=$(cfg '.kubernetes.cluster_issuer')
    
    # Create group_vars directory if not exists
    mkdir -p "${ROOT_DIR}/ansible/group_vars"
    
    cat > "${ROOT_DIR}/ansible/group_vars/all.yaml" << EOF
# =============================================================================
# Ansible Global Variables
# =============================================================================
# AUTO-GENERATED from config.yaml - DO NOT EDIT MANUALLY
# Run: ./scripts/generate-config.sh to regenerate
# =============================================================================

# -----------------------------------------------------------------------------
# Domain Configuration
# -----------------------------------------------------------------------------
domain_base: "${domain_base}"
registry_domain: "${registry_subdomain}.${domain_base}"
argocd_domain: "${argocd_subdomain}.${domain_base}"

# -----------------------------------------------------------------------------
# VPS Configuration
# -----------------------------------------------------------------------------
vps_ip: "${vps_ip}"

# -----------------------------------------------------------------------------
# Registry Configuration
# -----------------------------------------------------------------------------
registry_username: "${registry_username}"
registry_external_host: "${registry_subdomain}.${domain_base}"

# -----------------------------------------------------------------------------
# GitHub Configuration
# -----------------------------------------------------------------------------
github_owner: "${github_owner}"
registry_host: "${registry_subdomain}.${domain_base}"

# -----------------------------------------------------------------------------
# Kubernetes Configuration
# -----------------------------------------------------------------------------
ingress_class: "${ingress_class}"
cluster_issuer: "${cluster_issuer}"

# -----------------------------------------------------------------------------
# Credentials Directory
# -----------------------------------------------------------------------------
credentials_dir: "/root/.fundamental-credentials"
EOF

    log_success "Generated: ansible/group_vars/all.yaml"
}

# -----------------------------------------------------------------------------
# Generate Helm Values Files
# -----------------------------------------------------------------------------

generate_helm_values() {
    log_info "Generating Helm values files..."
    
    local domain_base=$(cfg '.domain.base')
    local registry_subdomain=$(cfg '.domain.subdomains.prod.registry')
    local dev_frontend=$(cfg '.domain.subdomains.dev.frontend')
    local ingress_class=$(cfg '.kubernetes.ingress_class')
    local cluster_issuer=$(cfg '.kubernetes.cluster_issuer')
    
    local registry="${registry_subdomain}.${domain_base}"
    local backend_image=$(cfg '.registry.images.backend')
    local frontend_image=$(cfg '.registry.images.frontend')
    local migrations_image=$(cfg '.registry.images.migrations')
    
    local postgres_image=$(cfg '.database.postgres.image')
    local redis_image=$(cfg '.database.redis.image')
    local postgres_username=$(cfg '.database.postgres.username')
    
    # Development values
    local dev_domain="${dev_frontend}.${domain_base}"
    local dev_db=$(cfg '.database.postgres.database_name.dev')
    local dev_aspnet=$(cfg '.application.aspnet_environment.dev')
    local dev_tag=$(cfg '.application.default_tag.dev')
    
    # Dev resources
    local dev_backend_cpu_limit=$(cfg '.resources.dev.backend.cpu_limit')
    local dev_backend_memory_limit=$(cfg '.resources.dev.backend.memory_limit')
    local dev_backend_cpu_request=$(cfg '.resources.dev.backend.cpu_request')
    local dev_backend_memory_request=$(cfg '.resources.dev.backend.memory_request')
    local dev_frontend_cpu_limit=$(cfg '.resources.dev.frontend.cpu_limit')
    local dev_frontend_memory_limit=$(cfg '.resources.dev.frontend.memory_limit')
    local dev_frontend_cpu_request=$(cfg '.resources.dev.frontend.cpu_request')
    local dev_frontend_memory_request=$(cfg '.resources.dev.frontend.memory_request')
    local dev_postgres_cpu_limit=$(cfg '.resources.dev.postgres.cpu_limit')
    local dev_postgres_memory_limit=$(cfg '.resources.dev.postgres.memory_limit')
    local dev_postgres_cpu_request=$(cfg '.resources.dev.postgres.cpu_request')
    local dev_postgres_memory_request=$(cfg '.resources.dev.postgres.memory_request')
    local dev_redis_cpu_limit=$(cfg '.resources.dev.redis.cpu_limit')
    local dev_redis_memory_limit=$(cfg '.resources.dev.redis.memory_limit')
    local dev_redis_cpu_request=$(cfg '.resources.dev.redis.cpu_request')
    local dev_redis_memory_request=$(cfg '.resources.dev.redis.memory_request')
    
    cat > "${ROOT_DIR}/charts/fundamental-stack/values-dev.yaml" << EOF
# =============================================================================
# Development Environment Values
# =============================================================================
# AUTO-GENERATED from config.yaml - DO NOT EDIT MANUALLY
# Run: ./scripts/generate-config.sh to regenerate
# =============================================================================

# Global settings
global:
  imagePullSecrets:
    - name: registry-credentials
  
  domain: "${dev_domain}"

# =============================================================================
# Backend (Development)
# =============================================================================
backend:
  replicaCount: 1
  
  image:
    repository: ${registry}/${backend_image}
    tag: "${dev_tag}"
  
  aspnetEnvironment: "${dev_aspnet}"
  
  resources:
    limits:
      cpu: ${dev_backend_cpu_limit}
      memory: ${dev_backend_memory_limit}
    requests:
      cpu: ${dev_backend_cpu_request}
      memory: ${dev_backend_memory_request}
  
  autoscaling:
    enabled: false
  
  podDisruptionBudget:
    enabled: false
  
  extraEnv:
    - name: ASPNETCORE_DETAILEDERRORS
      value: "true"
    - name: Logging__LogLevel__Default
      value: "Debug"
  
  secrets:
    existingSecret: "fundamental-backend-secrets"
    keys:
      jwtSecret: "jwt-secret"
      apiKey: "api-key"

# =============================================================================
# Frontend (Development)
# =============================================================================
frontend:
  replicaCount: 1
  
  image:
    repository: ${registry}/${frontend_image}
    tag: "${dev_tag}"
  
  resources:
    limits:
      cpu: ${dev_frontend_cpu_limit}
      memory: ${dev_frontend_memory_limit}
    requests:
      cpu: ${dev_frontend_cpu_request}
      memory: ${dev_frontend_memory_request}
  
  autoscaling:
    enabled: false
  
  podDisruptionBudget:
    enabled: false
  
  apiBaseUrl: "/api"

# =============================================================================
# Migrator (Development)
# =============================================================================
migrator:
  enabled: true
  
  image:
    repository: ${registry}/${migrations_image}
    tag: "${dev_tag}"
  
  resources:
    limits:
      cpu: 300m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

# =============================================================================
# Ingress (Development)
# =============================================================================
ingress:
  enabled: true
  className: "${ingress_class}"
  
  annotations:
    cert-manager.io/cluster-issuer: "${cluster_issuer}"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
    nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
  
  hosts:
    - host: ${dev_domain}
      paths:
        - path: /api
          pathType: Prefix
          service: backend
        - path: /
          pathType: Prefix
          service: frontend
  
  tls:
    - secretName: ${dev_frontend}-${domain_base//./-}-tls
      hosts:
        - ${dev_domain}

# =============================================================================
# Registry Ingress (Development)
# =============================================================================
registryIngress:
  enabled: true
  className: "${ingress_class}"
  
  annotations:
    cert-manager.io/cluster-issuer: "${cluster_issuer}"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/auth-type: "basic"
    nginx.ingress.kubernetes.io/auth-secret: "registry-auth"
    nginx.ingress.kubernetes.io/auth-realm: "Container Registry"
  
  host: ${registry}
  
  service:
    name: registry
    namespace: container-registry
    port: 5000
  
  tls:
    secretName: registry-tls

# =============================================================================
# PostgreSQL (Development)
# =============================================================================
postgresql:
  enabled: true
  
  image:
    repository: postgres
    tag: "17-alpine"
  
  auth:
    existingSecret: "postgresql-credentials"
    secretKeys:
      usernameKey: "username"
      passwordKey: "password"
    database: "${dev_db}"
  
  persistence:
    enabled: true
    size: 5Gi
  
  resources:
    limits:
      cpu: ${dev_postgres_cpu_limit}
      memory: ${dev_postgres_memory_limit}
    requests:
      cpu: ${dev_postgres_cpu_request}
      memory: ${dev_postgres_memory_request}

# =============================================================================
# Redis (Development)
# =============================================================================
redis:
  enabled: true
  
  image:
    repository: redis
    tag: "7-alpine"
  
  auth:
    enabled: true
    existingSecret: "redis-credentials"
    existingSecretPasswordKey: "password"
  
  persistence:
    enabled: true
    size: 1Gi
  
  resources:
    limits:
      cpu: ${dev_redis_cpu_limit}
      memory: ${dev_redis_memory_limit}
    requests:
      cpu: ${dev_redis_cpu_request}
      memory: ${dev_redis_memory_request}

# =============================================================================
# Network Policies (Development)
# =============================================================================
networkPolicies:
  enabled: true
  ingressNamespace: "ingress"
  ingressControllerLabels:
    name: nginx-ingress-microk8s

# =============================================================================
# Service Account (Development)
# =============================================================================
serviceAccount:
  create: true
  name: "fundamental-dev-sa"
  annotations: {}
EOF

    log_success "Generated: charts/fundamental-stack/values-dev.yaml"
    
    # Generate production values
    local prod_domain="${domain_base}"
    local prod_db=$(cfg '.database.postgres.database_name.prod')
    local prod_aspnet=$(cfg '.application.aspnet_environment.prod')
    local prod_tag=$(cfg '.application.default_tag.prod')
    
    # Prod resources
    local prod_backend_cpu_limit=$(cfg '.resources.prod.backend.cpu_limit')
    local prod_backend_memory_limit=$(cfg '.resources.prod.backend.memory_limit')
    local prod_backend_cpu_request=$(cfg '.resources.prod.backend.cpu_request')
    local prod_backend_memory_request=$(cfg '.resources.prod.backend.memory_request')
    local prod_frontend_cpu_limit=$(cfg '.resources.prod.frontend.cpu_limit')
    local prod_frontend_memory_limit=$(cfg '.resources.prod.frontend.memory_limit')
    local prod_frontend_cpu_request=$(cfg '.resources.prod.frontend.cpu_request')
    local prod_frontend_memory_request=$(cfg '.resources.prod.frontend.memory_request')
    local prod_postgres_cpu_limit=$(cfg '.resources.prod.postgres.cpu_limit')
    local prod_postgres_memory_limit=$(cfg '.resources.prod.postgres.memory_limit')
    local prod_postgres_cpu_request=$(cfg '.resources.prod.postgres.cpu_request')
    local prod_postgres_memory_request=$(cfg '.resources.prod.postgres.memory_request')
    local prod_redis_cpu_limit=$(cfg '.resources.prod.redis.cpu_limit')
    local prod_redis_memory_limit=$(cfg '.resources.prod.redis.memory_limit')
    local prod_redis_cpu_request=$(cfg '.resources.prod.redis.cpu_request')
    local prod_redis_memory_request=$(cfg '.resources.prod.redis.memory_request')
    
    cat > "${ROOT_DIR}/charts/fundamental-stack/values-prod.yaml" << EOF
# =============================================================================
# Production Environment Values
# =============================================================================
# AUTO-GENERATED from config.yaml - DO NOT EDIT MANUALLY
# Run: ./scripts/generate-config.sh to regenerate
# =============================================================================

# Global settings
global:
  imagePullSecrets:
    - name: registry-credentials
  
  domain: "${prod_domain}"

# =============================================================================
# Backend (Production)
# =============================================================================
backend:
  replicaCount: 2
  
  image:
    repository: ${registry}/${backend_image}
    tag: "${prod_tag}"
  
  aspnetEnvironment: "${prod_aspnet}"
  
  resources:
    limits:
      cpu: ${prod_backend_cpu_limit}
      memory: ${prod_backend_memory_limit}
    requests:
      cpu: ${prod_backend_cpu_request}
      memory: ${prod_backend_memory_request}
  
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilizationPercentage: 70
  
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
  
  secrets:
    existingSecret: "fundamental-backend-secrets"
    keys:
      jwtSecret: "jwt-secret"
      apiKey: "api-key"

# =============================================================================
# Frontend (Production)
# =============================================================================
frontend:
  replicaCount: 2
  
  image:
    repository: ${registry}/${frontend_image}
    tag: "${prod_tag}"
  
  resources:
    limits:
      cpu: ${prod_frontend_cpu_limit}
      memory: ${prod_frontend_memory_limit}
    requests:
      cpu: ${prod_frontend_cpu_request}
      memory: ${prod_frontend_memory_request}
  
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 5
    targetCPUUtilizationPercentage: 70
  
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
  
  apiBaseUrl: "/api"

# =============================================================================
# Migrator (Production)
# =============================================================================
migrator:
  enabled: true
  
  image:
    repository: ${registry}/${migrations_image}
    tag: "${prod_tag}"
  
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi

# =============================================================================
# Ingress (Production)
# =============================================================================
ingress:
  enabled: true
  className: "${ingress_class}"
  
  annotations:
    cert-manager.io/cluster-issuer: "${cluster_issuer}"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
    nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
  
  hosts:
    - host: ${prod_domain}
      paths:
        - path: /api
          pathType: Prefix
          service: backend
        - path: /
          pathType: Prefix
          service: frontend
  
  tls:
    - secretName: ${domain_base//./-}-tls
      hosts:
        - ${prod_domain}

# =============================================================================
# Registry Ingress (Production)
# =============================================================================
registryIngress:
  enabled: true
  className: "${ingress_class}"
  
  annotations:
    cert-manager.io/cluster-issuer: "${cluster_issuer}"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/auth-type: "basic"
    nginx.ingress.kubernetes.io/auth-secret: "registry-auth"
    nginx.ingress.kubernetes.io/auth-realm: "Container Registry"
  
  host: ${registry}
  
  service:
    name: registry
    namespace: container-registry
    port: 5000
  
  tls:
    secretName: registry-tls

# =============================================================================
# PostgreSQL (Production)
# =============================================================================
postgresql:
  enabled: true
  
  image:
    repository: postgres
    tag: "17-alpine"
  
  auth:
    existingSecret: "postgresql-credentials"
    secretKeys:
      usernameKey: "username"
      passwordKey: "password"
    database: "${prod_db}"
  
  persistence:
    enabled: true
    size: 20Gi
  
  resources:
    limits:
      cpu: ${prod_postgres_cpu_limit}
      memory: ${prod_postgres_memory_limit}
    requests:
      cpu: ${prod_postgres_cpu_request}
      memory: ${prod_postgres_memory_request}

# =============================================================================
# Redis (Production)
# =============================================================================
redis:
  enabled: true
  
  image:
    repository: redis
    tag: "7-alpine"
  
  auth:
    enabled: true
    existingSecret: "redis-credentials"
    existingSecretPasswordKey: "password"
  
  persistence:
    enabled: true
    size: 5Gi
  
  resources:
    limits:
      cpu: ${prod_redis_cpu_limit}
      memory: ${prod_redis_memory_limit}
    requests:
      cpu: ${prod_redis_cpu_request}
      memory: ${prod_redis_memory_request}

# =============================================================================
# Network Policies (Production)
# =============================================================================
networkPolicies:
  enabled: true
  ingressNamespace: "ingress"
  ingressControllerLabels:
    name: nginx-ingress-microk8s

# =============================================================================
# Service Account (Production)
# =============================================================================
serviceAccount:
  create: true
  name: "fundamental-prod-sa"
  annotations: {}
EOF

    log_success "Generated: charts/fundamental-stack/values-prod.yaml"
}

# -----------------------------------------------------------------------------
# Update Ansible Playbooks to Use Variables
# -----------------------------------------------------------------------------

update_ansible_playbooks() {
    log_info "Updating Ansible playbooks to use variables..."
    
    # Update setup-argocd.yaml
    sed -i 's/argocd_domain: argocd\.academind\.ir/argocd_domain: "{{ argocd_domain }}"/' \
        "${ROOT_DIR}/ansible/playbooks/setup-argocd.yaml" 2>/dev/null || true
    
    # Update setup-registry-proxy.yaml
    sed -i 's/registry_domain: registry\.academind\.ir/registry_domain: "{{ registry_domain }}"/' \
        "${ROOT_DIR}/ansible/playbooks/setup-registry-proxy.yaml" 2>/dev/null || true
    
    # Update setup-github-secrets.yaml
    sed -i 's/registry_host: registry\.academind\.ir/registry_host: "{{ registry_host }}"/' \
        "${ROOT_DIR}/ansible/playbooks/setup-github-secrets.yaml" 2>/dev/null || true
    
    # Update setup-kubernetes-secrets.yaml
    sed -i 's/registry_external_host: "registry\.academind\.ir"/registry_external_host: "{{ registry_external_host }}"/' \
        "${ROOT_DIR}/ansible/playbooks/setup-kubernetes-secrets.yaml" 2>/dev/null || true
    
    log_success "Updated Ansible playbooks"
}

# -----------------------------------------------------------------------------
# Generate Summary
# -----------------------------------------------------------------------------

generate_summary() {
    local domain_base=$(cfg '.domain.base')
    local dev_frontend=$(cfg '.domain.subdomains.dev.frontend')
    local argocd=$(cfg '.domain.subdomains.prod.argocd')
    local registry=$(cfg '.domain.subdomains.prod.registry')
    
    echo ""
    echo "============================================================================="
    echo "  Configuration Generated Successfully!"
    echo "============================================================================="
    echo ""
    echo "  Domain: ${domain_base}"
    echo ""
    echo "  URLs:"
    echo "    - Dev Frontend:  https://${dev_frontend}.${domain_base}"
    echo "    - Prod Frontend: https://${domain_base}"
    echo "    - ArgoCD:        https://${argocd}.${domain_base}"
    echo "    - Registry:      https://${registry}.${domain_base}"
    echo ""
    echo "  Generated Files:"
    echo "    - infrastructure/live/terragrunt.hcl"
    echo "    - ansible/group_vars/all.yaml"
    echo "    - charts/fundamental-stack/values-dev.yaml"
    echo "    - charts/fundamental-stack/values-prod.yaml"
    echo ""
    echo "  Next Steps:"
    echo "    1. Review the generated files"
    echo "    2. Commit and push changes"
    echo "    3. Run Terragrunt to update DNS: cd infrastructure/live/development/dns && terragrunt apply"
    echo "    4. Run Ansible to update VPS: cd ansible && ansible-playbook -i inventory/hosts.ini playbooks/full-deploy.yaml"
    echo ""
    echo "============================================================================="
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    echo ""
    echo "============================================================================="
    echo "  Fundamental Infrastructure - Configuration Generator"
    echo "============================================================================="
    echo ""
    
    check_requirements
    
    generate_terragrunt
    generate_ansible_vars
    generate_helm_values
    update_ansible_playbooks
    
    generate_summary
}

main "$@"
