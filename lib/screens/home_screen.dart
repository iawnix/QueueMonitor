import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/cluster_config.dart';
import '../models/cluster_status.dart';
import '../services/config_repository.dart';
import '../services/secure_secret_store.dart';
import '../services/ssh_queue_client.dart';
import '../widgets/status_metrics.dart';
import 'cluster_detail_screen.dart';
import 'cluster_form_screen.dart';
import 'import_config_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = ConfigRepository();
  final _client = SshQueueClient();
  final _secretStore = SecureSecretStore();

  List<ClusterConfig> _clusters = [];
  Map<String, ClusterPollResult> _results = {};
  Set<String> _refreshing = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final clusters = await _repository.loadClusters();
    if (!mounted) {
      return;
    }
    setState(() {
      _clusters = clusters;
      _loading = false;
    });
  }

  Future<void> _save(List<ClusterConfig> clusters) async {
    await _repository.saveClusters(clusters);
    if (!mounted) {
      return;
    }
    setState(() {
      _clusters = clusters;
    });
  }

  Future<ClusterPollResult> _refreshCluster(ClusterConfig cluster) async {
    setState(() {
      _refreshing = {..._refreshing, cluster.id};
    });
    try {
      final result = await _client.poll(cluster);
      if (mounted) {
        setState(() {
          _results = {..._results, cluster.id: result};
        });
      }
      return result;
    } catch (error) {
      final result = ClusterPollResult.failure(error: error.toString());
      if (mounted) {
        setState(() {
          _results = {..._results, cluster.id: result};
        });
      }
      return result;
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = {..._refreshing}..remove(cluster.id);
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait(_clusters.map(_refreshCluster));
  }

  Future<void> _openForm([ClusterConfig? cluster]) async {
    final edited = await Navigator.of(context).push<ClusterConfig>(
      MaterialPageRoute(
        builder: (_) =>
            ClusterFormScreen(cluster: cluster ?? ClusterConfig.empty()),
      ),
    );
    if (edited == null) {
      return;
    }
    final existing = _clusters.indexWhere((item) => item.id == edited.id);
    final next = [..._clusters];
    if (existing >= 0) {
      next[existing] = edited;
    } else {
      next.add(edited);
    }
    await _save(next);
    if (!mounted) {
      return;
    }
    setState(() {
      _results = {..._results}..remove(edited.id);
    });
  }

  Future<void> _deleteCluster(ClusterConfig cluster) async {
    final clearCredentials = await _confirmDeleteCluster(cluster);
    if (clearCredentials == null) {
      return;
    }
    final next = _clusters.where((item) => item.id != cluster.id).toList();
    await _save(next);
    if (clearCredentials) {
      await _clearUnusedSecrets(cluster, next);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _results = {..._results}..remove(cluster.id);
    });
  }

  Future<void> _importConfig() async {
    final imported = await Navigator.of(context).push<List<ClusterConfig>>(
      MaterialPageRoute(builder: (_) => const ImportConfigScreen()),
    );
    if (imported == null) {
      return;
    }
    await _save(imported);
    if (!mounted) {
      return;
    }
    final importedIds = imported.map((cluster) => cluster.id).toSet();
    setState(() {
      _results = Map.fromEntries(
        _results.entries.where((entry) => importedIds.contains(entry.key)),
      );
    });
  }

  Future<void> _exportConfig() async {
    final exported = _repository.exportJson(_clusters);
    await Clipboard.setData(ClipboardData(text: exported));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Config copied to clipboard')));
  }

  Future<bool?> _confirmDeleteCluster(ClusterConfig cluster) {
    var clearCredentials = true;
    return showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete cluster?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_clusterTitle(cluster)),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: clearCredentials,
                onChanged: (value) {
                  setDialogState(() {
                    clearCredentials = value ?? true;
                  });
                },
                title: const Text('Clear unused saved credentials'),
                subtitle: const Text(
                  'Shared aliases used by other clusters are kept.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(clearCredentials),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearUnusedSecrets(
    ClusterConfig deleted,
    List<ClusterConfig> remaining,
  ) async {
    final remainingSecretIds = _secretIdsForClusters(remaining).toSet();
    final deletedSecretIds = _secretIdsForCluster(deleted).toSet();
    for (final secretId in deletedSecretIds) {
      if (!remainingSecretIds.contains(secretId)) {
        await _secretStore.clearSecret(secretId);
      }
    }
  }

  Iterable<String> _secretIdsForClusters(List<ClusterConfig> clusters) sync* {
    for (final cluster in clusters) {
      yield* _secretIdsForCluster(cluster);
    }
  }

  Iterable<String> _secretIdsForCluster(ClusterConfig cluster) sync* {
    final managementId = cluster.management.auth.secretId.trim();
    if (managementId.isNotEmpty) {
      yield managementId;
    }
    if (cluster.jump.enabled) {
      final jumpId = cluster.jump.endpoint.auth.secretId.trim();
      if (jumpId.isNotEmpty) {
        yield jumpId;
      }
    }
  }

  String _clusterTitle(ClusterConfig cluster) {
    return cluster.name.isEmpty ? cluster.management.host : cluster.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QueueMonitor'),
        actions: [
          IconButton(
            tooltip: 'Import config',
            onPressed: _importConfig,
            icon: const Icon(Icons.upload_file),
          ),
          IconButton(
            tooltip: 'Export config',
            onPressed: _loading ? null : _exportConfig,
            icon: const Icon(Icons.download),
          ),
          IconButton(
            tooltip: 'Refresh all',
            onPressed: _clusters.isEmpty ? null : _refreshAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_clusters.isEmpty) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Add cluster'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _clusters.length,
        itemBuilder: (context, index) {
          final cluster = _clusters[index];
          return _ClusterCard(
            cluster: cluster,
            result: _results[cluster.id],
            refreshing: _refreshing.contains(cluster.id),
            onRefresh: () => _refreshCluster(cluster),
            onEdit: () => _openForm(cluster),
            onDelete: () => _deleteCluster(cluster),
            onOpen: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ClusterDetailScreen(
                    cluster: cluster,
                    result: _results[cluster.id],
                    onRefresh: _refreshCluster,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ClusterCard extends StatelessWidget {
  const _ClusterCard({
    required this.cluster,
    required this.result,
    required this.refreshing,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });

  final ClusterConfig cluster;
  final ClusterPollResult? result;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final status = result?.status;
    final online = result?.isOnline ?? false;
    final color = result == null
        ? Theme.of(context).colorScheme.outline
        : online
        ? const Color(0xff16a34a)
        : const Color(0xffdc2626);
    return Card(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, color: color, size: 12),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cluster.name.isEmpty
                          ? cluster.management.host
                          : cluster.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (refreshing)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${cluster.management.user}@${cluster.management.host}:${cluster.management.port}'
                '${cluster.jump.enabled ? ' via ${cluster.jump.endpoint.host}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              if (status == null)
                Text(
                  result?.error ?? 'Not checked',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: result?.error == null ? null : color,
                  ),
                )
              else
                StatusMetricGrid(status: status),
            ],
          ),
        ),
      ),
    );
  }
}
