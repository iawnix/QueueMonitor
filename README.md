# QueueMonitor

Minimal Android/iOS cluster queue monitor over SSH.

Repository target: `https://github.com/iawnix/QueueMonitor`

## Scope

QueueMonitor is intentionally narrow:

- Store one or more cluster management nodes.
- Connect by SSH with password or private key authentication.
- Optionally connect through one SSH jump host.
- Run a user-provided inline bash script on the management node.
- Parse one standardized JSON object from `stdout`.
- Show online/offline, CPU free/total, GPU free/total, running jobs, and queued jobs.

QueueMonitor does not manage files, terminals, Docker, package installs, node lists,
or scheduler operations.

## Script Protocol

The script must print exactly one JSON object to `stdout` and exit with code `0`
when the query succeeds. Diagnostic text belongs in `stderr`.

```json
{
  "schema_version": 1,
  "cluster": "example",
  "ok": true,
  "cpu": { "free": 128, "total": 256 },
  "gpu": { "free": 4, "total": 8 },
  "jobs": { "running": 12, "queued": 3 }
}
```

See [docs/protocol.md](docs/protocol.md) and [examples](examples).

## Config Import

Cluster definitions can be entered in the app, pasted as JSON, or imported from
a local JSON file. QueueMonitor uses the system file picker directly on Android
and iOS, without an extra Flutter file-picker dependency.

The home screen also has an Export button that writes the current config JSON
through the system file UI. Android uses the create-document picker; iOS uses
the share sheet so the file can be saved to Files. If native export fails, the
JSON is copied to the clipboard as a fallback.

Exported config files do not contain private keys, passphrases, or passwords.
For a private handoff file, imported password auth objects may include an
import-only `password` placeholder. QueueMonitor writes imported passwords to
`flutter_secure_storage`, then keeps normal app config and future exports
secret-free. Keep handoff files with real passwords out of GitHub and public
storage.

See [docs/config-schema.md](docs/config-schema.md).

## Development

This repository currently contains the Flutter source tree and app logic. If the
generated Android/iOS platform folders are absent, create them once:

```bash
flutter create --platforms=android,ios --org io.github.iawnix .
flutter pub get
flutter analyze
dart test test/cluster_status_test.dart test/config_repository_test.dart
```

Then build:

```bash
flutter build apk
flutter build ios --no-codesign
```

## License And Dependency Relationship

QueueMonitor is licensed under the GNU Affero General Public License v3.0.
This is a conservative licensing choice because the project explicitly takes
product-level inspiration from `LollipopKit/flutter_server_box`, whose upstream
license is also AGPL-3.0.

## Relationship To flutter_server_box

QueueMonitor was designed with reference to the public project
[`LollipopKit/flutter_server_box`](https://github.com/LollipopKit/flutter_server_box),
especially the general idea of a Flutter-based SSH server monitor for mobile
devices.

The upstream `flutter_server_box` repository is licensed under AGPL-3.0.
QueueMonitor does not copy, vendor, translate, or modify source code, UI
assets, text, or generated files from that repository. QueueMonitor is a clean,
narrower implementation for one use case: querying a cluster management node
with a user-provided script and displaying queue capacity.

If future work copies or adapts any copyrightable source code or assets from
`flutter_server_box`, that copied/adapted part must be handled under AGPL-3.0
and this repository's licensing plan must be revisited before release.

## flutter_secure_storage Relationship

It uses `flutter_secure_storage` as a runtime dependency for local secret
storage. QueueMonitor is not affiliated with, endorsed by, or derived from
`flutter_secure_storage`. That package remains under its own BSD 3-Clause
License. On iOS it uses Keychain; on Android version 10.x uses platform secure
storage with RSA OAEP and AES-GCM by default. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

QueueMonitor also uses `dartssh2` for SSH and `shared_preferences` for
non-secret cluster configuration.
