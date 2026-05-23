# Security Notes

QueueMonitor stores connection metadata separately from secrets.

## Stored As Plain App Preferences

- Cluster names.
- Management host, port, and username.
- Jump host, port, and username.
- Script content.
- Secret aliases.

## Stored Through `flutter_secure_storage`

- Passwords.
- Private key PEM content.
- Private key passphrases.

`flutter_secure_storage` is a dependency, not bundled source code. Its upstream
license is BSD 3-Clause. QueueMonitor's own code is AGPL-3.0 licensed.

`LollipopKit/flutter_server_box` is an AGPL-3.0 project used as an explicit
design reference. QueueMonitor is also AGPL-3.0 to keep the license posture
conservative. Do not copy code, assets, or docs from it without preserving
source, attribution, and AGPL obligations.

## Operational Rules

- Do not put real secrets in imported config files.
- Do not commit imported local config files.
- Rotate any password, token, or mail authorization code that has been pasted
  into a chat, issue, or repository by mistake.
- Keep status scripts read-only. They should query schedulers and print JSON,
  not submit, cancel, or mutate jobs.
