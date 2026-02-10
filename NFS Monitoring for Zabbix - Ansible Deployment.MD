# NFS Monitoring for Zabbix - Ansible Deployment

Deploys comprehensive NFS monitoring across Proxmox nodes (client side) and
TrueNAS SCALE (server side), including Zabbix template import and host linking.

## What Gets Monitored

### Client Side (Proxmox Nodes)
- Mount status (mounted/unmounted)
- Stale mount detection
- Write and read latency tests
- Read/write throughput (bytes/s)
- Read/write IOPS (ops/s)
- Retransmissions and timeouts
- Kernel-level read/write RTT and execution time
- Global RPC call and retransmission rates

### Server Side (TrueNAS)
- NFS daemon health
- RPC portmapper status
- Active connections and unique client count
- Connected client IP list
- NFS thread count and saturation
- Server-side I/O throughput (bytes read/written)
- NFSv3 and NFSv4 operation rates
- Reply cache hit/miss rates
- Per-export availability

## Prerequisites

- Ansible installed on your control machine
- SSH key access to all Proxmox nodes and TrueNAS
- Zabbix server with API access
- Hosts already registered in Zabbix (hostnames must match inventory names)
- Zabbix agent2 repo available (playbook installs agent if missing)

## Setup

1. Edit inventory:
   ```
   vim inventories/hosts.yml
   ```
   Set the correct IPs for your Proxmox nodes and TrueNAS.

2. Edit global vars:
   ```
   vim group_vars/all.yml
   ```
   Set your Zabbix server IP.

3. Edit Zabbix API vars:
   ```
   vim group_vars/zabbix_api.yml
   ```
   Set API URL and credentials. For production, use ansible-vault:
   ```
   ansible-vault encrypt group_vars/zabbix_api.yml
   ```

4. Run the playbook:
   ```
   ansible-playbook site.yml
   ```

## Usage

```bash
# Full deployment
ansible-playbook site.yml

# Agents and scripts only (no Zabbix API calls)
ansible-playbook site.yml --tags agents

# Templates and linking only
ansible-playbook site.yml --tags templates

# Single node
ansible-playbook site.yml --limit pve1

# Dry run
ansible-playbook site.yml --check --diff
```

## File Layout

```
.
├── ansible.cfg
├── site.yml
├── inventories/
│   └── hosts.yml
├── group_vars/
│   ├── all.yml
│   └── zabbix_api.yml
└── roles/
    ├── nfs-client/
    │   ├── tasks/main.yml
    │   ├── handlers/main.yml
    │   ├── templates/nfs_monitoring.conf.j2
    │   └── files/scripts/
    │       ├── discover_nfs.sh
    │       ├── check_nfs.sh
    │       ├── nfs_client_stats.sh
    │       └── nfs_rpc_stats.sh
    ├── nfs-server/
    │   ├── tasks/main.yml
    │   ├── handlers/main.yml
    │   ├── templates/nfs_server_monitoring.conf.j2
    │   └── files/scripts/
    │       ├── discover_nfs_exports.sh
    │       ├── nfs_server_health.sh
    │       └── nfs_server_stats.sh
    └── zabbix-templates/
        ├── tasks/main.yml
        └── files/
            ├── nfs_client_template.yaml
            └── nfs_server_template.yaml
```

## Notes

- TrueNAS SCALE may overwrite system files on major upgrades. Re-run the
  playbook after TrueNAS updates to restore the monitoring config.
- The write latency test needs write permission on NFS mounts. If the zabbix
  user lacks write access, the read_latency check still works.
- Counter-based items use "Change per second" preprocessing in Zabbix.
- NFS mount discovery runs hourly. Use "Execute now" in the Zabbix frontend
  to trigger it immediately after deployment.
- Adjust latency trigger thresholds based on your storage backend:
  NVMe-backed shares should use tighter thresholds than HDD-backed ones.
