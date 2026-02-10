#!/bin/bash
# NFS client-side health checks
# Usage: check_nfs.sh <mountpoint> <check_type>

mountpoint="$1"
check="$2"

case "$check" in
    mounted)
        mount -t nfs,nfs4 | grep -q " $mountpoint " && echo 1 || echo 0
        ;;
    stale)
        timeout 5 stat "$mountpoint" > /dev/null 2>&1
        [ $? -eq 0 ] && echo 0 || echo 1
        ;;
    latency)
        tmpfile="$mountpoint/.zabbix_nfs_test_$$"
        start=$(date +%s%N)
        if timeout 10 dd if=/dev/zero of="$tmpfile" bs=4k count=1 conv=fsync 2>/dev/null; then
            timeout 5 cat "$tmpfile" > /dev/null 2>&1
            end=$(date +%s%N)
            rm -f "$tmpfile" 2>/dev/null
            echo $(( (end - start) / 1000000 ))
        else
            rm -f "$tmpfile" 2>/dev/null
            echo -1
        fi
        ;;
    read_latency)
        start=$(date +%s%N)
        if timeout 5 ls "$mountpoint" > /dev/null 2>&1; then
            end=$(date +%s%N)
            echo $(( (end - start) / 1000000 ))
        else
            echo -1
        fi
        ;;
esac
