#!/usr/bin/env bash
set -euo pipefail

cluster="${QUEUE_MONITOR_CLUSTER_NAME:-2w}"

if ! command -v pbsnodes >/dev/null 2>&1; then
  echo "pbsnodes not found" >&2
  exit 10
fi
if ! command -v qstat >/dev/null 2>&1; then
  echo "qstat not found" >&2
  exit 11
fi

read -r cpu_free cpu_total gpu_free gpu_total <<EOF
$(pbsnodes -aSj 2>/dev/null | awk '
  NR > 3 {
    node = $1;
    split($7, cpu, "/");
    split($9, gpu, "/");

    if (node ~ /^cn5[1-9]$/ || node == "cn60") {
      cpu_free += cpu[1];
      cpu_total += cpu[2];
    } else if (node ~ /^cn6[1-4]$/) {
      cpu_free += cpu[1];
      cpu_total += cpu[2];
      gpu_free += gpu[1];
      gpu_total += gpu[2];
    }
  }
  END {
    print cpu_free + 0, cpu_total + 0, gpu_free + 0, gpu_total + 0;
  }
')
EOF

running=$(qstat -r 2>/dev/null | awk 'NR > 5 {count++} END {print count + 0}')
queued=$(qstat -i 2>/dev/null | awk 'NR > 5 {count++} END {print count + 0}')

printf '{"schema_version":1,"cluster":"%s","ok":true,"cpu":{"free":%d,"total":%d},"gpu":{"free":%d,"total":%d},"jobs":{"running":%d,"queued":%d}}\n' \
  "$cluster" "$cpu_free" "$cpu_total" "$gpu_free" "$gpu_total" "$running" "$queued"
