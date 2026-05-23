#!/usr/bin/env bash
set -euo pipefail

cluster="${QUEUE_MONITOR_CLUSTER_NAME:-7q_xiaohe}"

if ! command -v pestat >/dev/null 2>&1; then
  echo "pestat not found" >&2
  exit 10
fi
if ! command -v scontrol >/dev/null 2>&1; then
  echo "scontrol not found" >&2
  exit 11
fi
if ! command -v squeue >/dev/null 2>&1; then
  echo "squeue not found" >&2
  exit 12
fi

total=$(
  pestat | grep gpu | awk '{print $1}' | while read -r node; do
    scontrol show nodes "$node" | grep -o "CfgTRES.*gpu=[0-9]*" | grep -o "[0-9]*$"
  done | awk '{sum += $1} END {print sum + 0}'
)

free=$(
  pestat | grep gpu | awk '{print $1}' | while read -r node; do
    node_total=$(scontrol show nodes "$node" | grep -o "CfgTRES.*gpu=[0-9]*" | grep -o "[0-9]*$")
    used=$(scontrol show nodes "$node" | grep -o "AllocTRES.*gpu=[0-9]*" | grep -o "[0-9]*$")
    echo $((node_total - used))
  done | awk '{sum += $1} END {print sum + 0}'
)

running=$(
  squeue -u "$USER" -t R --format="%b" | tail -n +2 | while read -r line; do
    echo "$line" | tr ',' '\n' | cut -d: -f2 | sort -u | wc -l
  done | awk '{sum += $1} END {print sum + 0}'
)

queued=$(
  squeue -u "$USER" -t PD --format="%b" | tail -n +2 | while read -r line; do
    echo "$line" | tr ',' '\n' | cut -d: -f2 | sort -u | wc -l
  done | awk '{sum += $1} END {print sum + 0}'
)

printf '{"schema_version":1,"cluster":"%s","ok":true,"cpu":{"free":0,"total":0},"gpu":{"free":%d,"total":%d},"jobs":{"running":%d,"queued":%d}}\n' \
  "$cluster" "$free" "$total" "$running" "$queued"
