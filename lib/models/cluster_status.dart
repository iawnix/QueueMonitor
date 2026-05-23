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
    final decodedRaw = jsonDecode(stdout);
    if (decodedRaw is! Map<String, dynamic>) {
      throw const FormatException('stdout must be one JSON object');
    }
    final decoded = decodedRaw;
    final cpu = _requiredObject(decoded, 'cpu');
    final gpu = _requiredObject(decoded, 'gpu');
    final jobs = _requiredObject(decoded, 'jobs');
    final version = _requiredInt(decoded, 'schema_version');
    if (version != 1) {
      throw FormatException('Unsupported schema_version: $version');
    }
    final ok = _requiredBool(decoded, 'ok');
    final cpuFree = _requiredInt(cpu, 'cpu.free');
    final cpuTotal = _requiredInt(cpu, 'cpu.total');
    final gpuFree = _requiredInt(gpu, 'gpu.free');
    final gpuTotal = _requiredInt(gpu, 'gpu.total');
    final jobsRunning = _requiredInt(jobs, 'jobs.running');
    final jobsQueued = _requiredInt(jobs, 'jobs.queued');
    _validateCapacity('cpu', cpuFree, cpuTotal);
    _validateCapacity('gpu', gpuFree, gpuTotal);
    return ClusterStatus(
      schemaVersion: version,
      cluster: _requiredString(decoded, 'cluster'),
      ok: ok,
      cpuFree: cpuFree,
      cpuTotal: cpuTotal,
      gpuFree: gpuFree,
      gpuTotal: gpuTotal,
      jobsRunning: jobsRunning,
      jobsQueued: jobsQueued,
      rawJson: const JsonEncoder.withIndent('  ').convert(decoded),
      checkedAt: DateTime.now(),
    );
  }

  static Map<String, dynamic> _requiredObject(
    Map<String, dynamic> json,
    String field,
  ) {
    final value = json[field];
    if (value is Map<String, dynamic>) {
      return value;
    }
    throw FormatException('Missing object field: $field');
  }

  static String _requiredString(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FormatException('Missing string field: $field');
  }

  static bool _requiredBool(Map<String, dynamic> json, String field) {
    final value = json[field];
    if (value is bool) {
      return value;
    }
    throw FormatException('Missing boolean field: $field');
  }

  static int _requiredInt(Map<String, dynamic> json, String field) {
    final key = field.split('.').last;
    final value = json[key];
    if (value is int && value >= 0) {
      return value;
    }
    throw FormatException('Missing non-negative integer field: $field');
  }

  static void _validateCapacity(String label, int free, int total) {
    if (free > total) {
      throw FormatException('$label.free cannot exceed $label.total');
    }
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

  bool get isOnline => status?.ok == true && error == null;

  factory ClusterPollResult.success(
    ClusterStatus status, {
    String stderr = '',
  }) {
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
