# Fundamental Stack Helm Chart

A production-ready Helm chart for deploying the Fundamental application stack following **Kubernetes 2025 best practices**.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Security](#security)
- [GitOps with ArgoCD](#gitops-with-argocd)
- [Troubleshooting](#troubleshooting)
- [For .NET Developers](#for-net-developers)

## Overview

This chart deploys the complete Fundamental application stack:

| Component | Description | Technology |
|-----------|-------------|------------|
| **Backend** | ASP.NET Core Web API | .NET 8, EF Core |
| **Frontend** | Angular SPA | Angular 18, Nginx |
| **Database** | PostgreSQL | Bitnami Chart |
| **Cache** | Redis | Bitnami Chart |
| **Migrator** | EF Core Migrations | Helm Hook Job |

### Key Features

- ✅ **Security First**: Non-root containers, read-only filesystem, dropped capabilities
- ✅ **High Availability**: PDB, anti-affinity, HPA
- ✅ **Zero-Downtime Deployments**: Rolling updates, startup/liveness/readiness probes
- ✅ **Network Isolation**: Default-deny NetworkPolicies
- ✅ **GitOps Ready**: ArgoCD integration with automated tag updates
- ✅ **Secret Management**: `existingSecret` pattern for production secrets

## Architecture

```text
                    ┌─────────────────────────────────────────────────────────┐
                    │                    Ingress Controller                    │
                    │              (nginx.ingress.kubernetes.io)               │
                    └─────────────────────────────────────────────────────────┘
                                              │
                    ┌─────────────────────────┴─────────────────────────┐
                    │                                                   │
                    ▼                                                   ▼
        ┌───────────────────┐                             ┌───────────────────┐
        │   Frontend SVC    │                             │   Backend SVC     │
        │   (ClusterIP)     │                             │   (ClusterIP)     │
        └───────────────────┘                             └───────────────────┘
                    │                                                   │
                    ▼                                                   ▼
        ┌───────────────────┐                             ┌───────────────────┐
        │ Frontend Pods (2) │                             │ Backend Pods (3)  │
        │  Angular + Nginx  │ ───────────────────────────▶│  ASP.NET Core     │
        └───────────────────┘                             └───────────────────┘
                                                                    │
                                      ┌─────────────────────────────┴───────────────────────────────┐
                                      │                                                             │
                                      ▼                                                             ▼
                          ┌───────────────────┐                                         ┌───────────────────┐
                          │   PostgreSQL SVC   │                                         │    Redis SVC      │
                          │   (ClusterIP)      │                                         │   (ClusterIP)     │
                          └───────────────────┘                                         └───────────────────┘
                                      │                                                             │
                                      ▼                                                             ▼
                          ┌───────────────────┐                                         ┌───────────────────┐
                          │  PostgreSQL Pod   │                                         │    Redis Pod      │
                          │   (Bitnami)       │                                         │   (Bitnami)       │
                          └───────────────────┘                                         └───────────────────┘
```

## Directory Structure

```text
charts/
└── fundamental-stack/
    ├── Chart.yaml                    # Chart metadata & OCI dependencies
    ├── values.yaml                   # Default values
    ├── values-dev.yaml               # Development overrides
    ├── values-prod.yaml              # Production overrides
    └── templates/
        ├── _helpers.tpl              # Reusable template helpers
        ├── deployment-backend.yaml   # Backend deployment
        ├── deployment-frontend.yaml  # Frontend deployment
        ├── service-backend.yaml      # Backend ClusterIP service
        ├── service-frontend.yaml     # Frontend ClusterIP service
        ├── configmap-backend.yaml    # Backend configuration
        ├── configmap-frontend-nginx.yaml  # Nginx config for SPA
        ├── ingress.yaml              # App ingress (/, /api)
        ├── ingress-registry.yaml     # Registry ingress with Basic Auth
        ├── networkpolicies.yaml      # Default-deny + explicit allows
        └── job-migrator.yaml         # EF Core migration hook
```

## Prerequisites

- **Kubernetes** >= 1.26
- **Helm** >= 3.12
- **MicroK8s** with addons: `ingress`, `dns`, `storage`, `cert-manager`
- **ArgoCD** (for GitOps deployments)

### MicroK8s Setup

```bash
# Enable required addons
microk8s enable dns ingress storage cert-manager

# Verify
microk8s status
```

## Quick Start

### 1. Create Secrets

Before deploying, create the required secrets:

```bash
# Create namespace
kubectl create namespace fundamental-dev

# PostgreSQL credentials
kubectl -n fundamental-dev create secret generic postgresql-credentials \
  --from-literal=postgres-password='<POSTGRES_ADMIN_PASSWORD>' \
  --from-literal=username='fundamental' \
  --from-literal=password='<POSTGRES_USER_PASSWORD>'

# Redis credentials
kubectl -n fundamental-dev create secret generic redis-credentials \
  --from-literal=redis-password='<REDIS_PASSWORD>'

# Backend secrets (JWT, API keys)
kubectl -n fundamental-dev create secret generic fundamental-backend-secrets \
  --from-literal=jwt-secret='<JWT_SECRET>' \
  --from-literal=api-key='<API_KEY>'

# Registry credentials (for pulling images)
kubectl -n fundamental-dev create secret docker-registry registry-credentials \
  --docker-server=registry.academind.ir \
  --docker-username='<USERNAME>' \
  --docker-password='<PASSWORD>'
```

### 2. Update Dependencies

```bash
cd charts/fundamental-stack
helm dependency update
```

### 3. Install (Development)

```bash
helm install fundamental . \
  -n fundamental-dev \
  -f values.yaml \
  -f values-dev.yaml
```

### 4. Install (Production)

```bash
helm install fundamental . \
  -n fundamental-prod \
  -f values.yaml \
  -f values-prod.yaml
```

### 5. Verify

```bash
# Check pods
kubectl -n fundamental-dev get pods

# Check ingress
kubectl -n fundamental-dev get ingress

# Check services
kubectl -n fundamental-dev get svc
```

## Configuration

### Values File Precedence

```text
values.yaml          ← Base defaults
values-dev.yaml      ← Development overrides
values-prod.yaml     ← Production overrides
```

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backend.replicaCount` | Number of backend replicas | `2` |
| `backend.image.tag` | Backend image tag | `""` (appVersion) |
| `backend.aspnetEnvironment` | ASP.NET environment | `Production` |
| `backend.resources.limits.memory` | Memory limit | `512Mi` |
| `frontend.replicaCount` | Number of frontend replicas | `2` |
| `ingress.hosts[0].host` | Primary domain | `academind.ir` |
| `postgresql.enabled` | Deploy PostgreSQL | `true` |
| `redis.enabled` | Deploy Redis | `true` |

### Using External Database

To use an external PostgreSQL instead of the bundled one:

```yaml
postgresql:
  enabled: false

externalDatabase:
  host: "external-postgres.example.com"
  port: 5432
  database: "fundamental"
  existingSecret: "external-db-credentials"
  existingSecretPasswordKey: "password"
```

## Security

### Pod Security Context (2025 Best Practices)

All pods run with:

```yaml
securityContext:
  runAsUser: 1000
  runAsGroup: 3000
  fsGroup: 2000
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
```

### Container Security Context

All containers run with:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  capabilities:
    drop:
      - ALL
```

### Network Policies

The chart deploys **default-deny** NetworkPolicies with explicit allows:

| Policy | From | To | Ports |
|--------|------|-----|-------|
| `allow-dns` | All pods | kube-system DNS | 53/UDP, 53/TCP |
| `allow-frontend` | Ingress | Frontend | 8080 |
| `allow-backend` | Ingress, Frontend | Backend | 8080 |
| `allow-postgresql` | Backend, Migrator | PostgreSQL | 5432 |
| `allow-redis` | Backend | Redis | 6379 |

### Secret Management

**Never commit secrets to Git!** Use the `existingSecret` pattern:

```yaml
postgresql:
  auth:
    existingSecret: "postgresql-credentials"
    secretKeys:
      adminPasswordKey: "postgres-password"
      userPasswordKey: "password"
```

Create secrets manually or use:
- **External Secrets Operator** (recommended)
- **Sealed Secrets**
- **HashiCorp Vault**

## Sentry Integration (Error Tracking & Monitoring)

The stack integrates with [Sentry](https://sentry.io) for error tracking, performance monitoring, and session replay.

### Prerequisites

1. A running Sentry instance (self-hosted at `sentry.academind.ir` or SaaS)
2. Create projects in Sentry:
   - **Backend**: Platform `.NET`
   - **Frontend**: Platform `Angular`
3. Get the DSN (Data Source Name) from each project's Settings → Client Keys

### Create Sentry Credentials Secret

```bash
# Replace with your actual DSNs from Sentry
BACKEND_DSN="https://<key>@sentry.academind.ir/1"
FRONTEND_DSN="https://<key>@sentry.academind.ir/2"

# Development namespace
kubectl -n fundamental-dev create secret generic sentry-credentials \
  --from-literal=dsn="$BACKEND_DSN" \
  --from-literal=frontend-dsn="$FRONTEND_DSN"

# Production namespace
kubectl -n fundamental-prod create secret generic sentry-credentials \
  --from-literal=dsn="$BACKEND_DSN" \
  --from-literal=frontend-dsn="$FRONTEND_DSN"
```

### Update DSN (Change Sentry Keys)

To update the DSN values after initial creation:

```bash
# Method 1: Delete and recreate
kubectl -n fundamental-dev delete secret sentry-credentials
kubectl -n fundamental-dev create secret generic sentry-credentials \
  --from-literal=dsn="https://NEW_KEY@sentry.academind.ir/1" \
  --from-literal=frontend-dsn="https://NEW_KEY@sentry.academind.ir/2"

# Method 2: Patch existing secret (base64 encoded)
NEW_DSN=$(echo -n "https://newkey@sentry.academind.ir/1" | base64)
kubectl -n fundamental-dev patch secret sentry-credentials \
  -p "{\"data\":{\"dsn\":\"$NEW_DSN\"}}"

# After updating, restart deployments to pick up changes
kubectl -n fundamental-dev rollout restart deployment -l app.kubernetes.io/component=backend
kubectl -n fundamental-dev rollout restart deployment -l app.kubernetes.io/component=frontend
```

### View in Kubernetes Dashboard

1. **Access the Dashboard**:
   ```bash
   # Enable dashboard addon
   microk8s enable dashboard
   
   # Get access token
   microk8s kubectl create token default -n kube-system
   
   # Access via port-forward
   microk8s kubectl port-forward -n kube-system service/kubernetes-dashboard 10443:443
   # Open: https://localhost:10443
   ```

2. **Navigate to Secrets**:
   - Select namespace: `fundamental-dev` or `fundamental-prod`
   - Click **Config and Storage** → **Secrets**
   - Click on `sentry-credentials`
   - Click the 👁️ eye icon to reveal values

3. **View Environment Variables**:
   - Go to **Workloads** → **Deployments**
   - Click on `fundamental-dev-fundamental-stack-backend`
   - Click on a pod → **Containers** tab
   - Scroll to **Environment Variables**

### Values Configuration

The DSN is injected via `values-dev.yaml` / `values-prod.yaml`:

```yaml
# Backend configuration
backend:
  env:
    - name: Sentry__Dsn
      valueFrom:
        secretKeyRef:
          name: sentry-credentials
          key: dsn
    - name: SENTRY_RELEASE
      value: "fundamental-backend@dev"

# Frontend configuration  
frontend:
  env:
    - name: SENTRY_DSN
      valueFrom:
        secretKeyRef:
          name: sentry-credentials
          key: frontend-dsn
    - name: SENTRY_RELEASE
      value: "fundamental-frontend@dev"
```

### Features Enabled

| Feature | Backend | Frontend |
|---------|---------|----------|
| Error Tracking | ✅ | ✅ |
| Performance Monitoring | ✅ | ✅ |
| Distributed Tracing | ✅ | ✅ |
| Session Replay | ❌ | ✅ |
| Profiling | ✅ | ❌ |

### Session Replay (Frontend Only)

Session Replay records user interactions as a video-like playback, showing exactly what the user did before an error occurred.

Configuration in `main.ts`:
```typescript
Sentry.replayIntegration({
  sessionSampleRate: 0.1,    // 10% of sessions
  errorSampleRate: 1.0,      // 100% of sessions with errors
})
```

## GitOps with ArgoCD

### Architecture

```text
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Backend CI/CD  │────▶│  Infra Repo     │────▶│    ArgoCD       │
│  (Build & Push) │     │  (update-tag)   │     │  (Sync & Deploy)│
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
    Push Image            Update values-*.yaml     Apply to K8s
```

### Triggering Deployments

After CI builds an image, trigger the update workflow:

```bash
gh api repos/YOUR_ORG/Fundamental.Infra/dispatches \
  --method POST \
  --field event_type=update-image-tag \
  --field "client_payload[component]=backend" \
  --field "client_payload[tag]=1.2.3" \
  --field "client_payload[environment]=prod"
```

### ArgoCD Applications

Apply the ArgoCD manifests:

```bash
# Create project
kubectl apply -f argocd/projects/fundamental.yaml

# Create dev application
kubectl apply -f argocd/applications/fundamental-dev.yaml

# Create prod application
kubectl apply -f argocd/applications/fundamental-prod.yaml
```

### ArgoCD Sync Commands

```bash
# Manual sync (production)
argocd app sync fundamental-prod

# Check status
argocd app get fundamental-dev

# Rollback
argocd app rollback fundamental-prod 1
```

## Troubleshooting

### Common Issues

#### 1. Pods stuck in `Pending`

```bash
kubectl -n fundamental-dev describe pod <pod-name>
# Check Events section for scheduling issues
```

#### 2. Image pull errors

```bash
# Verify registry secret
kubectl -n fundamental-dev get secret registry-credentials -o yaml

# Check pod events
kubectl -n fundamental-dev describe pod <pod-name> | grep -A 10 Events
```

#### 3. Database connection failed

```bash
# Check PostgreSQL pod
kubectl -n fundamental-dev logs -l app.kubernetes.io/name=postgresql

# Test connection
kubectl -n fundamental-dev exec -it deploy/fundamental-backend -- \
  sh -c 'nc -zv $DB_HOST 5432'
```

#### 4. Migration job failed

```bash
# Check migration job logs
kubectl -n fundamental-dev logs job/fundamental-migrator-<revision>

# List hooks
kubectl -n fundamental-dev get jobs -l helm.sh/hook=pre-install
```

### Debug Commands

```bash
# Helm debug
helm template fundamental . -f values-dev.yaml --debug

# Lint
helm lint .

# Get rendered manifests
helm get manifest fundamental -n fundamental-dev

# ArgoCD app diff
argocd app diff fundamental-dev
```

## For .NET Developers

### Mapping to .NET Concepts

| Kubernetes | .NET Equivalent |
|------------|-----------------|
| Deployment | IIS Application Pool |
| Service | DNS/Load Balancer |
| ConfigMap | appsettings.json |
| Secret | User Secrets / Key Vault |
| Ingress | Reverse Proxy (IIS ARR) |
| Helm Chart | Azure DevOps Release |
| ArgoCD | Azure DevOps Pipeline |

### Local Development

1. **Run locally**: Use `docker-compose` for local development
2. **Deploy to MicroK8s**: Use this Helm chart for staging
3. **Production**: ArgoCD syncs from Git

### Health Endpoints

The chart expects these ASP.NET health endpoints:

```csharp
// Program.cs
builder.Services.AddHealthChecks()
    .AddCheck("startup", () => HealthCheckResult.Healthy())
    .AddNpgSql(connectionString)
    .AddRedis(redisConnectionString);

app.MapHealthChecks("/health/startup", new HealthCheckOptions
{
    Predicate = check => check.Name == "startup"
});

app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false // Always healthy if app is running
});

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = _ => true // Check all dependencies
});
```

### Connection Strings

The chart injects connection strings as environment variables:

```csharp
// appsettings.json
{
  "ConnectionStrings": {
    "DefaultConnection": "" // Injected by K8s
  }
}

// Program.cs
var connectionString = Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection")
    ?? builder.Configuration.GetConnectionString("DefaultConnection");
```

## Testing

```bash
# Lint the chart
helm lint .

# Dry-run install
helm install fundamental . --dry-run -f values-dev.yaml

# Template output
helm template fundamental . -f values-dev.yaml > rendered.yaml

# Validate against K8s API
kubectl apply --dry-run=server -f rendered.yaml
```

## License

MIT
