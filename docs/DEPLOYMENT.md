# Fundamental Platform - Deployment Guide

This document provides a comprehensive guide for deploying the Fundamental Platform from development to production using GitOps principles with ArgoCD and Helm.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Repository Structure](#repository-structure)
4. [Required Secrets](#required-secrets)
5. [Initial Setup](#initial-setup)
6. [CI/CD Pipeline](#cicd-pipeline)
7. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Developer Workflow                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. Push Code ───▶ GitHub Repo ───▶ CI/CD Workflow                         │
│                                        │                                    │
│                                        ▼                                    │
│                               Build & Test                                  │
│                                        │                                    │
│                                        ▼                                    │
│                         Push Docker Image to Registry                       │
│                                        │                                    │
│                                        ▼                                    │
│                      Trigger Infra Repo (repository_dispatch)               │
│                                        │                                    │
│                                        ▼                                    │
│                         Update values-{env}.yaml tag                        │
│                                        │                                    │
│                                        ▼                                    │
│                      ArgoCD detects change, syncs app                       │
│                                        │                                    │
│                                        ▼                                    │
│                      Kubernetes applies new deployment                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Components

| Component | Description | Image |
|-----------|-------------|-------|
| **Backend API** | .NET 9.0 ASP.NET Core Web API | `registry.academind.ir/fundamental-backend` |
| **Migrator** | EF Core Database Migrations (Helm Hook Job) | `registry.academind.ir/fundamental-migrations` |
| **Frontend** | Angular 16 SPA served by Nginx | `registry.academind.ir/fundamental-frontend` |
| **PostgreSQL** | Primary database | Bitnami PostgreSQL |
| **Redis** | Caching layer | Bitnami Redis |

---

## Prerequisites

### Required Tools

- **kubectl** - Kubernetes CLI
- **helm** - Kubernetes package manager (v3.12+)
- **argocd** - ArgoCD CLI (optional)
- **docker** - For local testing

### Kubernetes Cluster

- MicroK8s or any Kubernetes 1.28+
- Ingress controller (nginx-ingress)
- Cert-manager for TLS certificates
- ArgoCD installed in the cluster

---

## Repository Structure

```
Fundamental.Backend/
├── Dockerfile              # API Docker build
├── Dockerfile.migrations   # Migrations Docker build
├── .dockerignore
└── .github/workflows/
    └── ci-cd.yaml          # Backend CI/CD pipeline

Fundamental.FrontEnd/
├── Dockerfile              # Frontend Docker build
├── nginx.conf              # Nginx configuration
├── .dockerignore
└── .github/workflows/
    └── ci-cd.yaml          # Frontend CI/CD pipeline

Fundamental.Infra/
├── charts/
│   └── fundamental-stack/
│       ├── Chart.yaml
│       ├── values.yaml         # Default values
│       ├── values-dev.yaml     # Development overrides
│       └── values-prod.yaml    # Production overrides
├── argocd/
│   ├── projects/
│   │   └── fundamental.yaml    # ArgoCD project
│   └── applications/
│       ├── fundamental-dev.yaml
│       └── fundamental-prod.yaml
└── .github/workflows/
    └── update-tag.yml          # GitOps tag updater
```

---

## Required Secrets

### 1. GitHub Repository Secrets

Configure these secrets in **Fundamental.Backend** and **Fundamental.FrontEnd** repositories:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `REGISTRY_USERNAME` | Docker registry username | `your-registry-user` |
| `REGISTRY_PASSWORD` | Docker registry password | `your-registry-password` |
| `INFRA_REPO_TOKEN` | GitHub PAT with `repo` scope for triggering Infra workflows | `ghp_xxxxxxxxxxxx` |

**How to create GitHub PAT:**
1. Go to GitHub → Settings → Developer Settings → Personal Access Tokens → Fine-grained tokens
2. Create a new token with:
   - Repository access: `Fundamental.Infra`
   - Permissions: `Contents: Read and write`, `Actions: Read and write`

### 2. Kubernetes Secrets

Create these secrets in your Kubernetes cluster **before** deploying:

#### a) PostgreSQL Credentials

```bash
kubectl create namespace fundamental-dev
kubectl create namespace fundamental-prod

# Development
kubectl create secret generic postgresql-credentials \
  --namespace=fundamental-dev \
  --from-literal=postgres-password=<POSTGRES_PASSWORD> \
  --from-literal=password=<APP_USER_PASSWORD>

# Production
kubectl create secret generic postgresql-credentials \
  --namespace=fundamental-prod \
  --from-literal=postgres-password=<POSTGRES_PASSWORD> \
  --from-literal=password=<APP_USER_PASSWORD>
```

#### b) Redis Credentials

```bash
# Development
kubectl create secret generic redis-credentials \
  --namespace=fundamental-dev \
  --from-literal=redis-password=<REDIS_PASSWORD>

# Production
kubectl create secret generic redis-credentials \
  --namespace=fundamental-prod \
  --from-literal=redis-password=<REDIS_PASSWORD>
```

#### c) Backend Application Secrets

```bash
# Development
kubectl create secret generic fundamental-backend-secrets \
  --namespace=fundamental-dev \
  --from-literal=JWT_SECRET=<YOUR_JWT_SECRET> \
  --from-literal=SENTRY_DSN=<YOUR_SENTRY_DSN> \
  --from-literal=EXTERNAL_API_KEY=<API_KEY>

# Production
kubectl create secret generic fundamental-backend-secrets \
  --namespace=fundamental-prod \
  --from-literal=JWT_SECRET=<YOUR_JWT_SECRET> \
  --from-literal=SENTRY_DSN=<YOUR_SENTRY_DSN> \
  --from-literal=EXTERNAL_API_KEY=<API_KEY>
```

#### d) Docker Registry Credentials

```bash
# Development
kubectl create secret docker-registry registry-credentials \
  --namespace=fundamental-dev \
  --docker-server=registry.academind.ir \
  --docker-username=<USERNAME> \
  --docker-password=<PASSWORD>

# Production
kubectl create secret docker-registry registry-credentials \
  --namespace=fundamental-prod \
  --docker-server=registry.academind.ir \
  --docker-username=<USERNAME> \
  --docker-password=<PASSWORD>
```

---

## Initial Setup

### Step 1: Configure ArgoCD

1. **Install ArgoCD** (if not already installed):
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

2. **Create ArgoCD Project**:
   ```bash
   kubectl apply -f argocd/projects/fundamental.yaml
   ```

3. **Update ArgoCD Application Manifests**:
   
   Edit `argocd/applications/fundamental-dev.yaml` and `fundamental-prod.yaml`:
   - Update `repoURL` to your actual Git repository URL
   - Update `server` if not using the default cluster

4. **Create ArgoCD Applications**:
   ```bash
   kubectl apply -f argocd/applications/fundamental-dev.yaml
   kubectl apply -f argocd/applications/fundamental-prod.yaml
   ```

### Step 2: Build and Push Initial Images

Before ArgoCD can deploy, you need the first images in the registry:

```bash
# Backend
cd Fundamental.Backend
docker build -t registry.academind.ir/fundamental-backend:dev-latest .
docker build -f Dockerfile.migrations -t registry.academind.ir/fundamental-migrations:dev-latest .
docker push registry.academind.ir/fundamental-backend:dev-latest
docker push registry.academind.ir/fundamental-migrations:dev-latest

# Frontend
cd ../Fundamental.FrontEnd
docker build -t registry.academind.ir/fundamental-frontend:dev-latest .
docker push registry.academind.ir/fundamental-frontend:dev-latest
```

### Step 3: Sync ArgoCD Application

```bash
# Via CLI
argocd app sync fundamental-dev

# Or via ArgoCD UI
# Navigate to https://your-argocd-server/applications/fundamental-dev
# Click "Sync"
```

---

## CI/CD Pipeline

### Automatic Deployment Flow

1. **Push to `develop` branch** → Builds and deploys to **dev** environment
2. **Push to `main` branch** → Builds and deploys to **prod** environment

### Manual Workflow Dispatch

Both Backend and Frontend CI/CD workflows support manual triggers:

```bash
# Via GitHub CLI
gh workflow run ci-cd.yaml -f environment=prod

# Or via GitHub UI
# Go to Actions → CI/CD → Run workflow → Select environment
```

### Deployment Sequence

```
1. Backend CI/CD triggers
   ├── Builds API image
   ├── Builds Migrations image
   ├── Pushes both to registry
   ├── Triggers update-tag.yml (backend component)
   └── Triggers update-tag.yml (migrator component)

2. update-tag.yml runs
   ├── Updates values-{env}.yaml
   └── Commits change

3. ArgoCD detects change
   ├── Runs migrations job (pre-install hook)
   │   └── Waits for PostgreSQL
   │   └── Applies EF Core migrations
   ├── Deploys Backend API
   └── Deploys Frontend
```

---

## Troubleshooting

### Migrations Job Failed

```bash
# Check migration job logs
kubectl logs -n fundamental-dev job/fundamental-stack-migrator

# Check if PostgreSQL is ready
kubectl get pods -n fundamental-dev -l app.kubernetes.io/name=postgresql

# Re-run migrations by triggering a sync
argocd app sync fundamental-dev --resource 'Job:fundamental-stack-migrator'
```

### Image Pull Errors

```bash
# Verify registry secret exists
kubectl get secret registry-credentials -n fundamental-dev

# Check if secret is correctly formatted
kubectl get secret registry-credentials -n fundamental-dev -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d

# Manually test pull
docker login registry.academind.ir
docker pull registry.academind.ir/fundamental-backend:dev-latest
```

### Health Check Failures

```bash
# Check backend health
kubectl exec -it deploy/fundamental-stack-backend -n fundamental-dev -- wget -qO- http://localhost:8080/health

# Check individual probes
kubectl exec -it deploy/fundamental-stack-backend -n fundamental-dev -- wget -qO- http://localhost:8080/health/live
kubectl exec -it deploy/fundamental-stack-backend -n fundamental-dev -- wget -qO- http://localhost:8080/health/ready
kubectl exec -it deploy/fundamental-stack-backend -n fundamental-dev -- wget -qO- http://localhost:8080/health/startup
```

### ArgoCD Sync Stuck

```bash
# Check application status
argocd app get fundamental-dev

# Force refresh
argocd app refresh fundamental-dev --hard-refresh

# Check for sync waves issues
kubectl get all -n fundamental-dev -l app.kubernetes.io/instance=fundamental-dev
```

### Backend Not Connecting to Database

```bash
# Verify connection string secret
kubectl get secret fundamental-stack-backend-secrets -n fundamental-dev -o yaml

# Check backend logs
kubectl logs -n fundamental-dev deploy/fundamental-stack-backend

# Test PostgreSQL connectivity
kubectl exec -it deploy/fundamental-stack-backend -n fundamental-dev -- nc -zv fundamental-stack-postgresql 5432
```

---

## Environment Configuration

### Development (`values-dev.yaml`)

- Single replica for each component
- Resource limits: 256Mi-512Mi memory
- No autoscaling
- Debug logging enabled

### Production (`values-prod.yaml`)

- Multiple replicas with HPA
- Higher resource limits: 512Mi-1Gi memory
- Autoscaling enabled (2-10 pods)
- Production logging (Warning+)
- Pod disruption budgets

---

## Quick Reference

### Useful Commands

```bash
# Check deployment status
kubectl get all -n fundamental-dev

# View backend logs
kubectl logs -f -n fundamental-dev -l app.kubernetes.io/component=backend

# Port-forward for local testing
kubectl port-forward -n fundamental-dev svc/fundamental-stack-backend 8080:80

# Check ArgoCD sync status
argocd app list

# Manual sync
argocd app sync fundamental-dev

# Rollback to previous revision
argocd app rollback fundamental-dev 1
```

### Health Endpoints

| Endpoint | Purpose | Used By |
|----------|---------|---------|
| `/health/startup` | Container initialization complete | K8s startupProbe |
| `/health/live` | Process is alive | K8s livenessProbe |
| `/health/ready` | Ready to accept traffic | K8s readinessProbe |
| `/health` | Overall status (all checks) | Monitoring |

---

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review ArgoCD and Kubernetes logs
3. Contact the DevOps team
