# QueueMonitor Config Schema

Config import is for non-secret structure. Private keys, passphrases, and
passwords are intentionally excluded.

## Version 1

```json
{
  "version": 1,
  "clusters": [
    {
      "id": "cluster_1",
      "name": "Example Cluster",
      "management": {
        "host": "mgmt.example.edu",
        "port": 22,
        "user": "iaw",
        "auth": {
          "type": "private_key",
          "secret_id": "example_mgmt_key"
        }
      },
      "jump": {
        "enabled": true,
        "host": "jump.example.edu",
        "port": 22,
        "user": "iaw",
        "auth": {
          "type": "private_key",
          "secret_id": "example_jump_key"
        }
      },
      "script": {
        "mode": "inline",
        "content": "#!/usr/bin/env bash\n..."
      },
      "timeout_sec": 20
    }
  ]
}
```

## Auth Types

- `private_key`: app reads PEM text from secure storage by `secret_id`.
- `password`: app reads password text from secure storage by `secret_id`.

Compatibility aliases accepted by the parser:

- `key` is accepted as `private_key`.
- `key_alias` and `password_alias` are accepted as `secret_id`.

## Jump Host

`jump.enabled = false` disables jump-host connection. When enabled, the app
connects to the jump host first, opens a forwarded SSH channel to the management
node, then authenticates to the management node.
