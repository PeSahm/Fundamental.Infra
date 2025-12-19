# Ansible Configuration

This directory contains Ansible playbooks for zero-touch deployment of the Fundamental platform.

## Quick Start - Full Deployment

```bash
# 1. Install Ansible and collections
pip install ansible
ansible-galaxy collection install -r requirements.yml

# 2. Ensure SSH key is set up for VPS access
ssh-add ~/.ssh/your_key

# 3. Run full deployment (from scratch)
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/full-deploy.yaml
```

This will:
1. Setup VPS (Docker, MicroK8s, UFW)
2. Configure container registry
3. Setup cert-manager with Let's Encrypt
4. Create Kubernetes secrets
5. Install ArgoCD
6. Deploy applications via GitOps

## Directory Structure

```text
ansible/
├── inventory/          # Host inventory files
│   ├── hosts.ini       # Main inventory (VPS host)
│   ├── group_vars/     # Variables per group
│   │   └── all.yml     # Common variables
│   └── host_vars/      # Variables per host
│       └── vps-prod.yml # Production VPS variables
├── playbooks/          # Ansible playbooks
│   ├── full-deploy.yaml          # Complete deployment (runs all steps)
│   ├── setup-vps.yaml            # VPS infrastructure setup
│   ├── setup-registry-proxy.yaml # Container registry configuration
│   ├── setup-cert-manager.yaml   # TLS certificates (Let's Encrypt)
│   ├── setup-kubernetes-secrets.yaml # K8s secrets for apps
│   ├── setup-argocd.yaml         # ArgoCD installation
│   └── deploy-applications.yaml  # Application deployment
├── roles/              # Custom roles (future use)
├── files/              # Static files
├── templates/          # Jinja2 templates
├── .credentials/       # Generated credentials (gitignored)
├── ansible.cfg         # Ansible configuration
└── requirements.yml    # External collection dependencies
```

## Prerequisites

### On Linux (Ubuntu/Debian)

```bash
# Install Ansible
sudo apt update && sudo apt install -y ansible

# Or via pip (latest version)
pip install ansible

# Clone the repository
git clone https://github.com/PeSahm/Fundamental.Infra.git
cd Fundamental.Infra/ansible

# Install required collections
ansible-galaxy collection install -r requirements.yml

# Setup SSH key (copy your private key or generate new one)
# Ensure your public key is in the VPS's ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_rsa
chmod 700 ~/.ssh
```

### On macOS

```bash
# Install Ansible via Homebrew
brew install ansible

# Or via pip
pip install ansible

# Clone and setup
git clone https://github.com/PeSahm/Fundamental.Infra.git
cd Fundamental.Infra/ansible
ansible-galaxy collection install -r requirements.yml
```

### On Windows (via WSL)

```bash
# Open WSL terminal
wsl

# Install Ansible
sudo apt update && sudo apt install -y ansible

# Copy SSH key from Windows to WSL (one-time setup)
mkdir -p ~/.ssh
cp /mnt/c/Users/<YourUsername>/.ssh/id_rsa ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
chmod 700 ~/.ssh

# Navigate to ansible directory
cd /mnt/c/Repos/Personal/Fundamental/Fundamental.Infra/ansible

# Install required collections
ansible-galaxy collection install -r requirements.yml
```

## Usage

### 1. Verify SSH Connection

```bash
# Test connectivity to VPS
ansible all -i inventory/hosts.ini -m ping
```

Expected output:

```text
vps-prod | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### 2. Run VPS Setup Playbook

```bash
# Dry run (check mode) - see what would change
ansible-playbook -i inventory/hosts.ini playbooks/setup-vps.yaml --check

# Apply changes (takes 5-10 minutes)
ansible-playbook -i inventory/hosts.ini playbooks/setup-vps.yaml

# Verbose output for debugging
ansible-playbook -i inventory/hosts.ini playbooks/setup-vps.yaml -v
```

### 3. Run Tests After Setup

```bash
# Verify installation
ansible-playbook -i inventory/hosts.ini ../tests/ansible/test-setup-vps.yaml
```

## What Gets Installed

| Component | Details |
|-----------|---------|
| **Common Packages** | curl, wget, git, vim, htop, jq, etc. |
| **Docker** | Docker CE with compose plugin |
| **MicroK8s** | v1.28/stable with addons: dns, storage, registry, ingress |
| **UFW Firewall** | Ports 22 (SSH), 80 (HTTP), 443 (HTTPS), 16443 (K8s API), 18080 (OCR) |
| **Timezone** | Asia/Tehran |

## Quick Commands Reference

```bash
# From WSL, in the ansible directory:

# Test connection
ansible all -i inventory/hosts.ini -m ping

# Provision VPS (first time or updates)
ansible-playbook -i inventory/hosts.ini playbooks/setup-vps.yaml

# Run verification tests
ansible-playbook -i inventory/hosts.ini ../tests/ansible/test-setup-vps.yaml

# Check specific host facts
ansible vps-prod -i inventory/hosts.ini -m setup
```

## Troubleshooting

### SSH Permission Denied

```bash
# Ensure SSH key has correct permissions
chmod 600 ~/.ssh/id_rsa

# Test SSH manually
ssh root@5.10.248.55
```

### Ansible Not Found in WSL

```bash
sudo apt update && sudo apt install -y ansible
```

### World Writable Directory Warning

This warning appears when running from Windows paths in WSL. It's safe to ignore - the playbook still runs correctly.

## Security Notes

1. **SSH Keys**: Never commit SSH keys. Use `ssh-agent` or set up keys manually.
2. **Secrets**: Use `ansible-vault` for sensitive variables (not implemented yet).
3. **Firewall**: UFW is configured to block all ports except those explicitly allowed.

---

## Developer Guide: Ansible for .NET Developers

### What is Ansible?

Think of Ansible as **"Infrastructure as Code"** - similar to how you write C# to define application behavior, you write YAML to define server configuration. Instead of manually SSH-ing into servers and running commands, you declare the desired state and Ansible makes it happen.

| .NET Concept | Ansible Equivalent |
|--------------|-------------------|
| Solution (.sln) | Inventory (hosts.ini) |
| Project (.csproj) | Playbook (.yaml) |
| Class | Role |
| Method | Task |
| appsettings.json | group_vars / host_vars |
| NuGet packages | Ansible Collections |
| Dependency Injection | Variables & Templates |

### How Ansible Works

```text
┌─────────────────┐     SSH      ┌─────────────────┐
│  Control Node   │ ──────────►  │   Target VPS    │
│  (Your Machine) │              │  (5.10.248.55)  │
│                 │              │                 │
│  - Playbooks    │   Pushes     │  - Executes     │
│  - Inventory    │   Commands   │    tasks        │
│  - Variables    │              │  - Reports back │
└─────────────────┘              └─────────────────┘
```

1. **Agentless**: Unlike Chef/Puppet, no software needs to be installed on target servers - just SSH access
2. **Idempotent**: Running a playbook multiple times produces the same result (like `EnsureCreated()` in EF Core)
3. **Declarative**: You describe WHAT you want, not HOW to do it

### Anatomy of a Playbook

```yaml
# playbooks/setup-vps.yaml - Similar to a Program.cs

- name: Setup VPS Infrastructure          # Like: class SetupVps
  hosts: vps                              # Target servers (from inventory)
  become: true                            # Run as sudo (like elevation)

  tasks:                                  # Like: public void Configure()
    - name: Install packages              # Like: a method call
      ansible.builtin.apt:                # Module (like a NuGet package)
        name: "{{ common_packages }}"     # Variable (like IOptions<T>)
        state: present                    # Desired state
```

### Key Files Explained

| File | Purpose | .NET Analogy |
|------|---------|--------------|
| `ansible.cfg` | Global settings (timeouts, paths) | `appsettings.json` |
| `inventory/hosts.ini` | Server addresses & groups | Connection strings |
| `inventory/group_vars/all.yml` | Variables for ALL servers | Shared config |
| `inventory/host_vars/vps-prod.yml` | Variables for ONE server | Environment-specific config |
| `playbooks/*.yaml` | What to execute | Controllers/Services |
| `roles/` | Reusable task bundles | Class libraries |
| `requirements.yml` | External dependencies | `packages.config` / NuGet refs |

### Common Modifications

#### 1. Add a New Firewall Port

Edit `inventory/group_vars/all.yml`:

```yaml
ufw_allowed_ports:
  - { port: 22, proto: tcp, comment: "SSH" }
  - { port: 80, proto: tcp, comment: "HTTP" }
  - { port: 443, proto: tcp, comment: "HTTPS" }
  - { port: 5000, proto: tcp, comment: "My .NET API" }  # ← Add this
```

#### 2. Add a New Package to Install

Edit `inventory/group_vars/all.yml`:

```yaml
common_packages:
  - curl
  - wget
  - git
  - dotnet-sdk-8.0    # ← Add .NET SDK
```

#### 3. Add a New Task to the Playbook

Edit `playbooks/setup-vps.yaml` and add a task:

```yaml
tasks:
  # ... existing tasks ...

  - name: Create application directory
    ansible.builtin.file:
      path: /opt/myapp
      state: directory
      mode: '0755'
```

#### 4. Add a New Server

Edit `inventory/hosts.ini`:

```ini
[vps]
vps-prod ansible_host=5.10.248.55
vps-staging ansible_host=10.0.0.50      # ← Add new server

[all:vars]
ansible_user=root
```

Then create `inventory/host_vars/vps-staging.yml` for server-specific settings.

#### 5. Create a Reusable Role

Roles are like class libraries - reusable across playbooks:

```bash
# Create role structure
mkdir -p roles/dotnet-app/{tasks,templates,defaults}
```

```yaml
# roles/dotnet-app/tasks/main.yml
---
- name: Install .NET runtime
  ansible.builtin.apt:
    name: aspnetcore-runtime-8.0
    state: present

- name: Copy application
  ansible.builtin.copy:
    src: "{{ app_artifact_path }}"
    dest: /opt/{{ app_name }}/
```

```yaml
# roles/dotnet-app/defaults/main.yml (default variables)
---
app_name: myapp
app_artifact_path: ./publish/
```

Use in playbook:

```yaml
- name: Deploy .NET Application
  hosts: vps
  roles:
    - role: dotnet-app
      vars:
        app_name: my-api
```

### Useful Ansible Modules for .NET Developers

| Module | Purpose | Example Use |
|--------|---------|-------------|
| `apt` | Install packages | Install .NET SDK, nginx |
| `copy` | Copy files to server | Deploy compiled DLLs |
| `template` | Copy with variable substitution | Generate appsettings.Production.json |
| `systemd` | Manage services | Start/stop your .NET app |
| `docker_container` | Run containers | Deploy containerized apps |
| `git` | Clone repositories | Pull source code |
| `command` / `shell` | Run any command | `dotnet build`, `dotnet publish` |
| `file` | Create directories/symlinks | App folders, log directories |
| `lineinfile` | Edit config files | Modify environment variables |

### Variable Precedence (Lowest to Highest)

Understanding this helps avoid "why isn't my variable working?" issues:

```text
1. role/defaults/main.yml     (lowest priority - defaults)
2. inventory/group_vars/all.yml
3. inventory/group_vars/<group>.yml
4. inventory/host_vars/<host>.yml
5. playbook vars:
6. command line: -e "var=value" (highest priority)
```

### Development Workflow

```bash
# 1. Make changes to playbooks/variables
code ansible/

# 2. Test syntax (like dotnet build)
ansible-playbook playbooks/setup-vps.yaml --syntax-check

# 3. Dry run - see what WOULD change (like a database migration preview)
ansible-playbook -i inventory/hosts.ini playbooks/setup-vps.yaml --check --diff

# 4. Apply to one host first (like deploying to staging)
ansible-playbook -i inventory/hosts.ini playbooks/setup-vps.yaml --limit vps-prod

# 5. Full deployment
ansible-playbook -i inventory/hosts.ini playbooks/setup-vps.yaml
```

### Debugging Tips

```bash
# Verbose output (like -v in dotnet)
ansible-playbook playbooks/setup-vps.yaml -v    # basic
ansible-playbook playbooks/setup-vps.yaml -vvv  # very verbose

# Debug a specific variable
- name: Debug variable
  ansible.builtin.debug:
    var: common_packages

# Run a single task by tag
ansible-playbook playbooks/setup-vps.yaml --tags "docker"

# Skip specific tags
ansible-playbook playbooks/setup-vps.yaml --skip-tags "microk8s"
```

## Sentry Self-Hosted Deployment

Deploy Sentry error tracking and performance monitoring for both backend and frontend applications.

### Prerequisites

- MicroK8s cluster running
- cert-manager configured
- DNS record for `sentry.academind.ir`

### Deploy Sentry

```bash
# Deploy Sentry (from ansible directory)
ansible-playbook -i inventory/hosts.ini playbooks/setup-sentry.yaml
```

This will:
1. Create `sentry` namespace
2. Generate and store credentials
3. Deploy infrastructure (PostgreSQL, Redis, Kafka, ClickHouse, Zookeeper)
4. Deploy Sentry services (Web, Worker, Cron, Relay, Snuba, Symbolicator, Vroom)
5. Run database migrations
6. Create admin user
7. Configure ingress for `sentry.academind.ir`

### Sentry Components

| Component | Purpose | Resources |
|-----------|---------|-----------|
| PostgreSQL | Primary database | 1Gi RAM, 20Gi disk |
| Redis | Caching & queues | 512Mi RAM, 5Gi disk |
| Kafka | Message streaming | 1Gi RAM, 10Gi disk |
| ClickHouse | Analytics storage | 1Gi RAM, 20Gi disk |
| Zookeeper | Kafka coordination | 512Mi RAM, 5Gi disk |
| Sentry Web | Main UI & API | 1Gi RAM |
| Sentry Worker | Background jobs | 1Gi RAM |
| Sentry Cron | Scheduled tasks | 512Mi RAM |
| Sentry Relay | Event ingestion | 512Mi RAM |
| Snuba | Query service | 512Mi RAM |
| Symbolicator | Source maps processing | 1Gi RAM, 10Gi disk |
| Vroom | Session replay & profiling | 512Mi RAM |

### Post-Deployment Setup

After deployment, complete the following manual steps:

#### 1. Access Sentry UI
- URL: https://sentry.academind.ir
- Get credentials: `ssh root@5.10.248.55 "cat /root/.sentry-credentials"`

#### 2. First Login
1. Login with admin credentials
2. If you see "Unable to load configuration" - wait 30 seconds and refresh
3. Complete the onboarding wizard

#### 3. Create Projects
1. Go to **Settings → Projects → Create Project**
2. Create **dotnet-backend**:
   - Platform: .NET
   - Project Name: dotnet-backend
3. Create **angular-frontend**:
   - Platform: JavaScript / Angular
   - Project Name: angular-frontend

#### 4. Get DSN Values
1. Go to **Settings → Projects → [project] → Client Keys (DSN)**
2. Copy the DSN for each project
3. DSN format: `https://[key]@sentry.academind.ir/[project-id]`

#### 5. Create Auth Token (for source maps)
1. Go to **Settings → Auth Tokens**
2. Create new token with scopes:
   - `project:releases`
   - `org:read`
3. Copy the token for CI/CD

#### 6. Add GitHub Secrets
Add these secrets to Fundamental.Backend and Fundamental.FrontEnd repos:
```
SENTRY_DSN          = Backend DSN
SENTRY_DSN_FRONTEND = Frontend DSN  
SENTRY_AUTH_TOKEN   = Auth token for source maps
SENTRY_ORG          = sentry (default org name)
SENTRY_PROJECT_BACKEND  = dotnet-backend
SENTRY_PROJECT_FRONTEND = angular-frontend
```

#### 7. Configure CSRF (if needed)
If you get CSRF errors, add your domain to the config:
```bash
# SSH to VPS and edit configmap
ssh root@5.10.248.55
microk8s kubectl edit configmap sentry-config -n sentry
# Add to sentry.conf.py:
# CSRF_TRUSTED_ORIGINS = ["https://sentry.academind.ir"]
```

### Verify Deployment

```bash
# Check pods
ssh root@5.10.248.55 "microk8s kubectl get pods -n sentry"

# Check services
ssh root@5.10.248.55 "microk8s kubectl get svc -n sentry"

# Check ingress
ssh root@5.10.248.55 "microk8s kubectl get ingress -n sentry"

# View credentials
ssh root@5.10.248.55 "cat /root/.sentry-credentials"
```

### Troubleshooting

```bash
# Check migration job logs
ssh root@5.10.248.55 "microk8s kubectl logs -n sentry job/sentry-init-migrations"

# Check web pod logs
ssh root@5.10.248.55 "microk8s kubectl logs -n sentry deployment/sentry-web"

# Restart deployment
ssh root@5.10.248.55 "microk8s kubectl rollout restart -n sentry deployment/sentry-web"
```

### Best Practices

1. **Idempotency**: Tasks should be safe to run multiple times
2. **Use Variables**: Never hardcode values that might change
3. **Name Everything**: Every task should have a descriptive `name:`
4. **Test with --check**: Always dry-run before applying
5. **Version Control**: All ansible code should be in Git
6. **Secrets Management**: Use `ansible-vault` for passwords/keys (future)

### Learning Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible for DevOps (Book)](https://www.ansiblefordevops.com/)
- [Ansible Galaxy](https://galaxy.ansible.com/) - Community roles (like NuGet.org)
- [Sentry Self-Hosted Documentation](https://develop.sentry.dev/self-hosted/)
