import 'dart:convert';

class ClusterStatus {
  const ClusterStatus({
    required this.schemaVersion,
    required this.cluster,
    required this.ok,
    required this.cpuFree,
    required this.cpuTotal,
    required this.gpuFree,
    required this.gpuTotal,
    required this.jobsRunning,
    required this.jobsQueued,
    required this.rawJson,
    required this.checkedAt,
  });

  final int schemaVersion;
  final String cluster;
  final bool ok;
  final int cpuFree;
  final int cpuTotal;
  final int gpuFree;
  final int gpuTotal;
  final int jobsRunning;
  final int jobsQueued;
  final String rawJson;
  final DateTime checkedAt;

  factory ClusterStatus.fromStdout(String stdout) {
    final decoded = jsonDecode(stdout) as Map<String, dynamic>;
    final cpu = decoded['cpu'] as Map<String, dynamic>? ?? {};
    final gpu = decoded['gpu'] as Map<String, dynamic>? ?? {};
    final jobs = decoded['jobs'] as Map<String, dynamic>? ?? {};
    final version = (decoded['schema_version'] as num?)?.toInt() ?? 0;
    if (version != 1) {
      throw FormatException('Unsupported schema_version: $version');
    }
    return ClusterStatus(
      schemaVersion: version,
      cluster: decoded['cluster'] as String? ?? '',
      ok: decoded['ok'] as bool? ?? true,
      cpuFree: _asInt(cpu['free']),
      cpuTotal: _asInt(cpu['total']),
      gpuFree: _asInt(gpu['free']),
      gpuTotal: _asInt(gpu['total']),
      jobsRunning: _asInt(jobs['running']),
      jobsQueued: _asInt(jobs['queued']),
      rawJson: const JsonEncoder.withIndent('  ').convert(decoded),
      checkedAt: DateTime.now(),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}

class ClusterPollResult {
  const ClusterPollResult({
    required this.status,
    required this.error,
    required this.exitCode,
    required this.stderr,
    required this.checkedAt,
  });

  final ClusterStatus? status;
  final String? error;
  final int? exitCode;
  final String stderr;
  final DateTime checkedAt;

  bool get isOnline => status != null && error == null;

  factory ClusterPollResult.success(ClusterStatus status, {String stderr = ''}) {
    return ClusterPollResult(
      status: status,
      error: null,
      exitCode: 0,
      stderr: stderr,
      checkedAt: DateTime.now(),
    );
  }

  factory ClusterPollResult.failure({
    required String error,
    int? exitCode,
    String stderr = '',
  }) {
    return ClusterPollResult(
      status: null,
      error: error,
      exitCode: exitCode,
      stderr: stderr,
      checkedAt: DateTime.now(),
    );
  }
}
