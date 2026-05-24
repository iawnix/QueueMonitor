import 'package:flutter/material.dart';

import '../models/cluster_config.dart';
import '../services/secure_secret_store.dart';
import 'script_editor_screen.dart';

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
      secretId: _effectiveSecretId(_secretId, role: 'management'),
    );
    final jumpAuth = AuthRef(
      type: _jumpAuthType,
      secretId: _effectiveSecretId(_jumpSecretId, role: 'jump'),
    );

    final managementSecretOk = await _ensureSecretAvailable(
      managementAuth,
      password: _password.text,
      privateKey: _privateKey.text,
      label: 'management node',
    );
    if (!managementSecretOk) {
      return;
    }
    if (_jumpEnabled) {
      final jumpSecretOk = await _ensureSecretAvailable(
        jumpAuth,
        password: _jumpPassword.text,
        privateKey: _jumpPrivateKey.text,
        label: 'jump host',
      );
      if (!jumpSecretOk) {
        return;
      }
    }

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

  Future<void> _editScript() async {
    final edited = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ScriptEditorScreen(initialScript: _script.text),
      ),
    );
    if (edited == null || !mounted) {
      return;
    }
    setState(() {
      _script.text = edited;
    });
  }

  Future<bool> _ensureSecretAvailable(
    AuthRef auth, {
    required String password,
    required String privateKey,
    required String label,
  }) async {
    if (auth.type == AuthType.password) {
      if (password.isNotEmpty) {
        return true;
      }
      final existing = await _secretStore.read(auth);
      if ((existing.password ?? '').isNotEmpty) {
        return true;
      }
      _showError(
        'Enter a password for $label or use an alias with a saved password.',
      );
      return false;
    }

    if (privateKey.trim().isNotEmpty) {
      return true;
    }
    final existing = await _secretStore.read(auth);
    if ((existing.privateKeyPem ?? '').trim().isNotEmpty) {
      return true;
    }
    _showError(
      'Enter a private key for $label or use an alias with a saved key.',
    );
    return false;
  }

  String _effectiveSecretId(
    TextEditingController controller, {
    required String role,
  }) {
    final current = controller.text.trim();
    if (current.isNotEmpty) {
      return current;
    }
    return '${widget.cluster.id}_$role';
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          Tooltip(
            message: 'Save',
            child: TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save'),
            ),
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
                    min: 1,
                    max: 65535,
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
                      min: 1,
                      max: 65535,
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
                    min: 1,
                    max: 600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ScriptField(controller: _script, onEdit: _editScript),
          ],
        ),
      ),
    );
  }
}

class _ScriptField extends StatelessWidget {
  const _ScriptField({required this.controller, required this.onEdit});

  final TextEditingController controller;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (_) => controller.text.trim().isEmpty ? 'Required' : null,
      builder: (field) {
        final lineCount = controller.text.isEmpty
            ? 1
            : '\n'.allMatches(controller.text).length + 1;
        final preview = controller.text
            .split('\n')
            .take(8)
            .map((line) => line.isEmpty ? ' ' : line)
            .join('\n');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () async {
                await onEdit();
                field.didChange(controller.text);
              },
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Bash script',
                  errorText: field.errorText,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.code),
                        const SizedBox(width: 8),
                        Expanded(child: Text('$lineCount lines')),
                        TextButton.icon(
                          onPressed: () async {
                            await onEdit();
                            field.didChange(controller.text);
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        preview,
                        maxLines: 8,
                        overflow: TextOverflow.fade,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('Advanced credential alias'),
          children: [
            _TextField(
              controller: secretId,
              label: 'Credential alias',
              helperText:
                  'Optional for manual setup; useful for imported configs.',
            ),
          ],
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
    this.min,
    this.max,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final bool number;
  final int? min;
  final int? max;
  final String? helperText;

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
          helperText: helperText,
        ),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'Required';
          }
          if (number && int.tryParse(value ?? '') == null) {
            return 'Invalid number';
          }
          final numberValue = int.tryParse(value ?? '');
          if (numberValue != null && min != null && numberValue < min!) {
            return 'Must be at least $min';
          }
          if (numberValue != null && max != null && numberValue > max!) {
            return 'Must be at most $max';
          }
          return null;
        },
      ),
    );
  }
}
