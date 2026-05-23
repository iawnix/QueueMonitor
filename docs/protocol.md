# QueueMonitor Script Protocol

## Contract

The app executes the configured script on the cluster management node through SSH.

The script must:

- Write exactly one JSON object to `stdout`.
- Write diagnostics to `stderr`.
- Exit `0` only when the JSON is valid and complete.
- Use integer counts, not percentages.
- Aggregate the whole cluster at management-node level.

The script must not:

- Print human-readable status lines before or after the JSON.
- Print per-node data.
- Include passwords, keys, tokens, or email credentials.

## Schema Version 1

```json
{
  "schema_version": 1,
  "cluster": "cluster-name",
  "ok": true,
  "cpu": {
    "free": 0,
    "total": 0
  },
  "gpu": {
    "free": 0,
    "total": 0
  },
  "jobs": {
    "running": 0,
    "queued": 0
  }
}
```

## Field Semantics

- `schema_version`: integer, currently `1`.
- `cluster`: display name from the script side; the app can still use its local name.
- `ok`: boolean. `true` means scheduler commands succeeded.
- `cpu.free`: currently idle CPU cores/slots.
- `cpu.total`: total CPU cores/slots considered by the script.
- `gpu.free`: currently idle GPUs.
- `gpu.total`: total GPUs considered by the script.
- `jobs.running`: running job count or running allocation count.
- `jobs.queued`: queued/pending job count.

If a cluster has no GPU, report `gpu.free = 0` and `gpu.total = 0`.

## Failure Behavior

Use a non-zero exit code when scheduler commands fail.

Example:

```bash
if ! command -v sinfo >/dev/null 2>&1; then
  echo "sinfo not found" >&2
  exit 10
fi
```

The app marks the cluster offline or failed and shows `stderr` in detail view.

## Examples

- `examples/pbs_1w_status.sh`: PBS-style CPU capacity example that emits
  protocol v1 JSON.
- `examples/pbs_2w_status.sh`: PBS-style CPU/GPU capacity example that emits
  protocol v1 JSON.
