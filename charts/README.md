# Helm Charts

This directory contains Helm charts for deploying the Fundamental application stack.

## Directory Structure

```text
charts/
└── fundamental-stack/          # Main umbrella chart
    ├── Chart.yaml              # Chart metadata & dependencies
    ├── Chart.lock              # Locked dependency versions
    ├── values.yaml             # Default values
    ├── values-dev.yaml         # Development environment
    ├── values-prod.yaml        # Production environment
    └── templates/
        ├── _helpers.tpl        # Template helpers
        ├── backend/
        │   ├── deployment.yaml
        │   └── service.yaml
        ├── frontend/
        │   ├── deployment.yaml
        │   └── service.yaml
        ├── ingress.yaml        # Ingress with routing
        ├── secrets.yaml        # Secret references
        └── hooks/
            └── migrator-job.yaml  # Database migration job
```

## Dependencies

- **PostgreSQL**: Bitnami PostgreSQL chart
- **Redis**: Bitnami Redis chart

## Usage

### Install Dependencies

```bash
cd charts/fundamental-stack
helm dependency update
```

### Install Chart

```bash
# Development
helm install fundamental ./charts/fundamental-stack -f ./charts/fundamental-stack/values-dev.yaml

# Production
helm install fundamental ./charts/fundamental-stack -f ./charts/fundamental-stack/values-prod.yaml
```

### Upgrade

```bash
helm upgrade fundamental ./charts/fundamental-stack -f ./charts/fundamental-stack/values-prod.yaml
```

## Testing

```bash
# Lint
helm lint ./charts/fundamental-stack

# Template (dry-run)
helm template fundamental ./charts/fundamental-stack -f ./charts/fundamental-stack/values-dev.yaml

# Test after install
helm test fundamental
```
