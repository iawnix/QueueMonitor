#!/usr/bin/env bash
set -euo pipefail

cluster="${QUEUE_MONITOR_CLUSTER_NAME:-gpu-host}"

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi not found" >&2
  exit 10
fi

gpu_ids=$(nvidia-smi --query-gpu=index --format=csv,noheader,nounits)
gpu_total=$(printf '%s\n' "$gpu_ids" | awk 'NF {count++} END {print count+0}')
gpu_free=0

for gpu in $gpu_ids; do
  proc_count=$(nvidia-smi -i "$gpu" --query-compute-apps=pid --format=csv,noheader,nounits | awk 'NF {count++} END {print count+0}')
  if [ "$proc_count" -eq 0 ]; then
    gpu_free=$((gpu_free + 1))
  fi
done

printf '{"schema_version":1,"cluster":"%s","ok":true,"cpu":{"free":0,"total":0},"gpu":{"free":%d,"total":%d},"jobs":{"running":0,"queued":0}}\n' \
  "$cluster" "$gpu_free" "$gpu_total"
