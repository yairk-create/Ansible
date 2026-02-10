#!/bin/bash
# Global NFS RPC client stats from /proc/net/rpc/nfs
# Usage: nfs_rpc_stats.sh <metric>

metric="$1"

case "$metric" in
    rpc_calls)
        awk '/^rpc/ {print $2}' /proc/net/rpc/nfs 2>/dev/null || echo 0
        ;;
    rpc_retrans)
        awk '/^rpc/ {print $3}' /proc/net/rpc/nfs 2>/dev/null || echo 0
        ;;
    rpc_auth_refresh)
        awk '/^rpc/ {print $4}' /proc/net/rpc/nfs 2>/dev/null || echo 0
        ;;
esac
