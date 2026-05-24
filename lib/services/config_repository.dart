import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cluster_config.dart';
import 'config_export.dart';

class ConfigRepository {
  static const _clustersKey = 'queue_monitor.clusters.v1';

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
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final version = (decoded['version'] as num?)?.toInt() ?? 1;
    if (version != 1) {
      throw FormatException('Unsupported config version: $version');
    }
    final clustersRaw = decoded['clusters'] as List<dynamic>? ?? [];
    final clusters = clustersRaw
        .cast<Map<String, dynamic>>()
        .map(ClusterConfig.fromJson)
        .toList(growable: false);
    await saveClusters(clusters);
    return clusters;
  }

  String exportJson(List<ClusterConfig> clusters) {
    return exportConfigJson(clusters);
  }
}
