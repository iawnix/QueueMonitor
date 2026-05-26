import 'dart:convert';

import 'package:queue_monitor/models/cluster_config.dart';
import 'package:queue_monitor/services/config_import.dart';
import 'package:queue_monitor/services/secret_store.dart';
import 'package:test/test.dart';

void main() {
  test('imports inline passwords into secure storage only', () async {
    final secretStore = _FakeSecretStore();
    final imported = parseImportedConfigJson('''
{
  "version": 1,
  "clusters": [
    {
      "id": "cluster_demo",
      "name": "Demo",
      "management": {
        "host": "mgmt.example.edu",
        "port": 22,
        "user": "cluster_user",
        "auth": {
          "type": "password",
          "password": "SERVER_PASSWORD"
        }
      },
      "jump": {
        "enabled": true,
        "host": "jump.example.edu",
        "port": 22,
        "user": "jump_user",
        "auth": {
          "type": "password",
          "password": "JUMP_PASSWORD"
        }
      },
      "script": {"mode": "inline", "content": "#!/usr/bin/env bash\\n"},
      "timeout_sec": 20
    }
  ]
}
''');

    await storeImportedPasswords(imported.passwords, secretStore);
    final clusters = imported.clusters;
    final cluster = clusters.single;
    expect(
      cluster.management.auth.secretId,
      'import_cluster_demo_management_password',
    );
    expect(
      cluster.jump.endpoint.auth.secretId,
      'import_cluster_demo_jump_password',
    );

    final managementSecret = await secretStore.read(cluster.management.auth);
    final jumpSecret = await secretStore.read(cluster.jump.endpoint.auth);
    expect(managementSecret.password, 'SERVER_PASSWORD');
    expect(jumpSecret.password, 'JUMP_PASSWORD');

    final savedCluster =
        jsonDecode(jsonEncode(cluster.toJson())) as Map<String, dynamic>;
    final managementAuth =
        (savedCluster['management'] as Map<String, dynamic>)['auth']
            as Map<String, dynamic>;
    final jumpAuth =
        (savedCluster['jump'] as Map<String, dynamic>)['auth']
            as Map<String, dynamic>;

    expect(managementAuth['type'], 'password');
    expect(jumpAuth['type'], 'password');
    expect(managementAuth, isNot(contains('password')));
    expect(jumpAuth, isNot(contains('password')));
  });

  test(
    'preserves explicit secret id while importing inline password',
    () async {
      final secretStore = _FakeSecretStore();
      final imported = parseImportedConfigJson('''
{
  "version": 1,
  "clusters": [
    {
      "id": "cluster_demo",
      "name": "Demo",
      "management": {
        "host": "mgmt.example.edu",
        "port": 22,
        "user": "cluster_user",
        "auth": {
          "type": "password",
          "secret_id": "demo_password",
          "password": "SERVER_PASSWORD"
        }
      },
      "jump": {"enabled": false},
      "script": {"mode": "inline", "content": "#!/usr/bin/env bash\\n"},
      "timeout_sec": 20
    }
  ]
}
''');

      await storeImportedPasswords(imported.passwords, secretStore);
      final auth = imported.clusters.single.management.auth;
      expect(auth.type, AuthType.password);
      expect(auth.secretId, 'demo_password');
      expect((await secretStore.read(auth)).password, 'SERVER_PASSWORD');
    },
  );
}

class _FakeSecretStore implements SecretStore {
  final Map<String, AuthMaterial> _secrets = {};

  @override
  Future<AuthMaterial> read(AuthRef ref) async {
    return _secrets[ref.secretId] ?? const AuthMaterial();
  }

  @override
  Future<void> writePassword(String secretId, String password) async {
    _secrets[secretId] = AuthMaterial(password: password);
  }

  @override
  Future<void> writePrivateKey(
    String secretId,
    String privateKeyPem, {
    String? passphrase,
  }) async {
    _secrets[secretId] = AuthMaterial(
      privateKeyPem: privateKeyPem,
      passphrase: passphrase,
    );
  }

  @override
  Future<void> clearSecret(String secretId) async {
    _secrets.remove(secretId);
  }
}
