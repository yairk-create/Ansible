# 🚀 Proxmox & Linux Automation with Ansible

![Ansible](https://img.shields.io/badge/Ansible-E03237?style=for-the-badge&logo=ansible&logoColor=white)
![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=for-the-badge&logo=proxmox&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Security](https://img.shields.io/badge/Security-Vaultwarden-blue?style=for-the-badge&logo=bitwarden)

Efficient, secure, and automated management for your Proxmox cluster and Linux environment. This repository houses specialized Ansible playbooks designed for high-availability home-lab and infrastructure orchestration.

---

## 🌟 Key Features

- **🛡️ Secure Secret Management**: Native integration with **Vaultwarden (Bitwarden)** ensures no plain-text passwords ever touch your disk.
- **🔍 Device Scanning**: New playbooks for network discovery, Proxmox guest enumeration, and host fact gathering.
- **🖥️ Proxmox Orchestration**: Automated updates and configuration for Proxmox VE nodes.
- **🐧 Linux Hardening**: Base configuration for Linux guests including SSH hardening, package management, and basic security tools.
- **🤖 Agent Workflows**: Built-in `/scan` and `/commit` commands to automate infrastructure management and documentation.
- **🚀 One-Click Setup**: Streamlined environment preparation script.

---

## 📂 Project Structure

```text
.
├── 📂 .agent/             # Custom agent workflows (/scan, /commit)
├── 📂 playbooks/          # Production-ready Ansible playbooks
├── 📂 inventory/          # Infrastructure topology definition
│   ├── hosts.ini         # Main inventory file
│   └── 📂 group_vars/     # Encrypted-at-rest variables via Vaultwarden lookup
├── 📜 agents.md           # Security & Best Practices policy
├── 📜 CONNECTIVITY_GUIDE.md # Detailed troubleshooting guide
├── 📜 setup.sh            # Automated dependency installer
└── 📜 generate_docs.py    # Documentation & Git sync agent
```

---

## 🛠️ Getting Started

### 1. Prerequisites
- Linux Control Node (Ubuntu/Debian recommended)
- SSH access to target nodes
- Access to your Vaultwarden instance

### 2. Environment Setup
Clone the repo and run the automated setup:
```bash
./setup.sh
source venv/bin/activate
```

### 3. Bitwarden Authentication
Configure and unlock your secret vault:
```bash
# Configure your Vaultwarden URL
bw config server https://vaultwarden.nanunana.page/

# Login and Unlock
source unlock_vault.sh
```

---

## 🔐 Security Integration

This project uses the `community.general.bitwarden` lookup plugin. To use it, ensure you have an item named `proxmox_root` in your vault with the correct credentials.

**Connectivity Logic:**
Passwords are fetched on-the-fly and never stored in the clear. Use the provided `unlock_vault.sh` to maintain a secure session in your terminal.

---

## 🚀 Active Playbooks

- [debug_vault.yml](playbooks/debug_vault_README.md)
- [site.yml](playbooks/site_README.md)
- [verify_connectivity.yml](playbooks/verify_connectivity_README.md)
- **scan_facts.yml**: Gathers OS and hardware details from inventory.
- **scan_proxmox.yml**: Lists all active VMs and Containers on Proxmox nodes.
- **scan_network.yml**: Performs network discovery on the local subnet.

---

## ✅ Playbook Validation

To ensure the playbooks are error-free before running, use the following commands:

```bash
source venv/bin/activate
export LC_ALL=C.UTF-8 LANG=C.UTF-8
ansible-playbook --syntax-check playbooks/scan_facts.yml
ansible-playbook --syntax-check playbooks/scan_proxmox.yml
ansible-playbook --syntax-check playbooks/scan_network.yml
```
