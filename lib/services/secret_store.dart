import '../models/cluster_config.dart';

class AuthMaterial {
  const AuthMaterial({this.password, this.privateKeyPem, this.passphrase});

  final String? password;
  final String? privateKeyPem;
  final String? passphrase;
}

abstract class SecretStore {
  Future<AuthMaterial> read(AuthRef ref);

  Future<void> writePassword(String secretId, String password);

  Future<void> writePrivateKey(
    String secretId,
    String privateKeyPem, {
    String? passphrase,
  });

  Future<void> clearSecret(String secretId);
}
