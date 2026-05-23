import 'dart:convert';

import 'package:test/test.dart';
import 'package:queue_monitor/models/cluster_config.dart';

void main() {
  test('parses jump-host config', () {
    final raw = jsonDecode('''
{
  "id": "cluster_demo",
  "name": "Demo",
  "management": {
    "host": "mgmt.example.edu",
    "port": 22,
    "user": "iaw",
    "auth": {"type": "private_key", "secret_id": "mgmt_key"}
  },
  "jump": {
    "enabled": true,
    "host": "jump.example.edu",
    "port": 2222,
    "user": "iaw",
    "auth": {"type": "password", "secret_id": "jump_password"}
  },
  "script": {"mode": "inline", "content": "#!/usr/bin/env bash\\n"},
  "timeout_sec": 20
}
''') as Map<String, dynamic>;

    final cluster = ClusterConfig.fromJson(raw);

    expect(cluster.name, 'Demo');
    expect(cluster.management.host, 'mgmt.example.edu');
    expect(cluster.management.auth.type, AuthType.privateKey);
    expect(cluster.jump.enabled, isTrue);
    expect(cluster.jump.endpoint.host, 'jump.example.edu');
    expect(cluster.jump.endpoint.auth.type, AuthType.password);
  });
}
