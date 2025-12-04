# Ansible Configuration

This directory contains Ansible playbooks and roles for provisioning and configuring the VPS infrastructure.

## Directory Structure

```text
ansible/
├── inventory/          # Host inventory files
│   └── hosts.ini       # Main inventory (VPS host)
├── playbooks/          # Ansible playbooks
│   └── setup-vps.yaml  # Main VPS provisioning playbook
├── roles/              # Custom roles (future use)
├── group_vars/         # Variables per group
│   └── all.yml         # Common variables
├── host_vars/          # Variables per host
│   └── vps-prod.yml    # Production VPS variables
├── files/              # Static files
├── templates/          # Jinja2 templates
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
