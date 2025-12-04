# Fundamental.Infra

Infrastructure as Code repository for the Fundamental application stack. This repository follows GitOps principles and manages:

- **Meta-Infrastructure** (Terraform/Terragrunt) - DNS & GitHub configuration
- **Infrastructure Provisioning** (Ansible)
- **Kubernetes Manifests** (Helm)
- **GitOps Automation** (ArgoCD)
- **CI/CD Pipelines** (GitHub Actions)
- **Local Development** (Tilt)

## 📁 Repository Structure

```text
Fundamental.Infra/
├── infrastructure/             # Meta-Infrastructure (Terraform/Terragrunt)
│   ├── modules/                # Reusable Terraform modules
│   │   ├── cloudflare-dns/     # DNS record management
│   │   └── github-config/      # GitHub repos, environments & secrets
│   └── live/                   # Terragrunt "live" configurations
│       ├── terragrunt.hcl      # Root config (global vars: VPS_IP, etc.)
│       ├── development/        # Dev environment (dev.*, dev-api.*)
│       │   ├── dns/            # Dev DNS records
│       │   └── github/         # Dev GitHub config
│       └── production/         # Prod environment (@, www, api, argocd)
│           ├── dns/            # Prod DNS records
│           └── github/         # Prod GitHub config
│
├── ansible/                    # Infrastructure provisioning
│   ├── inventory/              # Host inventory files
│   ├── playbooks/              # Ansible playbooks
│   ├── roles/                  # Custom Ansible roles
│   ├── group_vars/             # Group-level variables
│   ├── host_vars/              # Host-specific variables
│   ├── files/                  # Static files to copy
│   ├── templates/              # Jinja2 templates
│   ├── ansible.cfg             # Ansible configuration
│   └── requirements.yml        # External role dependencies

│
├── charts/                     # Helm charts
│   └── fundamental-stack/      # Main application chart
│       ├── templates/          # Kubernetes manifest templates
│       ├── Chart.yaml          # Chart metadata & dependencies
│       ├── values.yaml         # Default values
│       ├── values-dev.yaml     # Development overrides
│       └── values-prod.yaml    # Production overrides
│
├── argocd/                     # ArgoCD configuration
│   ├── applications/           # Application manifests
│   └── projects/               # Project definitions
│
├── environments/               # Environment-specific configs
│   ├── dev/                    # Development environment
│   └── prod/                   # Production environment
│
├── .github/                    # GitHub configuration
│   └── workflows/              # GitHub Actions workflows
│
├── scripts/                    # Utility scripts
├── docs/                       # Documentation
├── tests/                      # Test suites
│   ├── ansible/                # Ansible tests (Molecule)
│   ├── helm/                   # Helm tests & linting
│   └── integration/            # Integration tests
│
└── Tiltfile                    # Local development with Tilt
```

## 🎯 Target Infrastructure

| Component | Technology |
|-----------|------------|
| Server | VPS at `5.10.248.55` |
| Domain | `academind.ir` (Cloudflare) |
| Kubernetes | MicroK8s |
| Container Runtime | Docker |
| Ingress | MicroK8s Ingress (NGINX) |
| Storage | MicroK8s hostpath-storage |
| Registry | MicroK8s built-in registry |

## 🚀 Quick Start

### Prerequisites

- Terraform >= 1.5.0
- Terragrunt >= 0.54.0
- Ansible 2.15+
- Helm 3.12+
- kubectl
- Access to VPS via SSH

### 0. Configure Meta-Infrastructure (Terraform)

```bash
# Set up environment variables
cd infrastructure
cp .env.example .env
# Edit .env with your actual tokens

# Apply DNS and GitHub configuration
source .env
cd live/production
terragrunt run-all plan    # Review changes
terragrunt run-all apply   # Apply changes
```

### 1. Provision Infrastructure

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/setup-vps.yaml
```

### 2. Deploy with ArgoCD

ArgoCD will automatically sync changes from this repository.

### 3. Local Development

```bash
# Ensure sibling repos exist
# ../Fundamental.Backend
# ../Fundamental.FrontEnd

tilt up
```

## 🔐 Security Notes

- **Secrets**: Never commit secrets. Use Kubernetes Secrets created manually or sealed-secrets.
- **SSH Keys**: Stored locally, never in repository.
- **Basic Auth**: Credentials stored as K8s secrets, referenced in Ingress.

## 📚 Documentation

- [Terraform/Terragrunt Guide](infrastructure/README.md)
- [Ansible Setup Guide](docs/ansible.md)
- [Helm Chart Documentation](docs/helm.md)
- [ArgoCD Configuration](docs/argocd.md)
- [Local Development](docs/local-dev.md)

## 🔗 Related Repositories

- [Fundamental.Backend](https://github.com/PeSahm/Fundamental.Backend)
- [Fundamental.FrontEnd](https://github.com/PeSahm/Fundamental.FrontEnd)

## License

See [LICENSE](LICENSE) for details.
