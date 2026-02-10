# NFS Monitoring and Auto-Recovery System

## Overview

A comprehensive NFS monitoring and auto-recovery system built on Zabbix 7.0 for a Proxmox VE cluster with TrueNAS storage backends. The system provides full-stack observability from client-side mount health to server-side NFS daemon performance, with automated recovery actions and Telegram alerting.

## Infrastructure

### Monitored Hosts

| Host | Role | IP | Host Groups |
|------|------|----|-------------|
| node (pve) | Proxmox VE node | 192.168.1.243 | Hypervisors, Linux servers, prod servers |
| node1 (pve1) | Proxmox VE node | 192.168.1.240 | Hypervisors, Linux servers, prod servers |
| node2 (pve2) | Proxmox VE node | 192.168.1.241 | Hypervisors, Linux servers, prod servers |
| truenas1 | TrueNAS SCALE (NFS server) | 192.168.1.203 | GPU Nodes, Linux servers, prod servers |
| truenas2 | TrueNAS SCALE (NFS server) | 192.168.1.242 | Discovered hosts, Linux servers, prod servers |

### NFS Mounts (Proxmox Storage)

Each Proxmox node has three NFS mounts used for VM disk storage:

| Mount Point | Purpose |
|-------------|---------|
| /mnt/pve/Nvme-disks | NVMe-backed NFS share |
| /mnt/pve/hard-truenass | HDD-backed NFS share |
| /mnt/pve/truenas-nfs | General NFS share |

### Zabbix Server

- Host: 192.168.1.210
- Deployment: Docker (Zabbix 7.0)
- Frontend: http://192.168.1.210:8080
- API endpoint: http://localhost:8080/api_jsonrpc.php

---

## Zabbix Templates

### NFS Client Monitoring (Template ID: 10919)

Applied to: node, node1, node2

Collects 30 items per host via zabbix-agent2 and custom UserParameter scripts.

#### Discovery Rule

- **NFS mount discovery** (`nfs.discovery`) - discovers all NFS/NFS4 mounts via the `mount` command. Runs every 1 hour, keeps lost resources for 30 days.

#### Items per Discovered Mount ({#NFSMOUNT})

| Item | Key | Type | Description |
|------|-----|------|-------------|
| Mounted status | `nfs.check[{#NFSMOUNT},mounted]` | Integer | 1 = mounted, 0 = missing |
| Stale check | `nfs.check[{#NFSMOUNT},stale]` | Integer | 0 = healthy, 1 = stale (5s timeout) |
| Write latency | `nfs.check[{#NFSMOUNT},write_latency]` | Integer | Milliseconds to write a test file |
| Read latency | `nfs.check[{#NFSMOUNT},read_latency]` | Integer | Milliseconds to read from the mount |
| Read bytes/s | `nfs.client.stats[{#NFSMOUNT},read_bytes]` | Integer | Bytes read (Change per second) |
| Write bytes/s | `nfs.client.stats[{#NFSMOUNT},write_bytes]` | Integer | Bytes written (Change per second) |
| Read ops/s | `nfs.client.stats[{#NFSMOUNT},read_ops]` | Integer | READ operations (Change per second) |
| Write ops/s | `nfs.client.stats[{#NFSMOUNT},write_ops]` | Integer | WRITE operations (Change per second) |
| Retransmissions/s | `nfs.client.stats[{#NFSMOUNT},retrans]` | Integer | RPC retransmissions (Change per second) |
| Timeouts/s | `nfs.client.stats[{#NFSMOUNT},timeouts]` | Integer | RPC timeouts (Change per second) |
| Read RTT avg | `nfs.client.stats[{#NFSMOUNT},read_rtt_avg]` | Float | Average READ round-trip time (ms) |
| Write RTT avg | `nfs.client.stats[{#NFSMOUNT},write_rtt_avg]` | Float | Average WRITE round-trip time (ms) |
| Read execution avg | `nfs.client.stats[{#NFSMOUNT},read_exe_avg]` | Float | Average READ total execution time (ms) |
| Write execution avg | `nfs.client.stats[{#NFSMOUNT},write_exe_avg]` | Float | Average WRITE total execution time (ms) |

#### Global Items

| Item | Key | Description |
|------|-----|-------------|
| RPC total calls/s | `nfs.rpc[calls]` | Total NFS RPC calls (Change per second) |
| RPC retransmissions/s | `nfs.rpc[retrans]` | Global RPC retransmissions (Change per second) |

#### Trigger Prototypes

| Trigger | Severity | Expression |
|---------|----------|------------|
| NFS {#NFSMOUNT} not mounted on {HOST.NAME} | HIGH | mounted = 0 |
| NFS {#NFSMOUNT} stale on {HOST.NAME} | DISASTER | stale = 1 |
| NFS {#NFSMOUNT} write latency warning on {HOST.NAME} | WARNING | write_latency > 100ms |
| NFS {#NFSMOUNT} write latency high on {HOST.NAME} | HIGH | write_latency > 500ms |
| NFS {#NFSMOUNT} retransmissions on {HOST.NAME} | WARNING | retransmissions > 0 |
| NFS {#NFSMOUNT} timeouts on {HOST.NAME} | HIGH | timeouts > 0 |
| NFS {#NFSMOUNT} write RTT high on {HOST.NAME} | WARNING | write_rtt_avg > 50ms |

---

### NFS Server Monitoring (Template ID: 10920)

Applied to: truenas1, truenas2

Collects 21+ items per host via zabbix-agent2 running as a Docker container.

#### Discovery Rule

- **NFS export discovery** (`nfs.server.discovery`) - discovers exports from `/proc/fs/nfsd/exports`. Runs every 1 hour.

#### Regular Items

| Item | Key | Description |
|------|-----|-------------|
| Daemon status | `nfs.server.health[daemon_status]` | 1 = running, 0 = down |
| RPC status | `nfs.server.health[rpc_status]` | 1 = responding, 0 = down |
| Active connections | `nfs.server.health[connections]` | TCP connections on port 2049 |
| Unique client count | `nfs.server.health[client_count]` | Unique client IPs |
| Connected client IPs | `nfs.server.health[clients_list]` | Comma-separated IP list |
| NFS threads | `nfs.server.health[nfsd_threads]` | Active nfsd thread count |
| RPC calls/s | `nfs.server.stats[rpc_calls]` | Total RPC calls (Change/s) |
| Bad RPCs/s | `nfs.server.stats[rpc_bad]` | Failed RPCs (Change/s) |
| Bytes read/s | `nfs.server.stats[io_read]` | Server-side read throughput (Change/s) |
| Bytes written/s | `nfs.server.stats[io_write]` | Server-side write throughput (Change/s) |
| NFSv4 total ops/s | `nfs.server.stats[v4_total]` | All v4 operations (Change/s) |
| NFSv4 reads/s | `nfs.server.stats[v4_read]` | v4 READ operations (Change/s) |
| NFSv4 writes/s | `nfs.server.stats[v4_write]` | v4 WRITE operations (Change/s) |
| NFSv4 commits/s | `nfs.server.stats[v4_commit]` | v4 COMMIT operations (Change/s) |
| NFSv4 opens/s | `nfs.server.stats[v4_open]` | v4 OPEN operations (Change/s) |
| NFSv3 total ops/s | `nfs.server.stats[v3_total]` | All v3 operations (Change/s) |
| NFSv3 reads/s | `nfs.server.stats[v3_read]` | v3 READ operations (Change/s) |
| NFSv3 writes/s | `nfs.server.stats[v3_write]` | v3 WRITE operations (Change/s) |
| Thread saturation/s | `nfs.server.stats[threads_fullcnt]` | Times all threads busy (Change/s) |
| Cache hits/s | `nfs.server.stats[cache_hits]` | Reply cache hits (Change/s) |
| Cache misses/s | `nfs.server.stats[cache_misses]` | Reply cache misses (Change/s) |

#### Item Prototypes

| Item | Key | Description |
|------|-----|-------------|
| Export available | `nfs.server.health[export_available,{#EXPORT}]` | 1 = accessible, 0 = unavailable |

#### Triggers

| Trigger | Severity | Expression |
|---------|----------|------------|
| NFS daemon is down on {HOST.NAME} | DISASTER | daemon_status = 0 |
| NFS RPC not responding on {HOST.NAME} | DISASTER | rpc_status = 0 |
| NFS bad RPCs detected on {HOST.NAME} | WARNING | rpc_bad > 0 for 3 checks |
| NFS all threads busy on {HOST.NAME} | WARNING | threads_fullcnt > 10 for 5 checks |
| No NFS clients connected to {HOST.NAME} | INFO | client_count = 0 |
| NFS export {#EXPORT} unavailable on {HOST.NAME} | HIGH | export_available = 0 |

---

## Data Collection Architecture

### Proxmox Nodes (Client Side)

Zabbix Agent 2 is installed natively via apt on each Proxmox node.

**Agent configuration:** `/etc/zabbix/zabbix_agent2.conf`
- `Hostname` must match the Zabbix host technical name (node, node1, node2)
- `Server` and `ServerActive` point to 192.168.1.210

**UserParameter config:** `/etc/zabbix/zabbix_agent2.d/nfs_client_monitoring.conf`

```
UserParameter=nfs.discovery,/etc/zabbix/scripts/discover_nfs.sh
UserParameter=nfs.check[*],/etc/zabbix/scripts/check_nfs.sh "$1" "$2"
UserParameter=nfs.client.stats[*],/etc/zabbix/scripts/nfs_client_stats.sh "$1" "$2"
UserParameter=nfs.rpc[*],/etc/zabbix/scripts/nfs_rpc_stats.sh "$1"
```

**Scripts directory:** `/etc/zabbix/scripts/`

| Script | Purpose | Data Source |
|--------|---------|-------------|
| discover_nfs.sh | Discovers NFS mounts | `mount` command output |
| check_nfs.sh | Mount status, stale detection, latency | `stat`, `dd`, `touch` with timeouts |
| nfs_client_stats.sh | Per-mount I/O stats | `/proc/self/mountstats` per-op statistics |
| nfs_rpc_stats.sh | Global RPC counters | `/proc/net/rpc/nfs` |
| nfs_client_recovery.sh | Auto-recovery actions | Runs remount, unmount, cache flush, network diagnostics |

### TrueNAS Nodes (Server Side)

Zabbix Agent 2 runs as a Docker container since TrueNAS SCALE locks apt.

**Docker Compose:** `/etc/zabbix/docker-compose.yml`

```yaml
services:
  zabbix-agent2:
    container_name: zabbix-agent2
    environment:
      ZBX_HOSTNAME: truenas1  # or truenas2
      ZBX_SERVER_HOST: 192.168.1.210
      ZBX_TIMEOUT: '15'
    image: zabbix/zabbix-agent2:alpine-7.0-latest
    network_mode: host
    pid: host
    privileged: true
    restart: always
    volumes:
      - /proc:/host/proc:ro
      - /etc/zabbix/scripts:/etc/zabbix/scripts:ro
      - /etc/zabbix/zabbix_agentd.d:/etc/zabbix/zabbix_agentd.d:ro
      - /mnt:/mnt:ro
```

Key design decisions:
- `privileged: true` and `pid: host` required for `nsenter` to access host processes
- `/proc` mounted as `/host/proc` so scripts read kernel NFS stats from the host
- `/mnt` mounted read-only for export availability checks
- UserParameter config placed in `/etc/zabbix/zabbix_agentd.d/` (not `zabbix_agent2.d`) to match the container's Include path

**UserParameter config:** `/etc/zabbix/zabbix_agentd.d/nfs_server_monitoring.conf`

```
UserParameter=nfs.server.discovery,/etc/zabbix/scripts/discover_nfs_exports.sh
UserParameter=nfs.server.health[*],/etc/zabbix/scripts/nfs_server_health.sh "$1" "$2"
UserParameter=nfs.server.stats[*],/etc/zabbix/scripts/nfs_server_stats.sh "$1"
```

**Scripts directory:** `/etc/zabbix/scripts/`

| Script | Purpose | Data Source |
|--------|---------|-------------|
| discover_nfs_exports.sh | Discovers NFS exports | `/host/proc/fs/nfsd/exports` |
| nfs_server_health.sh | Daemon status, connections, clients, threads | `/host/proc/net/rpc/nfsd`, `/host/proc/net/tcp` |
| nfs_server_stats.sh | Server-side I/O, operations, cache | `/host/proc/net/rpc/nfsd` |
| nfs_server_recovery.sh | Auto-recovery actions | Uses `nsenter` to restart services, manage threads, check ZFS |

Container-specific adaptations:
- All `/proc` reads use `/host/proc` path
- Connection counting parses `/host/proc/net/tcp` (hex port 0x0801 = 2049) instead of using `ss`
- Export discovery reads `/host/proc/fs/nfsd/exports` instead of `showmount`
- Recovery script uses `nsenter --target 1 --mount --net --pid --` to execute host-level commands

---

## Alerting

### Telegram Integration

- Bot token: configured in Zabbix Media Type "Telegram"
- Chat ID: 458703818
- Message format: HTML with bold problem/recovery headers
- Sends both problem and recovery notifications

### Alert Flow

For each recovery action, Zabbix follows a two-step escalation:

1. **Step 1 (immediate):** Execute the recovery script on the affected host
2. **Step 2 (after escalation period):** If the problem persists, send a Telegram notification

Recovery notifications are always sent when a problem resolves, regardless of whether auto-recovery fixed it or it resolved on its own.

---

## Auto-Recovery Actions

### Client-Side Recovery (Proxmox Nodes)

Script: `/etc/zabbix/scripts/nfs_client_recovery.sh`
Runs as root via sudoers entry: `zabbix ALL=(root) NOPASSWD: /etc/zabbix/scripts/nfs_client_recovery.sh`

| Zabbix Action | Trigger Match | Recovery Command | Escalation |
|---------------|---------------|------------------|------------|
| Mount disappeared - auto remount | "not mounted" (severity >= HIGH) | `remount {#NFSMOUNT}` | 120s |
| Stale mount - auto fix | "stale" (severity >= DISASTER) | `fix_stale {#NFSMOUNT}` | 120s |
| High latency - flush cache | "write latency" (severity >= WARNING) | `flush_cache {#NFSMOUNT}` | 300s |
| Retransmissions - network check | "retransmissions" (severity >= WARNING) | `check_network {#NFSMOUNT}` | 300s |
| Timeouts - full recovery | "timeouts" (severity >= HIGH) | `full_recovery {#NFSMOUNT}` | 120s |
| Write RTT high - flush cache | "RTT high" (severity >= WARNING) | `flush_cache {#NFSMOUNT}` | 300s |

#### Recovery Actions Detail

**remount** - Attempts to re-mount a disappeared NFS share:
1. Resolves the NFS source from `/etc/fstab` or `/etc/pve/storage.cfg`
2. Pings the NFS server to verify reachability
3. Tests TCP connectivity to port 2049
4. Tries `mount <mountpoint>` (fstab-based)
5. Falls back to explicit `mount -t nfs4` if fstab mount fails

**fix_stale** - Recovers a hung/stale NFS mount:
1. Identifies processes using the mount via `lsof`
2. Sends SIGTERM, waits 2 seconds, then SIGKILL to remaining processes
3. Performs lazy unmount (`umount -l`) to avoid blocking
4. Waits 3 seconds for cleanup
5. Calls the remount procedure

**flush_cache** - Clears caches to help with latency issues:
1. Runs `sync` to flush pending writes
2. Drops page cache, dentries, and inodes (`echo 3 > /proc/sys/vm/drop_caches`)
3. Remounts the filesystem to clear NFS attribute cache

**check_network** - Runs network diagnostics:
1. Ping test (5 packets) to measure packet loss
2. MTU test with jumbo frames (8972 byte payload) to detect MTU mismatches
3. TCP connection time to NFS port 2049
4. NIC error and drop counters on the interface used for the NFS route

**full_recovery** - Combines all recovery steps:
1. If mount exists but is stale: runs fix_stale
2. If mount exists and is accessible: runs flush_cache + check_network
3. If mount does not exist: runs remount

### Server-Side Recovery (TrueNAS)

Script: `/etc/zabbix/scripts/nfs_server_recovery.sh`
Runs inside the zabbix-agent2 container with `nsenter` for host access.

| Zabbix Action | Trigger Match | Recovery Command | Escalation |
|---------------|---------------|------------------|------------|
| Daemon down - auto restart | "daemon is down" (severity >= DISASTER) | `restart_nfs` | 120s |
| RPC not responding - auto restart | "RPC not responding" (severity >= DISASTER) | `restart_nfs` | 120s |
| Threads busy - increase count | "threads busy" (severity >= WARNING) | `increase_threads` | 300s |
| Export unavailable - check dataset | "export" (severity >= HIGH) | `full_recovery {#EXPORT}` | 120s |

#### Recovery Actions Detail

**restart_nfs** - Restarts NFS services:
1. Restarts rpc-statd via systemctl (through nsenter)
2. Restarts nfs-server
3. Waits 3 seconds for services to stabilize
4. Verifies nfs-server is active
5. Re-exports all shares with `exportfs -ra`

**increase_threads** - Scales NFS thread count:
1. Reads current thread count from `/proc/net/rpc/nfsd`
2. Doubles the count (minimum 32, maximum 256)
3. Writes new count to `/proc/fs/nfsd/threads`
4. Verifies the new count took effect

**check_exports** - Refreshes NFS exports:
1. Runs `exportfs -ra` to re-read and apply export configuration
2. Reports the number of active exports

**check_dataset** - Verifies ZFS dataset health:
1. Identifies the ZFS dataset mounted at the export path
2. Checks the ZFS pool health status (ONLINE/DEGRADED/FAULTED)
3. Verifies the dataset is mounted; mounts it if not
4. Re-exports shares after any changes

**full_recovery** - Complete server recovery:
1. Checks ZFS dataset health for the affected export
2. Restarts NFS if daemon is not active or RPC is not responding
3. Refreshes all exports
4. Checks for thread saturation and increases threads if needed

---

## Recovery Logging

All recovery actions log to `/var/log/nfs_recovery.log` on each host with timestamps and process IDs.

Example log output:

```
2026-02-10 15:30:45 [12345] ==========================================
2026-02-10 15:30:45 [12345] NFS Recovery: action=fix_stale mount=/mnt/pve/Nvme-disks
2026-02-10 15:30:45 [12345] RECOVERY: Fixing stale mount /mnt/pve/Nvme-disks
2026-02-10 15:30:46 [12345] Killing processes on mount: 5432 5433
2026-02-10 15:30:48 [12345] Lazy unmount done, waiting...
2026-02-10 15:30:51 [12345] RECOVERY: Remounting /mnt/pve/Nvme-disks
2026-02-10 15:30:51 [12345] NFS server 192.168.1.242 is reachable
2026-02-10 15:30:51 [12345] NFS port 2049 is open on 192.168.1.242
2026-02-10 15:30:52 [12345] SUCCESS: Mounted via fstab
2026-02-10 15:30:52 [12345] Recovery completed successfully
2026-02-10 15:30:52 [12345] ==========================================
```

---

## Deployment Summary

### Ansible Project

An Ansible playbook was created for initial deployment of scripts and agent configuration: `ansible-nfs-monitoring.tar.gz`

Structure:
```
ansible-nfs-monitoring/
  site.yml
  inventories/hosts.yml
  group_vars/all.yml
  group_vars/zabbix_api.yml
  roles/
    nfs-client/         # Proxmox node scripts and config
    nfs-server/         # TrueNAS scripts and config
    zabbix-templates/   # Template import via API
```

### File Locations

#### Proxmox Nodes

| Path | Purpose |
|------|---------|
| /etc/zabbix/zabbix_agent2.conf | Agent config (Hostname must match Zabbix) |
| /etc/zabbix/zabbix_agent2.d/nfs_client_monitoring.conf | UserParameter definitions |
| /etc/zabbix/scripts/discover_nfs.sh | Mount discovery |
| /etc/zabbix/scripts/check_nfs.sh | Mount health checks |
| /etc/zabbix/scripts/nfs_client_stats.sh | Per-mount kernel stats |
| /etc/zabbix/scripts/nfs_rpc_stats.sh | Global RPC counters |
| /etc/zabbix/scripts/nfs_client_recovery.sh | Recovery actions |
| /etc/sudoers.d/zabbix_nfs | Passwordless sudo for recovery |
| /var/log/nfs_recovery.log | Recovery action log |

#### TrueNAS Nodes

| Path | Purpose |
|------|---------|
| /etc/zabbix/docker-compose.yml | Agent container definition |
| /etc/zabbix/zabbix_agentd.d/nfs_server_monitoring.conf | UserParameter definitions |
| /etc/zabbix/zabbix_agent2.d/plugins.d/ | Required empty dir for agent startup |
| /etc/zabbix/scripts/discover_nfs_exports.sh | Export discovery |
| /etc/zabbix/scripts/nfs_server_health.sh | Daemon health and connections |
| /etc/zabbix/scripts/nfs_server_stats.sh | Server-side performance stats |
| /etc/zabbix/scripts/nfs_server_recovery.sh | Recovery actions |
| /var/log/nfs_recovery.log | Recovery action log |

---

## Item Count Summary

| Host | Template | Items | Status |
|------|----------|-------|--------|
| node | NFS Client Monitoring | 30 | All OK |
| node1 | NFS Client Monitoring | 30 | All OK |
| node2 | NFS Client Monitoring | 30 | All OK |
| truenas1 | NFS Server Monitoring | 21 | All OK |
| truenas2 | NFS Server Monitoring | 23 | All OK |
| **Total** | | **134** | **All OK** |

---

## Maintenance Notes

- TrueNAS SCALE updates may reset files in `/etc/zabbix/`. The Docker container and its volume mounts should survive updates, but verify after major upgrades.
- The Zabbix agent2 container uses `privileged: true` which is required for `nsenter` but should be reviewed if security policies change.
- Recovery scripts use `nsenter --target 1` (PID 1 = init) to execute commands in the host namespace from within the container.
- NFS kernel stats in `/proc/self/mountstats` use cumulative counters. Items with "Change per second" preprocessing convert these to rates automatically.
- Discovery runs every 1 hour. New NFS mounts or exports will be detected within this interval.
- The `{#NFSMOUNT}` and `{#EXPORT}` macros in recovery scripts are expanded by Zabbix at runtime to the actual mount path or export path that triggered the alert.
