import 'package:flutter/services.dart';

class ConfigFilePicker {
  static const _channel = MethodChannel('queue_monitor/config_file_picker');

  Future<String?> pickJsonText() {
    return _channel.invokeMethod<String>('pickJsonText');
  }

  Future<bool> saveJsonText({
    required String fileName,
    required String text,
  }) async {
    final saved = await _channel.invokeMethod<bool>('saveJsonText', {
      'file_name': fileName,
      'text': text,
    });
    return saved ?? false;
  }
}
