#!/bin/bash
# Parse /proc/self/mountstats for per-mount NFS client statistics
# Usage: nfs_client_stats.sh <mountpoint> <metric>
#
# Metrics:
#   retrans       - total retransmissions
#   read_bytes    - total bytes read
#   write_bytes   - total bytes written
#   read_ops      - total read operations
#   write_ops     - total write operations
#   read_rtt_avg  - average read round-trip time in ms
#   write_rtt_avg - average write round-trip time in ms
#   read_exe_avg  - average read execution time in ms
#   write_exe_avg - average write execution time in ms
#   timeouts      - total request timeouts

mountpoint="$1"
metric="$2"

stats=$(awk -v mp="$mountpoint" '
    $0 ~ "device .* mounted on " mp " with fstype nfs" {found=1; next}
    /^device /{found=0}
    found {print}
' /proc/self/mountstats 2>/dev/null)

if [ -z "$stats" ]; then
    echo -1
    exit 0
fi

case "$metric" in
    retrans)
        echo "$stats" | awk '
            /^ *(READ|WRITE|GETATTR|ACCESS|LOOKUP|READDIR|READDIRPLUS|COMMIT|SETATTR|CREATE|REMOVE|RENAME):/ {
                getline; retrans += ($2 - $1)
            }
            END {print retrans+0}
        '
        ;;
    timeouts)
        echo "$stats" | awk '
            /^ *(READ|WRITE|GETATTR|ACCESS|LOOKUP|READDIR|READDIRPLUS|COMMIT):/ {
                getline; timeouts += $3
            }
            END {print timeouts+0}
        '
        ;;
    read_bytes)
        echo "$stats" | awk '/^ *READ:/{getline; print $5+0}'
        ;;
    write_bytes)
        echo "$stats" | awk '/^ *WRITE:/{getline; print $5+0}'
        ;;
    read_ops)
        echo "$stats" | awk '/^ *READ:/{getline; print $1+0}'
        ;;
    write_ops)
        echo "$stats" | awk '/^ *WRITE:/{getline; print $1+0}'
        ;;
    read_rtt_avg)
        echo "$stats" | awk '/^ *READ:/{getline; if($1>0) printf "%.2f\n", $7/$1/1000; else print 0}'
        ;;
    write_rtt_avg)
        echo "$stats" | awk '/^ *WRITE:/{getline; if($1>0) printf "%.2f\n", $7/$1/1000; else print 0}'
        ;;
    read_exe_avg)
        echo "$stats" | awk '/^ *READ:/{getline; if($1>0) printf "%.2f\n", $8/$1/1000; else print 0}'
        ;;
    write_exe_avg)
        echo "$stats" | awk '/^ *WRITE:/{getline; if($1>0) printf "%.2f\n", $8/$1/1000; else print 0}'
        ;;
    *)
        echo -1
        ;;
esac
