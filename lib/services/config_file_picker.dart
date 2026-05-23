import 'package:flutter/services.dart';

class ConfigFilePicker {
  static const _channel = MethodChannel('queue_monitor/config_file_picker');

  Future<String?> pickJsonText() {
    return _channel.invokeMethod<String>('pickJsonText');
  }
}
