#!/usr/bin/env bash
set -euo pipefail

cluster="${QUEUE_MONITOR_CLUSTER_NAME:-8q_xiaohe2}"

if ! command -v sinfo >/dev/null 2>&1; then
  echo "sinfo not found" >&2
  exit 10
fi
if ! command -v squeue >/dev/null 2>&1; then
  echo "squeue not found" >&2
  exit 11
fi

read -r used_cpu cpu_free total_cpu <<EOF
$(sinfo -p xiaohe2 -h --format="%C" 2>/dev/null \
  | awk -F'[/]' '{used += $1; free += $2; total += $4} END {print used + 0, free + 0, total + 0}')
EOF

running=$(squeue -u "$USER" -t R --noheader 2>/dev/null | wc -l | awk '{print $1 + 0}')
queued=$(squeue -u "$USER" -t PD --noheader 2>/dev/null | wc -l | awk '{print $1 + 0}')

printf '{"schema_version":1,"cluster":"%s","ok":true,"cpu":{"free":%d,"total":%d},"gpu":{"free":0,"total":0},"jobs":{"running":%d,"queued":%d}}\n' \
  "$cluster" "$cpu_free" "$total_cpu" "$running" "$queued"
