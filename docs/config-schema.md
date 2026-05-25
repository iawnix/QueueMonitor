# QueueMonitor Config Schema

Config import is for non-secret structure. Private keys, passphrases, and
passwords are intentionally excluded. `secret_id` is a local credential alias:
it names where the app should look up the password or private key in
`flutter_secure_storage`, but it is not itself a secret.

The app supports paste-based import, local JSON file import, and local JSON
export. File import uses the platform file picker (`ACTION_OPEN_DOCUMENT` on
Android and `UIDocumentPickerViewController` on iOS) and reads the selected file
as UTF-8 JSON text. File export uses `ACTION_CREATE_DOCUMENT` on Android and the
iOS share sheet so the JSON can be saved to Files. Native export failures fall
back to copying the JSON to the clipboard.

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

Use a stable alias such as `lab_mgmt_key` or `jump_password`, then enter the
matching password or private key on the device. The same alias can be reused by
multiple cluster entries that intentionally share one credential.

When adding a cluster manually in the app, `secret_id` does not need to be
entered in the normal flow. QueueMonitor generates a local alias from the
cluster id. Set it manually only when importing configs, preserving an existing
alias, or intentionally sharing one credential across entries.

Compatibility aliases accepted by the parser:

- `key` is accepted as `private_key`.
- `key_alias` and `password_alias` are accepted as `secret_id`.

## Jump Host

`jump.enabled = false` disables jump-host connection. When enabled, the app
connects to the jump host first, opens a forwarded SSH channel to the management
node, then authenticates to the management node.
