import 'package:flutter/material.dart';

import '../models/cluster_config.dart';
import '../models/cluster_status.dart';
import '../widgets/status_metrics.dart';

class ClusterDetailScreen extends StatelessWidget {
  const ClusterDetailScreen({
    super.key,
    required this.cluster,
    required this.result,
    required this.onRefresh,
  });

  final ClusterConfig cluster;
  final ClusterPollResult? result;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final status = result?.status;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          cluster.name.isEmpty ? cluster.management.host : cluster.name,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoTile(
            label: 'Management',
            value:
                '${cluster.management.user}@${cluster.management.host}:${cluster.management.port}',
          ),
          _InfoTile(
            label: 'Jump host',
            value: cluster.jump.enabled
                ? '${cluster.jump.endpoint.user}@${cluster.jump.endpoint.host}:${cluster.jump.endpoint.port}'
                : 'Disabled',
          ),
          _InfoTile(label: 'Timeout', value: '${cluster.timeoutSec}s'),
          const SizedBox(height: 12),
          if (status != null) ...[
            _MetricsPanel(status: status),
            const SizedBox(height: 16),
            Text('Raw JSON', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _CodeBlock(text: status.rawJson),
          ] else ...[
            _CodeBlock(text: result?.error ?? 'No status yet'),
          ],
          if ((result?.stderr ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('stderr', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _CodeBlock(text: result!.stderr),
          ],
        ],
      ),
    );
  }
}

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({required this.status});

  final ClusterStatus status;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            StatusMetricGrid(status: status),
            const Divider(height: 24),
            _MetricRow(
              label: 'Checked',
              value: status.checkedAt.toLocal().toString(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }
}
