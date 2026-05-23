import 'package:flutter_test/flutter_test.dart';
import 'package:queue_monitor/models/cluster_status.dart';

void main() {
  test('parses schema version 1 status JSON', () {
    final status = ClusterStatus.fromStdout('''
{
  "schema_version": 1,
  "cluster": "demo",
  "ok": true,
  "cpu": {"free": 8, "total": 16},
  "gpu": {"free": 2, "total": 4},
  "jobs": {"running": 3, "queued": 5}
}
''');

    expect(status.cluster, 'demo');
    expect(status.cpuFree, 8);
    expect(status.cpuTotal, 16);
    expect(status.gpuFree, 2);
    expect(status.gpuTotal, 4);
    expect(status.jobsRunning, 3);
    expect(status.jobsQueued, 5);
  });

  test('rejects unsupported schema version', () {
    expect(
      () => ClusterStatus.fromStdout('{"schema_version": 2}'),
      throwsFormatException,
    );
  });
}
