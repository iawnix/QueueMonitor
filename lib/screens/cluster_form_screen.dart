import 'package:flutter/material.dart';

import '../models/cluster_config.dart';
import '../services/secure_secret_store.dart';

class ClusterFormScreen extends StatefulWidget {
  const ClusterFormScreen({super.key, required this.cluster});

  final ClusterConfig cluster;

  @override
  State<ClusterFormScreen> createState() => _ClusterFormScreenState();
}

class _ClusterFormScreenState extends State<ClusterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _secretStore = SecureSecretStore();

  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _secretId;
  late final TextEditingController _password;
  late final TextEditingController _privateKey;
  late final TextEditingController _passphrase;
  late final TextEditingController _script;
  late final TextEditingController _timeout;

  late bool _jumpEnabled;
  late final TextEditingController _jumpHost;
  late final TextEditingController _jumpPort;
  late final TextEditingController _jumpUser;
  late final TextEditingController _jumpSecretId;
  late final TextEditingController _jumpPassword;
  late final TextEditingController _jumpPrivateKey;
  late final TextEditingController _jumpPassphrase;

  late AuthType _authType;
  late AuthType _jumpAuthType;

  @override
  void initState() {
    super.initState();
    final cluster = widget.cluster;
    _name = TextEditingController(text: cluster.name);
    _host = TextEditingController(text: cluster.management.host);
    _port = TextEditingController(text: cluster.management.port.toString());
    _user = TextEditingController(text: cluster.management.user);
    _secretId = TextEditingController(text: cluster.management.auth.secretId);
    _password = TextEditingController();
    _privateKey = TextEditingController();
    _passphrase = TextEditingController();
    _script = TextEditingController(text: cluster.script.content);
    _timeout = TextEditingController(text: cluster.timeoutSec.toString());
    _authType = cluster.management.auth.type;

    _jumpEnabled = cluster.jump.enabled;
    _jumpHost = TextEditingController(text: cluster.jump.endpoint.host);
    _jumpPort = TextEditingController(
      text: cluster.jump.endpoint.port.toString(),
    );
    _jumpUser = TextEditingController(text: cluster.jump.endpoint.user);
    _jumpSecretId = TextEditingController(
      text: cluster.jump.endpoint.auth.secretId,
    );
    _jumpPassword = TextEditingController();
    _jumpPrivateKey = TextEditingController();
    _jumpPassphrase = TextEditingController();
    _jumpAuthType = cluster.jump.endpoint.auth.type;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _host,
      _port,
      _user,
      _secretId,
      _password,
      _privateKey,
      _passphrase,
      _script,
      _timeout,
      _jumpHost,
      _jumpPort,
      _jumpUser,
      _jumpSecretId,
      _jumpPassword,
      _jumpPrivateKey,
      _jumpPassphrase,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final managementAuth = AuthRef(
      type: _authType,
      secretId: _secretId.text.trim(),
    );
    final jumpAuth = AuthRef(
      type: _jumpAuthType,
      secretId: _jumpSecretId.text.trim(),
    );

    await _persistSecret(
      managementAuth,
      password: _password.text,
      privateKey: _privateKey.text,
      passphrase: _passphrase.text,
    );
    if (_jumpEnabled) {
      await _persistSecret(
        jumpAuth,
        password: _jumpPassword.text,
        privateKey: _jumpPrivateKey.text,
        passphrase: _jumpPassphrase.text,
      );
    }

    final cluster = widget.cluster.copyWith(
      name: _name.text.trim(),
      management: SshEndpoint(
        host: _host.text.trim(),
        port: int.parse(_port.text.trim()),
        user: _user.text.trim(),
        auth: managementAuth,
      ),
      jump: _jumpEnabled
          ? JumpHost(
              enabled: true,
              endpoint: SshEndpoint(
                host: _jumpHost.text.trim(),
                port: int.parse(_jumpPort.text.trim()),
                user: _jumpUser.text.trim(),
                auth: jumpAuth,
              ),
            )
          : JumpHost.disabled(),
      script: ScriptConfig(content: _script.text),
      timeoutSec: int.parse(_timeout.text.trim()),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(cluster);
  }

  Future<void> _persistSecret(
    AuthRef auth, {
    required String password,
    required String privateKey,
    required String passphrase,
  }) async {
    if (auth.type == AuthType.password && password.isNotEmpty) {
      await _secretStore.writePassword(auth.secretId, password);
    } else if (auth.type == AuthType.privateKey && privateKey.isNotEmpty) {
      await _secretStore.writePrivateKey(
        auth.secretId,
        privateKey,
        passphrase: passphrase,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.cluster.name.isEmpty ? 'Cluster' : widget.cluster.name,
        ),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _save,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Cluster', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _TextField(controller: _name, label: 'Name', required: true),
            _TextField(
              controller: _host,
              label: 'Management host',
              required: true,
            ),
            Row(
              children: [
                Expanded(
                  child: _TextField(
                    controller: _port,
                    label: 'Port',
                    required: true,
                    number: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TextField(
                    controller: _user,
                    label: 'User',
                    required: true,
                  ),
                ),
              ],
            ),
            _AuthFields(
              authType: _authType,
              onAuthTypeChanged: (value) => setState(() => _authType = value),
              secretId: _secretId,
              password: _password,
              privateKey: _privateKey,
              passphrase: _passphrase,
            ),
            const Divider(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _jumpEnabled,
              onChanged: (value) => setState(() => _jumpEnabled = value),
              title: const Text('Jump host'),
            ),
            if (_jumpEnabled) ...[
              _TextField(
                controller: _jumpHost,
                label: 'Jump host',
                required: true,
              ),
              Row(
                children: [
                  Expanded(
                    child: _TextField(
                      controller: _jumpPort,
                      label: 'Port',
                      required: true,
                      number: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TextField(
                      controller: _jumpUser,
                      label: 'User',
                      required: true,
                    ),
                  ),
                ],
              ),
              _AuthFields(
                authType: _jumpAuthType,
                onAuthTypeChanged: (value) =>
                    setState(() => _jumpAuthType = value),
                secretId: _jumpSecretId,
                password: _jumpPassword,
                privateKey: _jumpPrivateKey,
                passphrase: _jumpPassphrase,
              ),
            ],
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Script',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: _TextField(
                    controller: _timeout,
                    label: 'Timeout',
                    required: true,
                    number: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _script,
              maxLines: 18,
              minLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Bash script',
              ),
              style: const TextStyle(fontFamily: 'monospace'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthFields extends StatelessWidget {
  const _AuthFields({
    required this.authType,
    required this.onAuthTypeChanged,
    required this.secretId,
    required this.password,
    required this.privateKey,
    required this.passphrase,
  });

  final AuthType authType;
  final ValueChanged<AuthType> onAuthTypeChanged;
  final TextEditingController secretId;
  final TextEditingController password;
  final TextEditingController privateKey;
  final TextEditingController passphrase;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SegmentedButton<AuthType>(
          segments: const [
            ButtonSegment(
              value: AuthType.privateKey,
              icon: Icon(Icons.key),
              label: Text('Key'),
            ),
            ButtonSegment(
              value: AuthType.password,
              icon: Icon(Icons.password),
              label: Text('Password'),
            ),
          ],
          selected: {authType},
          onSelectionChanged: (selected) => onAuthTypeChanged(selected.first),
        ),
        const SizedBox(height: 10),
        _TextField(
          controller: secretId,
          label: 'Credential alias',
          required: true,
        ),
        if (authType == AuthType.password)
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Password',
            ),
          )
        else ...[
          TextField(
            controller: privateKey,
            maxLines: 6,
            minLines: 3,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Private key PEM',
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passphrase,
            obscureText: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Passphrase',
            ),
          ),
        ],
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.required = false,
    this.number = false,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final bool number;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'Required';
          }
          if (number && int.tryParse(value ?? '') == null) {
            return 'Invalid number';
          }
          return null;
        },
      ),
    );
  }
}
