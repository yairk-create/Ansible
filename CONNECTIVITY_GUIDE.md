# Connectivity Guide & Quick Start

## Quick Start (Please Read Carefully)

### 1. Authenticate with Vaultwarden (One-Time Setup)

The Bitwarden CLI (`bw`) is installed but **requires logging in** with your email first.

1.  **Run Login Command:**
    ```bash
    source venv/bin/activate
    bw login <your-email>
    ```
    *(When prompted for Master Password, use: `Fi$gBW1g^1I1Cr`)*

2.  **Unlock the Vault:**
    Once logged in, run our helper script to unlock the vault and export the session for the current terminal:
    ```bash
    source unlock_vault.sh
    ```

### 2. Verify Connectivity to Proxmox

We have pre-configured the inventory with `root` user and `L0cal1t8` password.
Since this is the first connection, you may need to disable strict host key checking temporarily:

**Run Connectivity Check:**
```bash
# This disables host key checking for the first run to accept the server key
ANSIBLE_HOST_KEY_CHECKING=False ansible -i inventory/hosts.ini proxmox_nodes -m ping
```

**Expected Output:**
```json
pve1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### 3. Run the Full Playbook

Once connectivity is verified and the vault is unlocked:

```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory/hosts.ini playbooks/site.yml
```

---

## Troubleshooting Checklist

### 1. Network & SSH Access
- **Target:** `192.168.1.240`
- **User:** `root`
- **Password:** `L0cal1t8`
- **Config:** `inventory/hosts.ini` has been updated.

### 2. Bitwarden Status
If `source unlock_vault.sh` says "unauthenticated", you MUST run `bw login <email>` first.
This step cannot be automated without your email address.

### 3. Ansible Environment
Ensure you always activate the environment before running commands:
```bash
source venv/bin/activate
```
