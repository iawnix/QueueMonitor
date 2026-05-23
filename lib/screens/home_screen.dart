import 'package:flutter/material.dart';

import '../models/cluster_config.dart';
import '../models/cluster_status.dart';
import '../services/config_repository.dart';
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

  Future<void> _refreshCluster(ClusterConfig cluster) async {
    setState(() {
      _refreshing = {..._refreshing, cluster.id};
    });
    final result = await _client.poll(cluster);
    if (!mounted) {
      return;
    }
    setState(() {
      _results = {..._results, cluster.id: result};
      _refreshing = {..._refreshing}..remove(cluster.id);
    });
  }

  Future<void> _refreshAll() async {
    for (final cluster in _clusters) {
      await _refreshCluster(cluster);
    }
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
  }

  Future<void> _deleteCluster(ClusterConfig cluster) async {
    final next = _clusters.where((item) => item.id != cluster.id).toList();
    await _save(next);
  }

  Future<void> _importConfig() async {
    final imported = await Navigator.of(context).push<List<ClusterConfig>>(
      MaterialPageRoute(builder: (_) => const ImportConfigScreen()),
    );
    if (imported == null) {
      return;
    }
    await _save(imported);
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
                    onRefresh: () => _refreshCluster(cluster),
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
