#!/usr/bin/env bash
set -euo pipefail

cluster="${QUEUE_MONITOR_CLUSTER_NAME:-1w}"

if ! command -v pbsnodes >/dev/null 2>&1; then
  echo "pbsnodes not found" >&2
  exit 10
fi
if ! command -v qstat >/dev/null 2>&1; then
  echo "qstat not found" >&2
  exit 11
fi

cpu_free=0
cpu_total=0

nodes=$(
  pbsnodes -a 2>/dev/null \
    | awk -F '-' '/^compute/ {split($3, host, "."); print host[1]}' \
    | sort -n \
    | uniq
)

qstat_n1="$(qstat -n1 2>/dev/null)"

for line in $nodes; do
  if [[ "$line" -ge 1 && "$line" -le 20 ]]; then
    node_total=24
  elif [[ "$line" -ge 23 && "$line" -le 29 ]]; then
    node_total=128
  else
    node_total=112
  fi

  used=$(
    awk -v host="compute-0-$line" '
      {
        pos = index($0, host)
        if (pos > 0) {
          next_char = substr($0, pos + length(host), 1)
          if (next_char == "" || next_char !~ /[[:alnum:]_]/) {
            sum += $7
          }
        }
      }
      END {print sum + 0}
    ' <<<"$qstat_n1"
  )

  if ((used < 0)); then
    used=0
  fi

  free=$((node_total - used))
  if ((free < 0)); then
    free=0
  fi

  cpu_free=$((cpu_free + free))
  cpu_total=$((cpu_total + node_total))
done

running=$(qstat -r 2>/dev/null | awk 'NR > 3 {count++} END {print count + 0}')
queued=$(qstat -i 2>/dev/null | awk 'NR > 3 {count++} END {print count + 0}')

printf '{"schema_version":1,"cluster":"%s","ok":true,"cpu":{"free":%d,"total":%d},"gpu":{"free":0,"total":0},"jobs":{"running":%d,"queued":%d}}\n' \
  "$cluster" "$cpu_free" "$cpu_total" "$running" "$queued"
