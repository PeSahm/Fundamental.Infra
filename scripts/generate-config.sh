#!/usr/bin/env bash
# =============================================================================
# Configuration Generator Script (Multi-Environment)
# =============================================================================
# This script reads config.yaml and generates configuration files for:
#   - Ansible (ansible/group_vars/)
#   - Helm values (charts/fundamental-stack/)
#   - ArgoCD applications (argocd/applications/)
#   - CI/CD workflow templates
#
# Branch Strategy:
#   - develop branch → Development environment (dev.academind.ir)
#   - main branch    → Production environment (sahmbaz.ir)
#
# Usage:
#   ./scripts/generate-config.sh [--env dev|prod|all]
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

# Default: generate for all environments
TARGET_ENV="${1:-all}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_section() {
    echo -e "\n${CYAN}=== $1 ===${NC}\n"
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

# Read environment-specific value
env_cfg() {
    local env="$1"
    local path="$2"
    yq eval ".environments.${env}${path}" "${CONFIG_FILE}"
}

# Read shared config value
shared_cfg() {
    local path="$1"
    yq eval ".shared${path}" "${CONFIG_FILE}"
}

# -----------------------------------------------------------------------------
# Generate Ansible Variables
# -----------------------------------------------------------------------------

generate_ansible_vars() {
    log_section "Generating Ansible Variables"
    
    # Shared values
    local vps_ip=$(shared_cfg '.vps.ip')
    local ssh_user=$(shared_cfg '.vps.ssh_user')
    local registry_domain=$(shared_cfg '.registry.domain')
    local registry_username=$(shared_cfg '.registry.username')
    local argocd_domain=$(shared_cfg '.argocd.domain')
    local github_owner=$(shared_cfg '.github.owner')
    local ingress_class=$(shared_cfg '.kubernetes.ingress_class')
    local cluster_issuer=$(shared_cfg '.kubernetes.cluster_issuer')
    
    # Dev environment
    local dev_domain=$(env_cfg 'dev' '.domain.full')
    local dev_namespace=$(env_cfg 'dev' '.namespace')
    local dev_branch=$(env_cfg 'dev' '.branch')
    local dev_image_tag=$(env_cfg 'dev' '.image_tag')
    
    # Prod environment
    local prod_domain=$(env_cfg 'prod' '.domain.full')
    local prod_namespace=$(env_cfg 'prod' '.namespace')
    local prod_branch=$(env_cfg 'prod' '.branch')
    local prod_image_tag=$(env_cfg 'prod' '.image_tag')
    
    # Create group_vars directory
    mkdir -p "${ROOT_DIR}/ansible/group_vars"
    
    cat > "${ROOT_DIR}/ansible/group_vars/all.yaml" << EOF
# =============================================================================
# Ansible Global Variables
# =============================================================================
# AUTO-GENERATED from config.yaml - DO NOT EDIT MANUALLY
# Run: ./scripts/generate-config.sh to regenerate
# =============================================================================

# -----------------------------------------------------------------------------
# VPS Configuration
# -----------------------------------------------------------------------------
vps_ip: "${vps_ip}"
ansible_user: "${ssh_user}"

# -----------------------------------------------------------------------------
# Shared Services
# -----------------------------------------------------------------------------
registry_domain: "${registry_domain}"
registry_username: "${registry_username}"
registry_external_host: "${registry_domain}"

argocd_domain: "${argocd_domain}"
argocd_namespace: "argocd"

# -----------------------------------------------------------------------------
# GitHub Configuration
# -----------------------------------------------------------------------------
github_owner: "${github_owner}"
registry_host: "${registry_domain}"

# -----------------------------------------------------------------------------
# Kubernetes Configuration
# -----------------------------------------------------------------------------
ingress_class: "${ingress_class}"
cluster_issuer: "${cluster_issuer}"

# -----------------------------------------------------------------------------
# Environment Configuration
# -----------------------------------------------------------------------------
environments:
  dev:
    domain: "${dev_domain}"
    namespace: "${dev_namespace}"
    branch: "${dev_branch}"
    image_tag: "${dev_image_tag}"
  prod:
    domain: "${prod_domain}"
    namespace: "${prod_namespace}"
    branch: "${prod_branch}"
    image_tag: "${prod_image_tag}"

# -----------------------------------------------------------------------------
# Default Environment (for single-env playbooks)
# -----------------------------------------------------------------------------
domain_base: "${dev_domain}"
default_namespace: "${dev_namespace}"

# -----------------------------------------------------------------------------
# Credentials Directory
# -----------------------------------------------------------------------------
credentials_dir: "/root/.fundamental-credentials"
EOF

    log_success "Generated: ansible/group_vars/all.yaml"
}

# -----------------------------------------------------------------------------
# Generate Helm Values for Development
# -----------------------------------------------------------------------------

generate_helm_values_dev() {
    log_section "Generating Helm Values (Development)"
    
    # Shared values
    local registry=$(shared_cfg '.registry.domain')
    local backend_image=$(shared_cfg '.registry.images.backend')
    local frontend_image=$(shared_cfg '.registry.images.frontend')
    local migrations_image=$(shared_cfg '.registry.images.migrations')
    local ingress_class=$(shared_cfg '.kubernetes.ingress_class')
    local cluster_issuer=$(shared_cfg '.kubernetes.cluster_issuer')
    local postgres_username=$(shared_cfg '.database.postgres_username')
    
    # Dev environment values
    local domain=$(env_cfg 'dev' '.domain.full')
    local namespace=$(env_cfg 'dev' '.namespace')
    local aspnet_env=$(env_cfg 'dev' '.aspnet_environment')
    local image_tag=$(env_cfg 'dev' '.image_tag')
    local db_name=$(env_cfg 'dev' '.database_name')
    local replicas_backend=$(env_cfg 'dev' '.replicas.backend')
    local replicas_frontend=$(env_cfg 'dev' '.replicas.frontend')
    local autoscaling=$(env_cfg 'dev' '.autoscaling.enabled')
    
    # Resources
    local backend_cpu_limit=$(env_cfg 'dev' '.resources.backend.cpu_limit')
    local backend_mem_limit=$(env_cfg 'dev' '.resources.backend.memory_limit')
    local backend_cpu_req=$(env_cfg 'dev' '.resources.backend.cpu_request')
    local backend_mem_req=$(env_cfg 'dev' '.resources.backend.memory_request')
    
    local frontend_cpu_limit=$(env_cfg 'dev' '.resources.frontend.cpu_limit')
    local frontend_mem_limit=$(env_cfg 'dev' '.resources.frontend.memory_limit')
    local frontend_cpu_req=$(env_cfg 'dev' '.resources.frontend.cpu_request')
    local frontend_mem_req=$(env_cfg 'dev' '.resources.frontend.memory_request')
    
    local postgres_cpu_limit=$(env_cfg 'dev' '.resources.postgres.cpu_limit')
    local postgres_mem_limit=$(env_cfg 'dev' '.resources.postgres.memory_limit')
    local postgres_cpu_req=$(env_cfg 'dev' '.resources.postgres.cpu_request')
    local postgres_mem_req=$(env_cfg 'dev' '.resources.postgres.memory_request')
    local postgres_storage=$(env_cfg 'dev' '.resources.postgres.storage')
    
    local redis_cpu_limit=$(env_cfg 'dev' '.resources.redis.cpu_limit')
    local redis_mem_limit=$(env_cfg 'dev' '.resources.redis.memory_limit')
    local redis_cpu_req=$(env_cfg 'dev' '.resources.redis.cpu_request')
    local redis_mem_req=$(env_cfg 'dev' '.resources.redis.memory_request')
    local redis_storage=$(env_cfg 'dev' '.resources.redis.storage')
    
    # Generate TLS secret name (replace dots with dashes)
    local tls_secret="${domain//./-}-tls"
    
    cat > "${ROOT_DIR}/charts/fundamental-stack/values-dev.yaml" << EOF
# =============================================================================
# Development Environment Values
# =============================================================================
# AUTO-GENERATED from config.yaml - DO NOT EDIT MANUALLY
# Run: ./scripts/generate-config.sh to regenerate
#
# Environment: Development
# Branch: develop
# Domain: ${domain}
# Namespace: ${namespace}
# =============================================================================

# Global settings
global:
  imagePullSecrets:
    - name: registry-credentials
  
  domain: "${domain}"
  environment: "development"

# =============================================================================
# Backend (Development)
# =============================================================================
backend:
  replicaCount: ${replicas_backend}
  
  image:
    repository: ${registry}/${backend_image}
    tag: "${image_tag}"
  
  aspnetEnvironment: "${aspnet_env}"
  
  resources:
    limits:
      cpu: ${backend_cpu_limit}
      memory: ${backend_mem_limit}
    requests:
      cpu: ${backend_cpu_req}
      memory: ${backend_mem_req}
  
  autoscaling:
    enabled: ${autoscaling}
  
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
  replicaCount: ${replicas_frontend}
  
  image:
    repository: ${registry}/${frontend_image}
    tag: "${image_tag}"
  
  resources:
    limits:
      cpu: ${frontend_cpu_limit}
      memory: ${frontend_mem_limit}
    requests:
      cpu: ${frontend_cpu_req}
      memory: ${frontend_mem_req}
  
  autoscaling:
    enabled: ${autoscaling}
  
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
    tag: "${image_tag}"
  
  resources:
    limits:
      cpu: 300m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

# =============================================================================
# Ingress - Backend (Development)
# =============================================================================
backendIngress:
  enabled: true
  className: "${ingress_class}"
  
  annotations:
    cert-manager.io/cluster-issuer: "${cluster_issuer}"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
  
  hosts:
    - host: ${domain}
      paths:
        - path: /api
          pathType: Prefix
  
  tls:
    - secretName: ${tls_secret}
      hosts:
        - ${domain}

# =============================================================================
# Ingress - Frontend (Development)
# =============================================================================
frontendIngress:
  enabled: true
  className: "${ingress_class}"
  
  annotations:
    cert-manager.io/cluster-issuer: "${cluster_issuer}"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
  
  hosts:
    - host: ${domain}
      paths:
        - path: /
          pathType: Prefix
  
  tls:
    - secretName: ${tls_secret}
      hosts:
        - ${domain}

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
    database: "${db_name}"
  
  persistence:
    enabled: true
    size: ${postgres_storage}
  
  resources:
    limits:
      cpu: ${postgres_cpu_limit}
      memory: ${postgres_mem_limit}
    requests:
      cpu: ${postgres_cpu_req}
      memory: ${postgres_mem_req}

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
    size: ${redis_storage}
  
  resources:
    limits:
      cpu: ${redis_cpu_limit}
      memory: ${redis_mem_limit}
    requests:
      cpu: ${redis_cpu_req}
      memory: ${redis_mem_req}

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
}

# -----------------------------------------------------------------------------
# Generate Helm Values for Production
# -----------------------------------------------------------------------------

generate_helm_values_prod() {
    log_section "Generating Helm Values (Production)"
    
    # Shared values
    local registry=$(shared_cfg '.registry.domain')
    local backend_image=$(shared_cfg '.registry.images.backend')
    local frontend_image=$(shared_cfg '.registry.images.frontend')
    local migrations_image=$(shared_cfg '.registry.images.migrations')
    local ingress_class=$(shared_cfg '.kubernetes.ingress_class')
    local cluster_issuer=$(shared_cfg '.kubernetes.cluster_issuer')
    local postgres_username=$(shared_cfg '.database.postgres_username')
    
    # Prod environment values
    local domain=$(env_cfg 'prod' '.domain.full')
    local namespace=$(env_cfg 'prod' '.namespace')
    local aspnet_env=$(env_cfg 'prod' '.aspnet_environment')
    local image_tag=$(env_cfg 'prod' '.image_tag')
    local db_name=$(env_cfg 'prod' '.database_name')
    local replicas_backend=$(env_cfg 'prod' '.replicas.backend')
    local replicas_frontend=$(env_cfg 'prod' '.replicas.frontend')
    local autoscaling=$(env_cfg 'prod' '.autoscaling.enabled')
    local min_replicas=$(env_cfg 'prod' '.autoscaling.min_replicas')
    local max_replicas=$(env_cfg 'prod' '.autoscaling.max_replicas')
    local target_cpu=$(env_cfg 'prod' '.autoscaling.target_cpu')
    
    # Resources
    local backend_cpu_limit=$(env_cfg 'prod' '.resources.backend.cpu_limit')
    local backend_mem_limit=$(env_cfg 'prod' '.resources.backend.memory_limit')
    local backend_cpu_req=$(env_cfg 'prod' '.resources.backend.cpu_request')
    local backend_mem_req=$(env_cfg 'prod' '.resources.backend.memory_request')
    
    local frontend_cpu_limit=$(env_cfg 'prod' '.resources.frontend.cpu_limit')
    local frontend_mem_limit=$(env_cfg 'prod' '.resources.frontend.memory_limit')
    local frontend_cpu_req=$(env_cfg 'prod' '.resources.frontend.cpu_request')
    local frontend_mem_req=$(env_cfg 'prod' '.resources.frontend.memory_request')
    
    local postgres_cpu_limit=$(env_cfg 'prod' '.resources.postgres.cpu_limit')
    local postgres_mem_limit=$(env_cfg 'prod' '.resources.postgres.memory_limit')
    local postgres_cpu_req=$(env_cfg 'prod' '.resources.postgres.cpu_request')
    local postgres_mem_req=$(env_cfg 'prod' '.resources.postgres.memory_request')
    local postgres_storage=$(env_cfg 'prod' '.resources.postgres.storage')
    
    local redis_cpu_limit=$(env_cfg 'prod' '.resources.redis.cpu_limit')
    local redis_mem_limit=$(env_cfg 'prod' '.resources.redis.memory_limit')
    local redis_cpu_req=$(env_cfg 'prod' '.resources.redis.cpu_request')
    local redis_mem_req=$(env_cfg 'prod' '.resources.redis.memory_request')
    local redis_storage=$(env_cfg 'prod' '.resources.redis.storage')
    
    # Generate TLS secret name (replace dots with dashes)
    local tls_secret="${domain//./-}-tls"
    
    cat > "${ROOT_DIR}/charts/fundamental-stack/values-prod.yaml" << EOF
# =============================================================================
# Production Environment Values
# =============================================================================
# AUTO-GENERATED from config.yaml - DO NOT EDIT MANUALLY
# Run: ./scripts/generate-config.sh to regenerate
#
# Environment: Production
# Branch: main
# Domain: ${domain}
# Namespace: ${namespace}
# =============================================================================

# Global settings
global:
  imagePullSecrets:
    - name: registry-credentials
  
  domain: "${domain}"
  environment: "production"

# =============================================================================
# Backend (Production)
# =============================================================================
backend:
  replicaCount: ${replicas_backend}
  
  image:
    repository: ${registry}/${backend_image}
    tag: "${image_tag}"
  
  aspnetEnvironment: "${aspnet_env}"
  
  resources:
    limits:
      cpu: ${backend_cpu_limit}
      memory: ${backend_mem_limit}
    requests:
      cpu: ${backend_cpu_req}
      memory: ${backend_mem_req}
  
  autoscaling:
    enabled: ${autoscaling}
    minReplicas: ${min_replicas}
    maxReplicas: ${max_replicas}
    targetCPUUtilizationPercentage: ${target_cpu}
  
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
  replicaCount: ${replicas_frontend}
  
  image:
    repository: ${registry}/${frontend_image}
    tag: "${image_tag}"
  
  resources:
    limits:
      cpu: ${frontend_cpu_limit}
      memory: ${frontend_mem_limit}
    requests:
      cpu: ${frontend_cpu_req}
      memory: ${frontend_mem_req}
  
  autoscaling:
    enabled: ${autoscaling}
    minReplicas: ${min_replicas}
    maxReplicas: ${max_replicas}
    targetCPUUtilizationPercentage: ${target_cpu}
  
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
    tag: "${image_tag}"
  
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 200m
      memory: 256Mi

# =============================================================================
# Ingress - Backend (Production)
# =============================================================================
backendIngress:
  enabled: true
  className: "${ingress_class}"
  
  annotations:
    cert-manager.io/cluster-issuer: "${cluster_issuer}"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
  
  hosts:
    - host: ${domain}
      paths:
        - path: /api
          pathType: Prefix
  
  tls:
    - secretName: ${tls_secret}
      hosts:
        - ${domain}

# =============================================================================
# Ingress - Frontend (Production)
# =============================================================================
frontendIngress:
  enabled: true
  className: "${ingress_class}"
  
  annotations:
    cert-manager.io/cluster-issuer: "${cluster_issuer}"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
    nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
  
  hosts:
    - host: ${domain}
      paths:
        - path: /
          pathType: Prefix
  
  tls:
    - secretName: ${tls_secret}
      hosts:
        - ${domain}

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
    database: "${db_name}"
  
  persistence:
    enabled: true
    size: ${postgres_storage}
  
  resources:
    limits:
      cpu: ${postgres_cpu_limit}
      memory: ${postgres_mem_limit}
    requests:
      cpu: ${postgres_cpu_req}
      memory: ${postgres_mem_req}

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
    size: ${redis_storage}
  
  resources:
    limits:
      cpu: ${redis_cpu_limit}
      memory: ${redis_mem_limit}
    requests:
      cpu: ${redis_cpu_req}
      memory: ${redis_mem_req}

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
# Generate ArgoCD Applications
# -----------------------------------------------------------------------------

generate_argocd_apps() {
    log_section "Generating ArgoCD Applications"
    
    local github_owner=$(shared_cfg '.github.owner')
    local infra_repo=$(shared_cfg '.github.repositories.infra')
    
    # Dev application
    local dev_namespace=$(env_cfg 'dev' '.namespace')
    local dev_domain=$(env_cfg 'dev' '.domain.full')
    
    # Prod application
    local prod_namespace=$(env_cfg 'prod' '.namespace')
    local prod_domain=$(env_cfg 'prod' '.domain.full')
    
    mkdir -p "${ROOT_DIR}/argocd/applications"
    
    # Development Application
    cat > "${ROOT_DIR}/argocd/applications/fundamental-dev.yaml" << EOF
# =============================================================================
# ArgoCD Application - Development Environment
# =============================================================================
# AUTO-GENERATED from config.yaml - DO NOT EDIT MANUALLY
# Run: ./scripts/generate-config.sh to regenerate
#
# Domain: ${dev_domain}
# Namespace: ${dev_namespace}
# =============================================================================
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fundamental-dev
  namespace: argocd
  labels:
    app.kubernetes.io/name: fundamental
    app.kubernetes.io/instance: fundamental-dev
    app.kubernetes.io/environment: development
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: https://github.com/${github_owner}/${infra_repo}.git
    targetRevision: develop
    path: charts/fundamental-stack
    helm:
      valueFiles:
        - values-dev.yaml
  
  destination:
    server: https://kubernetes.default.svc
    namespace: ${dev_namespace}
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  revisionHistoryLimit: 10
EOF

    log_success "Generated: argocd/applications/fundamental-dev.yaml"
    
    # Production Application
    cat > "${ROOT_DIR}/argocd/applications/fundamental-prod.yaml" << EOF
# =============================================================================
# ArgoCD Application - Production Environment
# =============================================================================
# AUTO-GENERATED from config.yaml - DO NOT EDIT MANUALLY
# Run: ./scripts/generate-config.sh to regenerate
#
# Domain: ${prod_domain}
# Namespace: ${prod_namespace}
# =============================================================================
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: fundamental-prod
  namespace: argocd
  labels:
    app.kubernetes.io/name: fundamental
    app.kubernetes.io/instance: fundamental-prod
    app.kubernetes.io/environment: production
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: https://github.com/${github_owner}/${infra_repo}.git
    targetRevision: main
    path: charts/fundamental-stack
    helm:
      valueFiles:
        - values-prod.yaml
  
  destination:
    server: https://kubernetes.default.svc
    namespace: ${prod_namespace}
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  revisionHistoryLimit: 10
EOF

    log_success "Generated: argocd/applications/fundamental-prod.yaml"
}

# -----------------------------------------------------------------------------
# Generate CI/CD Configuration Reference
# -----------------------------------------------------------------------------

generate_cicd_reference() {
    log_section "Generating CI/CD Configuration Reference"
    
    local registry=$(shared_cfg '.registry.domain')
    local github_owner=$(shared_cfg '.github.owner')
    local backend_image=$(shared_cfg '.registry.images.backend')
    local frontend_image=$(shared_cfg '.registry.images.frontend')
    local migrations_image=$(shared_cfg '.registry.images.migrations')
    
    local dev_branch=$(env_cfg 'dev' '.branch')
    local dev_tag=$(env_cfg 'dev' '.image_tag')
    local dev_domain=$(env_cfg 'dev' '.domain.full')
    local dev_namespace=$(env_cfg 'dev' '.namespace')
    
    local prod_branch=$(env_cfg 'prod' '.branch')
    local prod_tag=$(env_cfg 'prod' '.image_tag')
    local prod_domain=$(env_cfg 'prod' '.domain.full')
    local prod_namespace=$(env_cfg 'prod' '.namespace')
    
    mkdir -p "${ROOT_DIR}/docs"
    
    cat > "${ROOT_DIR}/docs/CICD_CONFIGURATION.md" << EOF
# CI/CD Configuration Reference

This document describes the CI/CD configuration derived from \`config.yaml\`.

## Branch Strategy

| Branch | Environment | Domain | Image Tag | Namespace |
|--------|-------------|--------|-----------|-----------|
| \`${dev_branch}\` | Development | ${dev_domain} | \`${dev_tag}\` | ${dev_namespace} |
| \`${prod_branch}\` | Production | ${prod_domain} | \`${prod_tag}\` | ${prod_namespace} |

## Container Registry

- **Registry URL**: \`${registry}\`
- **Backend Image**: \`${registry}/${backend_image}\`
- **Frontend Image**: \`${registry}/${frontend_image}\`
- **Migrations Image**: \`${registry}/${migrations_image}\`

## GitHub Actions Workflow Configuration

### Backend Workflow Triggers

\`\`\`yaml
on:
  push:
    branches:
      - ${dev_branch}    # Triggers dev deployment
      - ${prod_branch}   # Triggers prod deployment
\`\`\`

### Image Tagging Logic

\`\`\`yaml
env:
  IMAGE_TAG: \${{ github.ref == 'refs/heads/${prod_branch}' && '${prod_tag}' || '${dev_tag}' }}
\`\`\`

### Environment Detection

\`\`\`yaml
env:
  ENVIRONMENT: \${{ github.ref == 'refs/heads/${prod_branch}' && 'production' || 'development' }}
\`\`\`

## Deployment Flow

1. **Push to \`${dev_branch}\`**:
   - Build images with tag \`${dev_tag}\`
   - Push to \`${registry}\`
   - ArgoCD detects change → deploys to \`${dev_namespace}\`

2. **Push to \`${prod_branch}\`**:
   - Build images with tag \`${prod_tag}\`
   - Push to \`${registry}\`
   - ArgoCD detects change → deploys to \`${prod_namespace}\`

## Secrets Required

GitHub repository secrets needed:

- \`REGISTRY_USERNAME\`: Container registry username
- \`REGISTRY_PASSWORD\`: Container registry password
- \`REGISTRY_URL\`: \`${registry}\`

---

*Auto-generated from config.yaml - Run \`./scripts/generate-config.sh\` to regenerate*
EOF

    log_success "Generated: docs/CICD_CONFIGURATION.md"
}

# -----------------------------------------------------------------------------
# Generate Summary
# -----------------------------------------------------------------------------

generate_summary() {
    local dev_domain=$(env_cfg 'dev' '.domain.full')
    local prod_domain=$(env_cfg 'prod' '.domain.full')
    local argocd_domain=$(shared_cfg '.argocd.domain')
    local registry=$(shared_cfg '.registry.domain')
    
    echo ""
    echo "============================================================================="
    echo "  Configuration Generated Successfully!"
    echo "============================================================================="
    echo ""
    echo "  Environments:"
    echo "    ┌─────────────┬───────────┬─────────────────────┬────────────────────┐"
    echo "    │ Environment │ Branch    │ Domain              │ Namespace          │"
    echo "    ├─────────────┼───────────┼─────────────────────┼────────────────────┤"
    echo "    │ Development │ develop   │ ${dev_domain}       │ fundamental-dev    │"
    echo "    │ Production  │ main      │ ${prod_domain}      │ fundamental-prod   │"
    echo "    └─────────────┴───────────┴─────────────────────┴────────────────────┘"
    echo ""
    echo "  Shared Services:"
    echo "    - ArgoCD:   https://${argocd_domain}"
    echo "    - Registry: https://${registry}"
    echo ""
    echo "  Generated Files:"
    echo "    - ansible/group_vars/all.yaml"
    echo "    - charts/fundamental-stack/values-dev.yaml"
    echo "    - charts/fundamental-stack/values-prod.yaml"
    echo "    - argocd/applications/fundamental-dev.yaml"
    echo "    - argocd/applications/fundamental-prod.yaml"
    echo "    - docs/CICD_CONFIGURATION.md"
    echo ""
    echo "  Next Steps:"
    echo "    1. Review the generated files"
    echo "    2. Create 'develop' branch in all repos:"
    echo "       git checkout -b develop && git push -u origin develop"
    echo "    3. Update CI/CD workflows in Backend/Frontend repos"
    echo "    4. Apply ArgoCD applications:"
    echo "       kubectl apply -f argocd/applications/"
    echo "    5. Setup DNS for sahmbaz.ir domain"
    echo ""
    echo "============================================================================="
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
    echo ""
    echo "============================================================================="
    echo "  Fundamental Infrastructure - Multi-Environment Configuration Generator"
    echo "============================================================================="
    echo ""
    
    check_requirements
    
    generate_ansible_vars
    
    if [[ "${TARGET_ENV}" == "all" || "${TARGET_ENV}" == "dev" ]]; then
        generate_helm_values_dev
    fi
    
    if [[ "${TARGET_ENV}" == "all" || "${TARGET_ENV}" == "prod" ]]; then
        generate_helm_values_prod
    fi
    
    generate_argocd_apps
    generate_cicd_reference
    
    generate_summary
}

main "$@"
