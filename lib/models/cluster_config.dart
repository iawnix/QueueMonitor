enum AuthType {
  password,
  privateKey,
}

AuthType authTypeFromString(String value) {
  switch (value) {
    case 'password':
      return AuthType.password;
    case 'key':
    case 'private_key':
      return AuthType.privateKey;
    default:
      throw FormatException('Unsupported auth type: $value');
  }
}

String authTypeToString(AuthType type) {
  return switch (type) {
    AuthType.password => 'password',
    AuthType.privateKey => 'private_key',
  };
}

class AuthRef {
  const AuthRef({
    required this.type,
    required this.secretId,
  });

  final AuthType type;
  final String secretId;

  factory AuthRef.fromJson(Map<String, dynamic> json) {
    final alias = json['secret_id'] ?? json['key_alias'] ?? json['password_alias'];
    return AuthRef(
      type: authTypeFromString(json['type'] as String? ?? 'private_key'),
      secretId: alias as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': authTypeToString(type),
      'secret_id': secretId,
    };
  }
}

class SshEndpoint {
  const SshEndpoint({
    required this.host,
    required this.port,
    required this.user,
    required this.auth,
  });

  final String host;
  final int port;
  final String user;
  final AuthRef auth;

  factory SshEndpoint.fromJson(Map<String, dynamic> json) {
    return SshEndpoint(
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 22,
      user: json['user'] as String? ?? '',
      auth: AuthRef.fromJson(json['auth'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'user': user,
      'auth': auth.toJson(),
    };
  }
}

class JumpHost {
  const JumpHost({
    required this.enabled,
    required this.endpoint,
  });

  final bool enabled;
  final SshEndpoint endpoint;

  factory JumpHost.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return JumpHost.disabled();
    }
    return JumpHost(
      enabled: json['enabled'] as bool? ?? false,
      endpoint: SshEndpoint.fromJson(json),
    );
  }

  factory JumpHost.disabled() {
    return const JumpHost(
      enabled: false,
      endpoint: SshEndpoint(
        host: '',
        port: 22,
        user: '',
        auth: AuthRef(type: AuthType.privateKey, secretId: ''),
      ),
    );
  }

  Map<String, dynamic>? toJson() {
    if (!enabled) {
      return {'enabled': false};
    }
    return {
      'enabled': true,
      ...endpoint.toJson(),
    };
  }
}

class ScriptConfig {
  const ScriptConfig({
    required this.content,
  });

  final String content;

  factory ScriptConfig.fromJson(Map<String, dynamic> json) {
    final mode = json['mode'] as String? ?? 'inline';
    if (mode != 'inline') {
      throw FormatException('Unsupported script mode: $mode');
    }
    return ScriptConfig(content: json['content'] as String? ?? '');
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': 'inline',
      'content': content,
    };
  }
}

class ClusterConfig {
  const ClusterConfig({
    required this.id,
    required this.name,
    required this.management,
    required this.jump,
    required this.script,
    required this.timeoutSec,
  });

  final String id;
  final String name;
  final SshEndpoint management;
  final JumpHost jump;
  final ScriptConfig script;
  final int timeoutSec;

  factory ClusterConfig.empty() {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return ClusterConfig(
      id: 'cluster_$id',
      name: '',
      management: SshEndpoint(
        host: '',
        port: 22,
        user: '',
        auth: AuthRef(type: AuthType.privateKey, secretId: 'cluster_${id}_key'),
      ),
      jump: JumpHost.disabled(),
      script: const ScriptConfig(content: defaultStatusScript),
      timeoutSec: 20,
    );
  }

  factory ClusterConfig.fromJson(Map<String, dynamic> json) {
    return ClusterConfig(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Cluster',
      management: SshEndpoint.fromJson(
        json['management'] as Map<String, dynamic>? ?? {},
      ),
      jump: JumpHost.fromJson(json['jump'] as Map<String, dynamic>?),
      script: ScriptConfig.fromJson(json['script'] as Map<String, dynamic>? ?? {}),
      timeoutSec: (json['timeout_sec'] as num?)?.toInt() ?? 20,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'management': management.toJson(),
      'jump': jump.toJson(),
      'script': script.toJson(),
      'timeout_sec': timeoutSec,
    };
  }

  ClusterConfig copyWith({
    String? id,
    String? name,
    SshEndpoint? management,
    JumpHost? jump,
    ScriptConfig? script,
    int? timeoutSec,
  }) {
    return ClusterConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      management: management ?? this.management,
      jump: jump ?? this.jump,
      script: script ?? this.script,
      timeoutSec: timeoutSec ?? this.timeoutSec,
    );
  }
}

const defaultStatusScript = r'''#!/usr/bin/env bash
set -euo pipefail

# Replace these commands with scheduler-specific logic.
cat <<'JSON'
{
  "schema_version": 1,
  "cluster": "example",
  "ok": true,
  "cpu": { "free": 0, "total": 0 },
  "gpu": { "free": 0, "total": 0 },
  "jobs": { "running": 0, "queued": 0 }
}
JSON
''';
