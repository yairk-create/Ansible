# NFS Monitoring and Auto-Recovery with Zabbix

## Overview

This document describes the NFS monitoring and automatic recovery infrastructure deployed across a Proxmox/TrueNAS homelab environment. The system uses Zabbix 7.0 for monitoring, Telegram for alerting, and custom scripts on TrueNAS SCALE for automated share recovery.

## Environment

| Host         | IP             | Role                          |
|--------------|----------------|-------------------------------|
| vanila       | 192.168.1.210  | Zabbix Server                 |
| pve1         | -              | Proxmox node (NFS client)     |
| pve2         | -              | Proxmox node (NFS client)     |
| truenas1     | 192.168.1.242  | TrueNAS SCALE (NFS server)    |
| truenas2     | 192.168.1.203  | TrueNAS SCALE (NFS server)    |

### NFS Shares

**truenas1 (192.168.1.242)**

| Share ID | Path                | Purpose           |
|----------|---------------------|--------------------|
| 11       | /mnt/main/proxmox-vm | VM storage         |

**truenas2 (192.168.1.203)**

| Share ID | Path                            | Purpose           |
|----------|---------------------------------|--------------------|
| 1        | /mnt/tank/storage               | General storage    |
| 2        | /mnt/tank/storage/pve_images    | VM images          |

## Problem Statement

When an NFS share becomes unavailable, Zabbix would generate up to 6 duplicate Telegram alerts for a single event. This happened because:

1. Multiple triggers fire for the same root cause (stale, not mounted, daemon down, RPC not responding, export unavailable).
2. Multiple Zabbix actions matched the same event:
   - Action 3: "Report problems to Zabbix administrators" (no filter, catches everything).
   - Action 10: "Send Telegram on trigger" (broad NFS filter).
   - Action 29: "NFS Alert to Telegram" (dedicated NFS action).
3. Some actions sent to multiple recipients (yair + Admin).

Additionally, the existing auto-recovery scripts used `exportfs -ra` which does not work on TrueNAS SCALE because NFS shares are managed through the TrueNAS middleware (`midclt`), not `/etc/exports`.

## Solution Architecture

### Alert Deduplication

Three changes eliminated duplicate alerts:

1. **Action 3** ("Report problems to Zabbix administrators"): Added filter to exclude NFS triggers (`conditiontype=3, operator=3, value="NFS"` = trigger name does NOT contain "NFS").

2. **Action 10** ("Send Telegram on trigger"): Changed evaltype to AND and added exclusion for NFS triggers (`conditiontype=3, operator=3, value="NFS"`).

3. **Action 29** ("NFS Alert to Telegram"): This is now the sole action handling NFS alerts. Configured to send only to user `yair` (userid=3). Filter uses evaltype=0 (AND/OR) with conditions matching root-cause trigger names: stale, not mounted, daemon is down, RPC not responding, export.

### Auto-Recovery Flow

```
NFS share goes down
        |
        v
Zabbix detects trigger on client (pve1/pve2) or server (truenas1/truenas2)
        |
        v
Action 29 - Step 1 (immediate):
  1. Sends Telegram alert to yair
  2. Runs remote command on truenas1 + truenas2
        |
        v
Zabbix agent (container) runs /etc/zabbix/scripts/nfs_server_recovery.sh
        |
        v
Script creates trigger file: /etc/zabbix/scripts/trigger_recovery
        |
        v
systemd path unit (nfs-recovery.path) detects trigger file
        |
        v
systemd service runs /mnt/scripts/nfs_recovery.sh on the HOST
        |
        v
Recovery script uses midclt to re-enable disabled whitelisted shares
        |
        v
systemd removes trigger file
        |
        v
   Problem resolved? ----YES----> Done
        |
        NO (5 minutes pass)
        |
        v
Action 29 - Step 2 (escalation after 5 min):
  1. Sends escalation Telegram to yair
  2. Runs NFS restart on truenas1 + truenas2
        |
        v
Zabbix agent creates trigger file: /etc/zabbix/scripts/trigger_restart
        |
        v
systemd path unit (nfs-restart.path) detects trigger file
        |
        v
systemd service runs /mnt/scripts/nfs_restart.sh on the HOST
        |
        v
Full NFS service restart (systemctl restart nfs-server)
        |
        v
systemd removes trigger file
```

### Why the Trigger File Pattern

The Zabbix agent runs inside a Docker container as the `zabbix` user. It cannot directly:

- Run `midclt` (not available inside the container).
- Use `nsenter` to access the host namespace (permission denied).
- Write to `/mnt` (mounted read-only in the container).

The solution uses a signal file approach:

1. The agent writes a trigger file to `/etc/zabbix/scripts/` (writable inside the container).
2. A systemd path unit on the host watches for this file.
3. When detected, a systemd service runs the actual recovery script with full host access.

## Configuration Details

### Zabbix Actions

**Action 29: NFS Alert to Telegram**

```
Filter: evaltype=0 (AND/OR)
Conditions (OR'd together):
  - Trigger name contains "stale"
  - Trigger name contains "not mounted"
  - Trigger name contains "daemon is down"
  - Trigger name contains "RPC not responding"
  - Trigger name contains "export"

Escalation period: 5 minutes

Step 1 (immediate):
  1. Send message to user yair via Telegram (default message)
  2. Run script "NFS: Re-enable all shares" on truenas1 + truenas2

Step 2 (after 5 minutes, if problem still open):
  1. Send escalation Telegram to yair (custom message: "NFS share not recovered after 5 minutes. Restarting NFS service.")
  2. Run script "NFS: Restart NFS service" on truenas1 + truenas2
```

**Action 3: Report problems to Zabbix administrators**

```
Filter: evaltype=1 (AND)
Conditions:
  - Trigger name does NOT contain "NFS"
```

**Action 10: Send Telegram on trigger**

```
Filter: evaltype=1 (AND)
Conditions:
  - Trigger name does NOT contain "NFS"
  - Severity >= Warning
```

### Zabbix Script (ID 30): "NFS: Re-enable all shares"

```
Type: Script
Execute on: Zabbix agent
Command: /etc/zabbix/scripts/nfs_server_recovery.sh full_recovery
```

Note: The previous script (ID 28) used `{#EXPORT}` LLD macro which does not resolve when running on TrueNAS hosts (the macro belongs to the client host). The new script runs without arguments and re-enables all whitelisted shares.

### Zabbix Script: "NFS: Restart NFS service"

```
Type: Script
Execute on: Zabbix agent
Command: /etc/zabbix/scripts/nfs_restart_trigger.sh
```

Used by escalation step 2. Triggers a full NFS service restart on the TrueNAS host if the share is still down after 5 minutes.

### Trigger Dependencies (Same-Host)

Set at the trigger prototype level for LLD-discovered triggers:

```
stale         --> depends on "not mounted"
not mounted   --> depends on "daemon is down"
daemon is down --> depends on "RPC not responding"
```

Note: Cross-host dependencies (e.g., RPC on proxmox -> export on truenas) are not supported by Zabbix. The action filter handles this instead.

## Files on TrueNAS Hosts

### /etc/zabbix/scripts/nfs_server_recovery.sh

Runs inside the Zabbix agent container. Creates a trigger file to signal the host for share re-enable.

```bash
#!/bin/bash
touch /etc/zabbix/scripts/trigger_recovery
echo "Recovery triggered"
```

### /etc/zabbix/scripts/nfs_restart_trigger.sh

Runs inside the Zabbix agent container. Creates a trigger file to signal the host for a full NFS service restart (escalation step 2).

```bash
#!/bin/bash
touch /etc/zabbix/scripts/trigger_restart
echo "NFS restart triggered"
```

### /mnt/scripts/nfs_recovery.sh

Runs on the TrueNAS host via systemd. Uses `midclt` to re-enable disabled NFS shares.

```bash
#!/bin/bash
LOGFILE="/mnt/scripts/nfs_recovery.log"
WHITELIST="/mnt/scripts/nfs_recovery_whitelist.txt"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$$] $1" | tee -a "$LOGFILE"
}

if [ ! -f "$WHITELIST" ]; then
    log "No whitelist found at $WHITELIST"
    exit 1
fi

log "=========================================="
log "NFS Recovery triggered by Zabbix"

disabled=$(midclt call sharing.nfs.query | python3 -c "
import sys, json
whitelist = open('$WHITELIST').read().splitlines()
for s in json.load(sys.stdin):
    if not s['enabled'] and s['path'] in whitelist:
        print(s['id'], s['path'])
" 2>/dev/null)

if [ -z "$disabled" ]; then
    log "All whitelisted shares already enabled"
else
    while read -r sid spath; do
        midclt call sharing.nfs.update "$sid" '{"enabled": true}' > /dev/null 2>&1
        log "Re-enabled share $sid ($spath)"
    done <<< "$disabled"
fi

count=$(exportfs -v 2>/dev/null | wc -l)
log "Active exports: $count"

if ! systemctl is-active nfs-server > /dev/null 2>&1; then
    log "NFS daemon down, restarting"
    systemctl restart rpc-statd nfs-server
    sleep 3
    exportfs -ra
fi

log "Recovery complete"
log "=========================================="
```

### /mnt/scripts/nfs_recovery_whitelist.txt

Only shares listed here will be auto-recovered. This prevents accidentally re-enabling intentionally disabled shares (e.g., Immich NFS shares on truenas2).

**truenas1:**

```
/mnt/main/proxmox-vm
```

**truenas2:**

```
/mnt/tank/storage
/mnt/tank/storage/pve_images
/mnt/tank/opt
```

### /etc/systemd/system/nfs-recovery.path

Watches for the trigger file created by the Zabbix agent (step 1 - re-enable shares).

```ini
[Unit]
Description=Watch for NFS recovery trigger

[Path]
PathExists=/etc/zabbix/scripts/trigger_recovery

[Install]
WantedBy=multi-user.target
```

### /etc/systemd/system/nfs-recovery.service

Runs the recovery script and cleans up the trigger file.

```ini
[Unit]
Description=NFS Recovery

[Service]
Type=oneshot
ExecStart=/bin/bash /mnt/scripts/nfs_recovery.sh
ExecStartPost=/bin/rm -f /etc/zabbix/scripts/trigger_recovery
```

Note: `ExecStart` uses `/bin/bash` explicitly because `/mnt` may have `noexec` set on TrueNAS.

### /mnt/scripts/nfs_restart.sh

Runs on the TrueNAS host via systemd (escalation step 2). Performs a full NFS service restart.

```bash
#!/bin/bash
LOGFILE="/mnt/scripts/nfs_recovery.log"
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$$] $1" | tee -a "$LOGFILE"
}
log "=========================================="
log "NFS ESCALATION: Restarting NFS service (problem unresolved)"
systemctl restart rpc-statd nfs-server
sleep 3
if systemctl is-active nfs-server > /dev/null 2>&1; then
    log "NFS service restarted successfully"
    exportfs -ra
    count=$(exportfs -v 2>/dev/null | wc -l)
    log "Active exports: $count"
else
    log "CRITICAL: NFS service failed to start"
fi
log "=========================================="
```

### /etc/systemd/system/nfs-restart.path

Watches for the restart trigger file created by the Zabbix agent (step 2 - escalation).

```ini
[Unit]
Description=Watch for NFS restart trigger

[Path]
PathExists=/etc/zabbix/scripts/trigger_restart

[Install]
WantedBy=multi-user.target
```

### /etc/systemd/system/nfs-restart.service

Runs the restart script and cleans up the trigger file.

```ini
[Unit]
Description=NFS Service Restart

[Service]
Type=oneshot
ExecStart=/bin/bash /mnt/scripts/nfs_restart.sh
ExecStartPost=/bin/rm -f /etc/zabbix/scripts/trigger_restart
```

### /etc/logrotate.d/nfs_recovery

```
/var/log/nfs_recovery.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

## Docker Container Configuration

The Zabbix agent container requires the `/etc/zabbix/scripts` volume to be mounted **without** the `:ro` flag so the agent can create the trigger file.

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
      - /etc/zabbix/scripts:/etc/zabbix/scripts        # NOT read-only
      - /etc/zabbix/zabbix_agentd.d:/etc/zabbix/zabbix_agentd.d:ro
      - /mnt:/mnt:ro
```

### Permissions

The `/etc/zabbix/scripts` directory needs group write access for the `zabbix` user (UID 1997, GID 1995 inside the container):

```bash
chgrp 1995 /etc/zabbix/scripts
chmod 775 /etc/zabbix/scripts
```

The agent configuration must allow remote commands:

```
# /etc/zabbix/zabbix_agentd.d/allow_remote.conf
AllowKey=system.run[*]
```

## Testing

### Manual Test

From the TrueNAS host:

```bash
# Disable a share
midclt call sharing.nfs.update <SHARE_ID> '{"enabled": false}'

# Trigger recovery manually
touch /etc/zabbix/scripts/trigger_recovery

# Check logs
sleep 3
cat /mnt/scripts/nfs_recovery.log

# Verify share is re-enabled
midclt call sharing.nfs.query | python3 -c "
import sys, json
for s in json.load(sys.stdin):
    print(s['id'], s['path'], s['enabled'])
"
```

### End-to-End Test

```bash
# Disable share and wait for Zabbix to detect
midclt call sharing.nfs.update <SHARE_ID> '{"enabled": false}'

# Watch recovery log
watch -n5 'tail -10 /mnt/scripts/nfs_recovery.log'
```

Expected behavior:

1. Zabbix detects stale/unmounted NFS within 1-2 minutes.
2. Action 29 Step 1 fires: one Telegram message to yair + re-enable shares command.
3. Agent creates trigger file on both TrueNAS hosts.
4. systemd detects file and runs recovery (re-enable whitelisted shares via midclt).
5. If resolved: Zabbix detects recovery and closes the problem.
6. If NOT resolved after 5 minutes: Action 29 Step 2 fires: escalation Telegram + full NFS service restart.

### Test Escalation

To test the escalation (NFS restart after 5 minutes), manually trigger the restart:

```bash
# On TrueNAS host
touch /etc/zabbix/scripts/trigger_restart
sleep 3
cat /mnt/scripts/nfs_recovery.log
```

### Verify Alert Deduplication

After disabling a share, you should see exactly:

- 1 Telegram message (to yair only)
- Remote commands executed on both TrueNAS hosts
- No alerts from Action 3 or Action 10 for NFS triggers

## Troubleshooting

### Recovery not running

1. Check if agent can write trigger file:
   ```bash
   docker exec zabbix-agent2 touch /etc/zabbix/scripts/trigger_recovery
   ```

2. Check systemd path unit:
   ```bash
   systemctl status nfs-recovery.path
   systemctl status nfs-recovery.service
   journalctl -u nfs-recovery.service --no-pager -n 20
   ```

3. Check recovery log:
   ```bash
   cat /mnt/scripts/nfs_recovery.log
   ```

### Escalation (restart) not running

1. Check if agent can write restart trigger:
   ```bash
   docker exec zabbix-agent2 touch /etc/zabbix/scripts/trigger_restart
   ```

2. Check systemd restart units:
   ```bash
   systemctl status nfs-restart.path
   systemctl status nfs-restart.service
   journalctl -u nfs-restart.service --no-pager -n 20
   ```

### Multiple alerts still firing

Check which actions fired for an event:

```python
python3 << 'PYSCRIPT'
import json, urllib.request
TOKEN = "YOUR_TOKEN"
URL = "http://localhost:8080/api_jsonrpc.php"
def api(method, params):
    payload = json.dumps({"jsonrpc":"2.0","method":method,"params":params,"auth":TOKEN,"id":1}).encode()
    req = urllib.request.Request(URL, data=payload, headers={"Content-Type":"application/json"})
    return json.loads(urllib.request.urlopen(req).read().decode())["result"]

problems = api("problem.get", {"output": ["eventid", "name"], "recent": True})
for p in problems:
    if "NFS" in p["name"]:
        alerts = api("alert.get", {"eventids": [p["eventid"]], "output": ["actionid", "sendto", "status"]})
        print(f"Event {p['eventid']}: {p['name']}")
        for a in alerts:
            print(f"  action={a['actionid']} sendto={a.get('sendto','')} status={a['status']}")
PYSCRIPT
```

### Shares not re-enabling

1. Verify whitelist file exists and contains the correct paths:
   ```bash
   cat /mnt/scripts/nfs_recovery_whitelist.txt
   ```

2. Test midclt manually:
   ```bash
   midclt call sharing.nfs.query | python3 -m json.tool
   midclt call sharing.nfs.update <ID> '{"enabled": true}'
   ```

### systemd service fails with permission denied

Ensure `ExecStart` uses `/bin/bash /mnt/scripts/nfs_recovery.sh` (not a direct path) since `/mnt` may be mounted with `noexec`.

```bash
systemctl reset-failed nfs-recovery.service
systemctl start nfs-recovery.service
journalctl -u nfs-recovery.service --no-pager -n 10
```
