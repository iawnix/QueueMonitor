import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import '../models/cluster_config.dart';
import '../models/cluster_status.dart';
import 'secure_secret_store.dart';

class SshQueueClient {
  SshQueueClient({SecureSecretStore? secretStore})
    : _secretStore = secretStore ?? SecureSecretStore();

  final SecureSecretStore _secretStore;

  Future<ClusterPollResult> poll(ClusterConfig cluster) async {
    SSHClient? jumpClient;
    SSHClient? targetClient;
    try {
      final timeout = Duration(seconds: cluster.timeoutSec);

      if (cluster.jump.enabled) {
        jumpClient = await _connect(cluster.jump.endpoint).timeout(timeout);
        final forwardedSocket = await jumpClient
            .forwardLocal(cluster.management.host, cluster.management.port)
            .timeout(timeout);
        targetClient = await _connectWithSocket(
          forwardedSocket,
          cluster.management,
        ).timeout(timeout);
      } else {
        targetClient = await _connect(cluster.management).timeout(timeout);
      }

      final command = _wrapScript(cluster.script.content);
      final result = await targetClient.runWithResult(command).timeout(timeout);
      final stdout = utf8.decode(result.stdout).trim();
      final stderr = utf8.decode(result.stderr).trim();
      if (result.exitCode != 0) {
        return ClusterPollResult.failure(
          error: 'Script exited with ${result.exitCode}',
          exitCode: result.exitCode,
          stderr: stderr,
        );
      }
      final status = ClusterStatus.fromStdout(stdout);
      return ClusterPollResult.success(status, stderr: stderr);
    } on TimeoutException {
      return ClusterPollResult.failure(error: 'Connection or script timed out');
    } on FormatException catch (error) {
      return ClusterPollResult.failure(error: 'Invalid script JSON: $error');
    } on Object catch (error) {
      return ClusterPollResult.failure(error: error.toString());
    } finally {
      targetClient?.close();
      jumpClient?.close();
    }
  }

  Future<SSHClient> _connect(SshEndpoint endpoint) async {
    final socket = await SSHSocket.connect(endpoint.host, endpoint.port);
    return _connectWithSocket(socket, endpoint);
  }

  Future<SSHClient> _connectWithSocket(
    SSHSocket socket,
    SshEndpoint endpoint,
  ) async {
    final auth = await _secretStore.read(endpoint.auth);
    if (endpoint.auth.type == AuthType.password) {
      final password = auth.password;
      if (password == null || password.isEmpty) {
        throw StateError('Missing password for ${endpoint.auth.secretId}');
      }
      return SSHClient(
        socket,
        username: endpoint.user,
        onPasswordRequest: () => password,
      );
    }

    final privateKeyPem = auth.privateKeyPem;
    if (privateKeyPem == null || privateKeyPem.isEmpty) {
      throw StateError('Missing private key for ${endpoint.auth.secretId}');
    }
    final keyPairs = SSHKeyPair.fromPem(privateKeyPem, auth.passphrase);
    return SSHClient(socket, username: endpoint.user, identities: keyPairs);
  }

  String _wrapScript(String script) {
    final encoded = base64.encode(utf8.encode(script));
    return "base64 -d <<'QUEUE_MONITOR_SCRIPT' | bash\n"
        '$encoded\n'
        'QUEUE_MONITOR_SCRIPT';
  }
}
