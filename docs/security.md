# Security Notes

QueueMonitor stores connection metadata separately from secrets.

## Stored As Plain App Preferences

- Cluster names.
- Management host, port, and username.
- Jump host, port, and username.
- Script content.
- Credential aliases (`secret_id` values). These are local names used to find
  passwords or private keys in secure storage; they are not the secrets
  themselves.

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

- Prefer secret-free imported config files when possible.
- If a private handoff file uses import-only `auth.password` fields, keep it
  local, ignored by Git, and out of GitHub, chat logs, issue trackers, and
  public storage.
- Do not commit imported local config files.
- Rotate any password, token, or mail authorization code that has been pasted
  into a chat, issue, or repository by mistake.
- Keep status scripts read-only. They should query schedulers and print JSON,
  not submit, cancel, or mutate jobs.
