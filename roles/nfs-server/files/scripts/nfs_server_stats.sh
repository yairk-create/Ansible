#!/bin/bash
# NFS server performance stats from /proc/net/rpc/nfsd
# Usage: nfs_server_stats.sh <metric>
# All counter values are cumulative - use "Change per second" preprocessing in Zabbix.

metric="$1"
nfsd="/proc/net/rpc/nfsd"

if [ ! -f "$nfsd" ]; then
    echo -1
    exit 0
fi

case "$metric" in
    # RPC layer
    rpc_calls)
        awk '/^rpc/ {print $2}' "$nfsd"
        ;;
    rpc_bad)
        awk '/^rpc/ {print $3+$4+$5}' "$nfsd"
        ;;

    # NFSv3 operations
    v3_read)
        awk '/^proc3/ {print $9}' "$nfsd"
        ;;
    v3_write)
        awk '/^proc3/ {print $10}' "$nfsd"
        ;;
    v3_commit)
        awk '/^proc3/ {print $24}' "$nfsd"
        ;;
    v3_getattr)
        awk '/^proc3/ {print $4}' "$nfsd"
        ;;
    v3_access)
        awk '/^proc3/ {print $7}' "$nfsd"
        ;;
    v3_lookup)
        awk '/^proc3/ {print $6}' "$nfsd"
        ;;
    v3_readdir)
        awk '/^proc3/ {print $19}' "$nfsd"
        ;;
    v3_total)
        awk '/^proc3/ {for(i=4;i<=NF;i++) s+=$i; print s}' "$nfsd"
        ;;

    # NFSv4 operations
    v4_read)
        awk '/^proc4ops/ {print $27}' "$nfsd"
        ;;
    v4_write)
        awk '/^proc4ops/ {print $40}' "$nfsd"
        ;;
    v4_commit)
        awk '/^proc4ops/ {print $7}' "$nfsd"
        ;;
    v4_open)
        awk '/^proc4ops/ {print $20}' "$nfsd"
        ;;
    v4_close)
        awk '/^proc4ops/ {print $5}' "$nfsd"
        ;;
    v4_getattr)
        awk '/^proc4ops/ {print $12}' "$nfsd"
        ;;
    v4_total)
        awk '/^proc4ops/ {for(i=4;i<=NF;i++) s+=$i; print s}' "$nfsd"
        ;;

    # I/O bytes
    io_read)
        awk '/^io/ {print $2}' "$nfsd"
        ;;
    io_write)
        awk '/^io/ {print $3}' "$nfsd"
        ;;

    # Thread utilization
    threads_total)
        awk '/^th/ {print $2}' "$nfsd"
        ;;
    threads_fullcnt)
        awk '/^th/ {print $3}' "$nfsd"
        ;;

    # Network
    net_tcp_count)
        awk '/^net/ {print $4}' "$nfsd"
        ;;

    # Reply cache
    cache_hits)
        awk '/^rc/ {print $2}' "$nfsd"
        ;;
    cache_misses)
        awk '/^rc/ {print $3}' "$nfsd"
        ;;

    *)
        echo -1
        ;;
esac
