#!/bin/bash
# NFS server-side health checks
# Usage: nfs_server_health.sh <metric> [export_path]

metric="$1"
export_path="$2"

case "$metric" in
    daemon_status)
        # Check both possible NFS daemons on TrueNAS SCALE
        if systemctl is-active nfs-server > /dev/null 2>&1; then
            echo 1
        elif systemctl is-active nfs-ganesha > /dev/null 2>&1; then
            echo 1
        else
            echo 0
        fi
        ;;
    connections)
        ss -tn state established '( sport = :2049 )' 2>/dev/null | tail -n +2 | wc -l
        ;;
    client_count)
        ss -tn state established '( sport = :2049 )' 2>/dev/null | tail -n +2 | awk '{print $5}' | cut -d: -f1 | sort -u | wc -l
        ;;
    export_available)
        if [ -d "$export_path" ]; then
            timeout 5 ls "$export_path" > /dev/null 2>&1 && echo 1 || echo 0
        else
            echo 0
        fi
        ;;
    rpc_status)
        timeout 5 rpcinfo -t 127.0.0.1 nfs > /dev/null 2>&1 && echo 1 || echo 0
        ;;
    nfsd_threads)
        if [ -f /proc/net/rpc/nfsd ]; then
            awk '/^th/ {print $2}' /proc/net/rpc/nfsd
        else
            ps aux | grep -c '[n]fsd'
        fi
        ;;
    clients_list)
        # List unique client IPs (useful for debugging, returns as text)
        ss -tn state established '( sport = :2049 )' 2>/dev/null | tail -n +2 | awk '{print $5}' | cut -d: -f1 | sort -u | tr '\n' ',' | sed 's/,$//'
        ;;
esac
