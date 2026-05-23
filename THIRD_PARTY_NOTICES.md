# Third Party Notices

QueueMonitor is licensed under GNU Affero General Public License v3.0. The
following references and direct runtime dependencies retain their own notices.

## Design Reference: flutter_server_box

- Project: `LollipopKit/flutter_server_box`
- URL: https://github.com/LollipopKit/flutter_server_box
- Upstream license: GNU Affero General Public License v3.0
- Relationship: QueueMonitor uses `flutter_server_box` as a design reference
  for the broad product category: a Flutter mobile app that connects to servers
  over SSH and displays server state.
- Boundary: QueueMonitor does not copy, vendor, translate, or modify
  copyrightable code, UI assets, documentation text, generated files, or other
  protected expression from `flutter_server_box`.
- License handling: QueueMonitor is also AGPL-3.0 as a conservative choice.
  If any future contribution imports or adapts upstream code/assets, that
  contribution must preserve AGPL-3.0 obligations and attribution.

## flutter_secure_storage

- Package: `flutter_secure_storage`
- Version range: `^10.3.0`
- License: BSD 3-Clause
- Purpose in QueueMonitor: stores passwords, private-key PEM text, and private
  key passphrases in platform secure storage.
- Relationship: QueueMonitor depends on the published Flutter package. It does
  not copy, fork, relicense, or claim ownership of `flutter_secure_storage`.
  Use of this package does not imply upstream endorsement.

## dartssh2

- Package: `dartssh2`
- Version range: `^2.17.1`
- License: MIT
- Purpose in QueueMonitor: SSH connection, command execution, and jump-host
  forwarding.

## file_picker

- Package: `file_picker`
- Version range: `^11.0.2`
- License: MIT
- Purpose in QueueMonitor: JSON config import on Android and iOS.

## shared_preferences

- Package: `shared_preferences`
- Version range: `^2.5.5`
- License: BSD-style Flutter license
- Purpose in QueueMonitor: non-secret cluster configuration storage.

For release packaging, keep generated dependency license output from Flutter's
license registry and verify transitive dependencies from `pubspec.lock`.
