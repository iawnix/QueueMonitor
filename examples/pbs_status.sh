#!/usr/bin/env bash
set -euo pipefail

cluster="${QUEUE_MONITOR_CLUSTER_NAME:-pbs}"

if ! command -v pbsnodes >/dev/null 2>&1; then
  echo "pbsnodes not found" >&2
  exit 10
fi
if ! command -v qstat >/dev/null 2>&1; then
  echo "qstat not found" >&2
  exit 11
fi

read -r cpu_free cpu_total gpu_free gpu_total <<EOF
$(pbsnodes -aSj 2>/dev/null | awk 'NR>3 {
  split($7, cpu, "/");
  split($9, gpu, "/");
  cpu_free += cpu[1];
  cpu_total += cpu[2];
  gpu_free += gpu[1];
  gpu_total += gpu[2];
} END {print cpu_free+0, cpu_total+0, gpu_free+0, gpu_total+0}')
EOF

running=$(qstat 2>/dev/null | awk 'NR>2 && $5 == "R" {count++} END {print count+0}')
queued=$(qstat 2>/dev/null | awk 'NR>2 && ($5 == "Q" || $5 == "H") {count++} END {print count+0}')

printf '{"schema_version":1,"cluster":"%s","ok":true,"cpu":{"free":%d,"total":%d},"gpu":{"free":%d,"total":%d},"jobs":{"running":%d,"queued":%d}}\n' \
  "$cluster" "$cpu_free" "$cpu_total" "$gpu_free" "$gpu_total" "$running" "$queued"
