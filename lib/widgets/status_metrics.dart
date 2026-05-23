import 'package:flutter/material.dart';

import '../models/cluster_status.dart';

class StatusMetricGrid extends StatelessWidget {
  const StatusMetricGrid({super.key, required this.status});

  final ClusterStatus status;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricSpec(
        icon: Icons.memory,
        label: 'CPU',
        value: '${status.cpuFree}/${status.cpuTotal}',
        color: const Color(0xff2563eb),
      ),
      _MetricSpec(
        icon: Icons.developer_board,
        label: 'GPU',
        value: '${status.gpuFree}/${status.gpuTotal}',
        color: const Color(0xff7c3aed),
      ),
      _MetricSpec(
        icon: Icons.play_arrow_rounded,
        label: 'RUN',
        value: '${status.jobsRunning}',
        color: const Color(0xff16a34a),
      ),
      _MetricSpec(
        icon: Icons.schedule,
        label: 'PEND',
        value: '${status.jobsQueued}',
        color: const Color(0xffca8a04),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final columns = constraints.maxWidth >= 520 ? 4 : 2;
        final width =
            ((constraints.maxWidth - spacing * (columns - 1)) / columns)
                .clamp(120.0, 190.0)
                .toDouble();
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _MetricTile(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _MetricSpec {
  const _MetricSpec({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric});

  final _MetricSpec metric;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metric.icon, size: 18, color: metric.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  metric.label,
                  style: Theme.of(context).textTheme.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                metric.value,
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
