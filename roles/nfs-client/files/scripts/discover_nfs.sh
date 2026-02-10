#!/bin/bash
# Discover all NFS/NFS4 mounts on this host

mounts=$(mount -t nfs,nfs4 2>/dev/null | awk '{print $1, $3}')

echo -n '['
first=1
while read -r source mountpoint; do
    [ -z "$source" ] && continue
    server=$(echo "$source" | cut -d: -f1)
    share=$(echo "$source" | cut -d: -f2)
    [ "$first" -eq 0 ] && echo -n ','
    echo -n "{\"{#NFSMOUNT}\":\"$mountpoint\",\"{#NFSSOURCE}\":\"$source\",\"{#NFSSERVER}\":\"$server\",\"{#NFSSHARE}\":\"$share\"}"
    first=0
done <<< "$mounts"
echo ']'
