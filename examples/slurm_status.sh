#!/usr/bin/env bash
set -euo pipefail

cluster="${QUEUE_MONITOR_CLUSTER_NAME:-slurm}"

if ! command -v sinfo >/dev/null 2>&1; then
  echo "sinfo not found" >&2
  exit 10
fi
if ! command -v squeue >/dev/null 2>&1; then
  echo "squeue not found" >&2
  exit 11
fi

read -r cpu_free cpu_total <<EOF
$(sinfo -h --format="%C" | awk -F'[/]' '{free += $2; total += $4} END {print free+0, total+0}')
EOF

gpu_total=0
gpu_free=0
if command -v scontrol >/dev/null 2>&1; then
  gpu_total=$(
    scontrol show nodes 2>/dev/null \
      | awk -F'gpu=' '/CfgTRES=.*gpu=/ {split($2,a,","); total+=a[1]} END {print total+0}'
  )
  gpu_used=$(
    scontrol show nodes 2>/dev/null \
      | awk -F'gpu=' '/AllocTRES=.*gpu=/ {split($2,a,","); used+=a[1]} END {print used+0}'
  )
  gpu_free=$((gpu_total - gpu_used))
  if [ "$gpu_free" -lt 0 ]; then
    gpu_free=0
  fi
fi

running=$(squeue -h -t R 2>/dev/null | wc -l | awk '{print $1+0}')
queued=$(squeue -h -t PD 2>/dev/null | wc -l | awk '{print $1+0}')

printf '{"schema_version":1,"cluster":"%s","ok":true,"cpu":{"free":%d,"total":%d},"gpu":{"free":%d,"total":%d},"jobs":{"running":%d,"queued":%d}}\n' \
  "$cluster" "$cpu_free" "$cpu_total" "$gpu_free" "$gpu_total" "$running" "$queued"
