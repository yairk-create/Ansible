---
description: Run an Ansible playbook with environment setup and vault unlock
---

## How to Unlock Vault and Run Playbooks

### Understanding the Vault System

This project uses **Vaultwarden** (self-hosted Bitwarden) to securely store credentials that Ansible needs to access your infrastructure (Proxmox nodes, TrueNAS, Zabbix API, etc.).

**Key Components:**
1. **`unlock_vault.sh`** - Script that unlocks Bitwarden and exports the session token
2. **Bitwarden CLI (`bw`)** - Command-line tool to access your Vaultwarden instance
3. **`BW_SESSION`** - Environment variable that Ansible lookups use to fetch credentials

### Automated Workflow (Recommended)

The `unlock_vault.sh` script automates the entire process:

```bash
export LC_ALL=C.utf8 && export LANG=C.utf8 && source unlock_vault.sh && ansible-playbook playbooks/[playbook_name].yml -i inventory/hosts.ini [options]
```

**What happens when you run this:**
1. Sets locale to prevent encoding issues
2. Activates Python virtual environment
3. Checks Bitwarden authentication status
4. If locked: Unlocks vault automatically using stored master password
5. Exports `BW_SESSION` environment variable
6. Runs your playbook with full access to vault credentials

### Example Usage

**Deploy NFS monitoring (check mode):**
```bash
export LC_ALL=C.utf8 && export LANG=C.utf8 && source unlock_vault.sh && ansible-playbook playbooks/zabbix.yml -i inventory/hosts.ini --check --diff
```

**Deploy for real:**
```bash
export LC_ALL=C.utf8 && export LANG=C.utf8 && source unlock_vault.sh && ansible-playbook playbooks/zabbix.yml -i inventory/hosts.ini
```

**For playbooks that don't need vault access:**
```bash
export LC_ALL=C.utf8 && export LANG=C.utf8 && source venv/bin/activate && ansible-playbook playbooks/scan_facts.yml -i inventory/hosts.ini
```

### Common Usage Patterns

**Quick run (turbo mode):**
```bash
source unlock_vault.sh && ansible-playbook playbooks/zabbix.yml -i inventory/hosts.ini
```

**With tags:**
```bash
source unlock_vault.sh && ansible-playbook playbooks/site.yml -i inventory/hosts.ini --tags configure
```

**Limit to specific hosts:**
```bash
source unlock_vault.sh && ansible-playbook playbooks/update_system.yml -i inventory/hosts.ini --limit node1,node2
```

### Troubleshooting

**Error: "Bitwarden Vault locked"**
- Solution: Run `source unlock_vault.sh` before your playbook command
- The script will automatically unlock the vault

**Error: "Bitwarden unauthenticated"**
- Solution: First-time setup required
- Run: `bw config server https://vaultwarden.nanunana.page/`
- Then: `bw login <your_email>`
- After that, `unlock_vault.sh` will work automatically

**Session expired:**
- Just re-run with `source unlock_vault.sh` - it will create a new session

### Security Notes

- The master password is stored in `unlock_vault.sh` (excluded from git via `.gitignore`)
- `BW_SESSION` token expires after inactivity - script handles re-unlocking automatically
- Never commit `unlock_vault.sh` to version control
- SSH keys are used for Ansible connections (no passwords transmitted)