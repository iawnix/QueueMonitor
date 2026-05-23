import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/cluster_config.dart';
import '../services/config_repository.dart';

class ImportConfigScreen extends StatefulWidget {
  const ImportConfigScreen({super.key});

  @override
  State<ImportConfigScreen> createState() => _ImportConfigScreenState();
}

class _ImportConfigScreenState extends State<ImportConfigScreen> {
  final _repository = ConfigRepository();
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) {
      return;
    }
    setState(() {
      _controller.text = utf8.decode(bytes);
      _error = null;
    });
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
                FilledButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Pick JSON'),
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
