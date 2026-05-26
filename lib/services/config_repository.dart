import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cluster_config.dart';
import 'config_export.dart';
import 'config_import.dart';
import 'secret_store.dart';

class ConfigRepository {
  ConfigRepository({SecretStore? secretStore}) : _secretStore = secretStore;

  static const _clustersKey = 'queue_monitor.clusters.v1';

  final SecretStore? _secretStore;

  Future<List<ClusterConfig>> loadClusters() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_clustersKey);
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(ClusterConfig.fromJson)
        .toList(growable: false);
  }

  Future<void> saveClusters(List<ClusterConfig> clusters) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(
      clusters.map((cluster) => cluster.toJson()).toList(),
    );
    await prefs.setString(_clustersKey, raw);
  }

  Future<List<ClusterConfig>> importJson(String rawJson) async {
    final imported = parseImportedConfigJson(rawJson);
    if (imported.passwords.isNotEmpty) {
      final secretStore = _secretStore;
      if (secretStore == null) {
        throw StateError('Password import requires a secret store');
      }
      await storeImportedPasswords(imported.passwords, secretStore);
    }
    await saveClusters(imported.clusters);
    return imported.clusters;
  }

  String exportJson(List<ClusterConfig> clusters) {
    return exportConfigJson(clusters);
  }
}
