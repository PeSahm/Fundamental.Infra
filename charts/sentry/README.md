# Sentry Self-Hosted Setup

This directory contains the configuration and deployment files for self-hosted Sentry, a comprehensive error tracking and performance monitoring solution.

## Features

- **Error Tracking**: Capture and aggregate errors from backend and frontend
- **Performance Monitoring**: Track transaction performance and identify bottlenecks
- **Session Replay**: Record and replay user sessions for debugging
- **Source Maps**: JavaScript source map support for Angular
- **Debug Symbols**: .NET PDB support for stack trace deobfuscation
- **GitHub Integration**: Link commits, releases, and issues
- **Alerts**: Configurable alerting for error thresholds

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Sentry Self-Hosted                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────────────────┐ │
│  │  Relay  │───│   Web   │───│ Worker  │───│       Cron          │ │
│  └────┬────┘   └────┬────┘   └────┬────┘   └─────────────────────┘ │
│       │             │             │                                 │
│  ┌────┴────────────┴─────────────┴─────────────────────────────┐   │
│  │                      Message Queue (Kafka)                    │   │
│  └────┬────────────────────────────────────────────────────────┘   │
│       │                                                             │
│  ┌────┴────┐   ┌──────────┐   ┌──────────────┐   ┌─────────────┐   │
│  │  Snuba  │───│ClickHouse│   │  PostgreSQL  │   │    Redis    │   │
│  └─────────┘   └──────────┘   └──────────────┘   └─────────────┘   │
│                                                                     │
│  ┌─────────────────┐   ┌───────────────────────────────────────┐   │
│  │   Symbolicator  │   │     Vroom (Replay & Profiling)        │   │
│  └─────────────────┘   └───────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Purpose | Port |
|-----------|---------|------|
| **Relay** | Event ingestion, rate limiting | 3000 |
| **Web** | Django web application | 9000 |
| **Worker** | Async task processing | - |
| **Cron** | Scheduled tasks | - |
| **Snuba** | Query service for analytics | 1218 |
| **Symbolicator** | Source map & debug symbol processing | 3021 |
| **Vroom** | Session replay & profiling | 8085 |
| **PostgreSQL** | Primary database | 5432 |
| **Redis** | Cache & message broker | 6379 |
| **Kafka** | Event streaming | 9092 |
| **ClickHouse** | Analytics database | 8123, 9000 |
| **Zookeeper** | Kafka coordination | 2181 |

## Deployment

### Prerequisites

1. MicroK8s cluster with:
   - `dns` addon enabled
   - `storage` addon enabled
   - `ingress` addon enabled

2. At least 8GB RAM and 4 CPU cores available

3. DNS record for `sentry.academind.ir` pointing to VPS

### Deploy with Ansible

```bash
cd Fundamental.Infra/ansible

# Deploy Sentry
ansible-playbook playbooks/setup-sentry.yaml -i inventory/hosts.ini

# Check credentials
ssh root@5.10.248.55 'cat /root/.sentry-credentials'
```

### Manual DNS Setup (if not using Terragrunt)

Add to Cloudflare:
- `sentry.academind.ir` → VPS IP (proxied)

## Post-Deployment Setup

### 1. Login to Sentry

Navigate to `https://sentry.academind.ir` and login with the admin credentials from `/root/.sentry-credentials`.

### 2. Create Organization

1. Go to Settings → Organizations
2. Create organization: `fundamental`

### 3. Create Projects

Create two projects:

**Backend Project:**
- Name: `dotnet-backend`
- Platform: .NET / ASP.NET Core
- Copy DSN for configuration

**Frontend Project:**
- Name: `angular-frontend`
- Platform: JavaScript / Angular
- Copy DSN for configuration

### 4. Setup GitHub Integration

1. Go to Settings → Integrations → GitHub
2. Install Sentry GitHub App
3. Configure repository access for:
   - `PeSahm/Fundamental.Backend`
   - `PeSahm/Fundamental.FrontEnd`

### 5. Create Auth Token

1. Go to Settings → Auth Tokens
2. Create new token with scopes:
   - `project:releases`
   - `org:read`
3. Add token to GitHub secrets as `SENTRY_AUTH_TOKEN`

### 6. Configure DSN in Applications

**Backend (Kubernetes Secret):**

```bash
# Create secret with DSN
kubectl create secret generic sentry-credentials \
  --namespace fundamental-dev \
  --from-literal=dsn='https://xxx@sentry.academind.ir/1'
```

**Frontend (GitHub Secret):**

Add `SENTRY_DSN` to repository secrets.

## Integration Details

### Backend (.NET)

The backend uses these Sentry packages:
- `Sentry.AspNetCore` - ASP.NET Core integration
- `Sentry.Serilog` - Serilog sink
- `Sentry.Profiling` - Performance profiling

Configuration in `appsettings.json`:
```json
{
  "Sentry": {
    "Dsn": "https://xxx@sentry.academind.ir/1"
  }
}
```

### Frontend (Angular)

The frontend uses:
- `@sentry/angular-ivy` - Angular integration
- Session Replay for debugging
- Browser tracing for performance

Configuration in `environment.prod.ts`:
```typescript
export const environment = {
  sentry: {
    dsn: 'https://xxx@sentry.academind.ir/2',
    release: 'fundamental-frontend@version'
  }
}
```

## Source Maps Upload

Source maps are automatically uploaded during CI/CD:

### Angular (Frontend)

```yaml
# In .github/workflows/ci-cd.yaml
- name: Upload Source Maps to Sentry
  run: |
    npx sentry-cli releases new $RELEASE
    npx sentry-cli releases files $RELEASE upload-sourcemaps ./dist
    npx sentry-cli releases finalize $RELEASE
```

### .NET (Backend)

.NET uses PDB files which are embedded in the Docker image. Sentry automatically downloads symbols from Microsoft Symbol Server for framework assemblies.

## Alerts Configuration

Recommended alerts to configure:

1. **Error Rate Alert**: Trigger when error rate exceeds 5% of transactions
2. **New Issue Alert**: Notify on first occurrence of new issues
3. **Regression Alert**: Notify when resolved issues reoccur
4. **Performance Alert**: Trigger on P95 latency > 2s

## Maintenance

### Backup PostgreSQL

```bash
kubectl exec -n sentry deploy/sentry-postgres -- \
  pg_dump -U sentry sentry > sentry-backup.sql
```

### Clear Old Data

Configure data retention in Sentry settings:
- Events: 90 days
- Members: Unlimited
- Attachments: 30 days

### Upgrade Sentry

1. Update `sentry_version` in Ansible vars
2. Run playbook with `--tags upgrade`
3. Run migrations manually if needed

## Troubleshooting

### Events Not Appearing

1. Check Relay logs: `kubectl logs -n sentry deploy/sentry-relay`
2. Verify DSN is correct
3. Check network connectivity from app to Sentry

### Source Maps Not Working

1. Verify source maps are uploaded: `sentry-cli releases files <release> list`
2. Check release version matches what's deployed
3. Ensure source maps have correct paths

### High Memory Usage

1. Scale down replicas
2. Adjust ClickHouse memory limits
3. Enable data retention policies

## Resources

- [Sentry Self-Hosted Documentation](https://develop.sentry.dev/self-hosted/)
- [Sentry .NET SDK](https://docs.sentry.io/platforms/dotnet/)
- [Sentry Angular SDK](https://docs.sentry.io/platforms/javascript/guides/angular/)
- [Sentry CLI](https://docs.sentry.io/product/cli/)
