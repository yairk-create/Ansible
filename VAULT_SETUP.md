# Vaultwarden Configuration Guide

To fully enable the "Passwordless" setup where Ansible fetches credentials from the vault, you must create the following items in your Vaultwarden (Bitwarden) using the web vault or CLI:

## Required Vault Items

### 1. Item Name: `proxmox_root`
- **Type:** Login
- **Username:** `root`
- **Password:** `L0cal1t8`
- **URI:** `192.168.1.240` (Optional, for your reference)
- **Description:** Root credentials for Proxmox Cluster

### 2. Item Name: `linux_guest_creds` (Optional, for future VMs)
- **Type:** Login
- **Username:** `ansible_user`
- **Password:** `<your-vm-password>`

## How it works
Ansible will look for an item with the **exact name** `proxmox_root` and extract the `password` field to use as `ansible_password` during connection.

## Verification
After creating the item in the Vault, run:
```bash
source venv/bin/activate
source unlock_vault.sh
ANSIBLE_HOST_KEY_CHECKING=False ansible -i inventory/hosts.ini proxmox_nodes -m ping
```
