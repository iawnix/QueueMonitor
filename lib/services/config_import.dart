import 'dart:convert';

import '../models/cluster_config.dart';
import 'secret_store.dart';

class ImportedConfig {
  const ImportedConfig({required this.clusters, required this.passwords});

  final List<ClusterConfig> clusters;
  final List<ImportedPassword> passwords;
}

class ImportedPassword {
  const ImportedPassword({required this.auth, required this.password});

  final AuthRef auth;
  final String password;
}

ImportedConfig parseImportedConfigJson(String rawJson) {
  final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
  final version = (decoded['version'] as num?)?.toInt() ?? 1;
  if (version != 1) {
    throw FormatException('Unsupported config version: $version');
  }
  final rawClusterObjects = (decoded['clusters'] as List<dynamic>? ?? [])
      .cast<Map<String, dynamic>>()
      .toList(growable: false);
  final clustersRaw = rawClusterObjects
      .asMap()
      .entries
      .map((entry) => _normalizeImportedClusterJson(entry.value, entry.key))
      .toList(growable: false);
  final clusters = clustersRaw
      .map(ClusterConfig.fromJson)
      .toList(growable: false);
  return ImportedConfig(
    clusters: clusters,
    passwords: _collectImportPasswords(clustersRaw, clusters),
  );
}

Future<void> storeImportedPasswords(
  Iterable<ImportedPassword> passwords,
  SecretStore secretStore,
) async {
  for (final password in passwords) {
    await secretStore.writePassword(password.auth.secretId, password.password);
  }
}

Map<String, dynamic> _normalizeImportedClusterJson(
  Map<String, dynamic> raw,
  int index,
) {
  final normalized = jsonDecode(jsonEncode(raw)) as Map<String, dynamic>;
  final clusterId = normalized['id'] as String? ?? 'cluster_${index + 1}';
  _ensureImportPasswordSecretId(
    normalized['management'],
    _fallbackSecretId(clusterId, 'management'),
  );
  final jump = normalized['jump'];
  if (jump is Map<String, dynamic> && (jump['enabled'] as bool? ?? false)) {
    _ensureImportPasswordSecretId(jump, _fallbackSecretId(clusterId, 'jump'));
  }
  return normalized;
}

void _ensureImportPasswordSecretId(Object? endpoint, String fallbackSecretId) {
  final auth = _endpointAuthJson(endpoint);
  if (auth == null) {
    return;
  }
  final password = auth['password'];
  if (password is! String || password.isEmpty) {
    return;
  }
  final explicitAlias =
      auth['secret_id'] ?? auth['password_alias'] ?? auth['key_alias'];
  if (explicitAlias is String && explicitAlias.trim().isNotEmpty) {
    return;
  }
  auth['secret_id'] = fallbackSecretId;
}

List<ImportedPassword> _collectImportPasswords(
  List<Map<String, dynamic>> clustersRaw,
  List<ClusterConfig> clusters,
) {
  final passwords = <ImportedPassword>[];
  for (var i = 0; i < clusters.length; i++) {
    final cluster = clusters[i];
    final raw = clustersRaw[i];
    _addEndpointImportPassword(
      passwords,
      raw['management'],
      cluster.management.auth,
    );
    if (cluster.jump.enabled) {
      _addEndpointImportPassword(
        passwords,
        raw['jump'],
        cluster.jump.endpoint.auth,
      );
    }
  }
  return passwords;
}

void _addEndpointImportPassword(
  List<ImportedPassword> passwords,
  Object? endpoint,
  AuthRef auth,
) {
  if (auth.type != AuthType.password || auth.secretId.trim().isEmpty) {
    return;
  }
  final password = _endpointAuthJson(endpoint)?['password'];
  if (password is String && password.isNotEmpty) {
    passwords.add(ImportedPassword(auth: auth, password: password));
  }
}

Map<String, dynamic>? _endpointAuthJson(Object? endpoint) {
  if (endpoint is! Map<String, dynamic>) {
    return null;
  }
  final auth = endpoint['auth'];
  return auth is Map<String, dynamic> ? auth : null;
}

String _fallbackSecretId(String clusterId, String role) {
  final id = clusterId
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final idPart = id.isEmpty ? 'cluster' : id;
  return 'import_${idPart}_${role}_password';
}
