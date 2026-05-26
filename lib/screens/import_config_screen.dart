import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/cluster_config.dart';
import '../services/config_file_picker.dart';
import '../services/config_repository.dart';
import '../services/secure_secret_store.dart';

class ImportConfigScreen extends StatefulWidget {
  const ImportConfigScreen({super.key});

  @override
  State<ImportConfigScreen> createState() => _ImportConfigScreenState();
}

class _ImportConfigScreenState extends State<ImportConfigScreen> {
  final _repository = ConfigRepository(secretStore: SecureSecretStore());
  final _filePicker = ConfigFilePicker();
  final _controller = TextEditingController();
  String? _error;
  bool _picking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    try {
      final clusters = await _repository.importJson(_controller.text);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop<List<ClusterConfig>>(clusters);
    } on Object catch (error) {
      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _pickJsonFile() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final text = await _filePicker.pickJsonText();
      if (!mounted) {
        return;
      }
      if (text != null) {
        _controller.text = text;
      }
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message ?? error.code;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import config')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _picking ? null : _pickJsonFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_picking ? 'Picking...' : 'Pick JSON'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.check),
                  label: const Text('Import'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Config JSON',
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
