import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/cluster_config.dart';

class AuthMaterial {
  const AuthMaterial({
    this.password,
    this.privateKeyPem,
    this.passphrase,
  });

  final String? password;
  final String? privateKeyPem;
  final String? passphrase;
}

class SecureSecretStore {
  SecureSecretStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static String _passwordKey(String secretId) => 'secret.$secretId.password';
  static String _keyPemKey(String secretId) => 'secret.$secretId.private_key_pem';
  static String _passphraseKey(String secretId) => 'secret.$secretId.passphrase';

  Future<AuthMaterial> read(AuthRef ref) async {
    final password = await _storage.read(key: _passwordKey(ref.secretId));
    final privateKeyPem = await _storage.read(key: _keyPemKey(ref.secretId));
    final passphrase = await _storage.read(key: _passphraseKey(ref.secretId));
    return AuthMaterial(
      password: password,
      privateKeyPem: privateKeyPem,
      passphrase: passphrase,
    );
  }

  Future<void> writePassword(String secretId, String password) async {
    await _storage.write(key: _passwordKey(secretId), value: password);
  }

  Future<void> writePrivateKey(
    String secretId,
    String privateKeyPem, {
    String? passphrase,
  }) async {
    await _storage.write(key: _keyPemKey(secretId), value: privateKeyPem);
    if (passphrase != null && passphrase.isNotEmpty) {
      await _storage.write(key: _passphraseKey(secretId), value: passphrase);
    }
  }

  Future<void> clearSecret(String secretId) async {
    await _storage.delete(key: _passwordKey(secretId));
    await _storage.delete(key: _keyPemKey(secretId));
    await _storage.delete(key: _passphraseKey(secretId));
  }
}
