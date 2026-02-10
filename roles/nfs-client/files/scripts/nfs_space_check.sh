#!/bin/bash
# NFS mount space usage check
# Usage: nfs_space_check.sh <mountpoint> <metric>

mountpoint="$1"
metric="$2"

if ! mountpoint -q "$mountpoint" 2>/dev/null; then
    echo -1
    exit 0
fi

case "$metric" in
    total)
        df -B1 "$mountpoint" | awk 'NR==2 {print $2}'
        ;;
    used)
        df -B1 "$mountpoint" | awk 'NR==2 {print $3}'
        ;;
    available)
        df -B1 "$mountpoint" | awk 'NR==2 {print $4}'
        ;;
    percent)
        df "$mountpoint" | awk 'NR==2 {print $5}' | tr -d '%'
        ;;
    *)
        echo -1
        ;;
esac
