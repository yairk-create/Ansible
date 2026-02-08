---
description: Perform various scans of the devices and infrastructure
---
# Scan All Devices Workflow

This workflow automates the process of scanning your environment using the defined Ansible playbooks.

## Prerequisites
- Ensure you have activated the environment: `source venv/bin/activate`
- If running Proxmox scans, ensure your vault is unlocked: `source unlock_vault.sh`

## Available Scan Commands

### 1. Scan Inventory Facts
Gathers details (OS, IP, Specs) for all hosts defined in your inventory.
// turbo
```bash
LC_ALL=C.UTF-8 LANG=C.UTF-8 ./venv/bin/ansible-playbook -i inventory/hosts.ini playbooks/scan_facts.yml
```

### 2. Scan Proxmox Guests
Lists all VMs and Containers on your PVE nodes.
// turbo
```bash
LC_ALL=C.UTF-8 LANG=C.UTF-8 ./venv/bin/ansible-playbook -i inventory/hosts.ini playbooks/scan_proxmox.yml
```

### 3. Scan Network Discovery
Discovers active devices on the 192.168.1.0/24 subnet.
// turbo
```bash
LC_ALL=C.UTF-8 LANG=C.UTF-8 ./venv/bin/ansible-playbook playbooks/scan_network.yml
```

### 4. Run All Scans
Executes all the above scans in sequence.
// turbo
```bash
LC_ALL=C.UTF-8 LANG=C.UTF-8 ./venv/bin/ansible-playbook -i inventory/hosts.ini playbooks/scan_facts.yml && \
LC_ALL=C.UTF-8 LANG=C.UTF-8 ./venv/bin/ansible-playbook -i inventory/hosts.ini playbooks/scan_proxmox.yml && \
LC_ALL=C.UTF-8 LANG=C.UTF-8 ./venv/bin/ansible-playbook playbooks/scan_network.yml
```
