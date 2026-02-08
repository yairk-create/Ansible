# Ansible Automation Repository

This repository contains Ansible playbooks and configurations for managing infrastructure.

## Structure

```
.
├── playbooks/          # Ansible playbooks
├── inventory/          # Inventory files
│   ├── hosts.ini      # Static inventory
│   └── group_vars/    # Group variables
├── agents.md          # Best practices guide
└── setup.sh           # Environment setup script
```

## Quick Start

1. **Setup Environment:**
   ```bash
   ./setup.sh
   source venv/bin/activate
   ```

2. **Configure Vaultwarden:**
   ```bash
   source unlock_vault.sh
   ```

3. **Run Playbooks:**
   ```bash
   ansible-playbook -i inventory/hosts.ini playbooks/site.yml
   ```

## Playbooks

- [debug_vault.yml](playbooks/debug_vault_README.md)
- [site.yml](playbooks/site_README.md)
- [verify_connectivity.yml](playbooks/verify_connectivity_README.md)
