# Ansible Configuration

This directory contains Ansible playbooks and roles for provisioning and configuring the VPS infrastructure.

## Directory Structure

```text
ansible/
├── inventory/          # Host inventory files
│   └── hosts.ini       # Main inventory (dev/prod hosts)
├── playbooks/          # Ansible playbooks
│   └── setup-vps.yaml  # Main VPS provisioning playbook
├── roles/              # Custom roles
│   └── microk8s/       # MicroK8s installation role
├── group_vars/         # Variables per group
│   ├── all.yml         # Common variables
│   └── vps.yml         # VPS-specific variables
├── host_vars/          # Variables per host
│   └── vps-prod.yml    # Production VPS variables
├── files/              # Static files
├── templates/          # Jinja2 templates
├── ansible.cfg         # Ansible configuration
└── requirements.yml    # External role dependencies
```

## Usage

### Install Dependencies

```bash
ansible-galaxy install -r requirements.yml
```

### Run Playbook

```bash
# Dry run (check mode)
ansible-playbook -i inventory/hosts.ini playbooks/setup-vps.yaml --check

# Apply changes
ansible-playbook -i inventory/hosts.ini playbooks/setup-vps.yaml
```

### Verify Connection

```bash
ansible all -i inventory/hosts.ini -m ping
```

## Security Considerations

1. **SSH Keys**: Use key-based authentication only
2. **Vault**: Use `ansible-vault` for sensitive variables
3. **UFW**: Firewall configured to allow only ports 22, 80, 443, 16443
