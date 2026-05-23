import 'package:flutter/material.dart';

import '../models/cluster_config.dart';
import '../models/cluster_status.dart';
import '../widgets/status_metrics.dart';

class ClusterDetailScreen extends StatefulWidget {
  const ClusterDetailScreen({
    super.key,
    required this.cluster,
    required this.result,
    required this.onRefresh,
  });

  final ClusterConfig cluster;
  final ClusterPollResult? result;
  final Future<ClusterPollResult> Function(ClusterConfig cluster) onRefresh;

  @override
  State<ClusterDetailScreen> createState() => _ClusterDetailScreenState();
}

class _ClusterDetailScreenState extends State<ClusterDetailScreen> {
  late ClusterPollResult? _result;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _result = widget.result;
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
    });
    final result = await widget.onRefresh(widget.cluster);
    if (!mounted) {
      return;
    }
    setState(() {
      _result = result;
      _refreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _result?.status;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.cluster.name.isEmpty
              ? widget.cluster.management.host
              : widget.cluster.name,
        ),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refresh,
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
                '${widget.cluster.management.user}@${widget.cluster.management.host}:${widget.cluster.management.port}',
          ),
          _InfoTile(
            label: 'Jump host',
            value: widget.cluster.jump.enabled
                ? '${widget.cluster.jump.endpoint.user}@${widget.cluster.jump.endpoint.host}:${widget.cluster.jump.endpoint.port}'
                : 'Disabled',
          ),
          _InfoTile(label: 'Timeout', value: '${widget.cluster.timeoutSec}s'),
          const SizedBox(height: 12),
          if (status != null) ...[
            _MetricsPanel(status: status),
            const SizedBox(height: 16),
            Text('Raw JSON', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _CodeBlock(text: status.rawJson),
          ] else ...[
            _CodeBlock(text: _result?.error ?? 'No status yet'),
          ],
          if ((_result?.stderr ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('stderr', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _CodeBlock(text: _result!.stderr),
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
