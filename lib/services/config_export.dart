import 'dart:convert';

import '../models/cluster_config.dart';

String exportConfigJson(List<ClusterConfig> clusters) {
  return const JsonEncoder.withIndent('  ').convert({
    'version': 1,
    'clusters': clusters.map((cluster) => cluster.toJson()).toList(),
  });
}
