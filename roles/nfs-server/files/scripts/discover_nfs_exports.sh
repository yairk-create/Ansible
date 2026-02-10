#!/bin/bash
# Discover NFS exports from showmount

exports=$(showmount -e --no-headers 2>/dev/null | awk '{print $1}')

echo -n '['
first=1
for export_path in $exports; do
    [ -z "$export_path" ] && continue
    [ "$first" -eq 0 ] && echo -n ','
    echo -n "{\"{#EXPORT}\":\"$export_path\"}"
    first=0
done
echo ']'
