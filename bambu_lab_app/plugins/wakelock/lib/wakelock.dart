import 'package:flutter/services.dart';

/// Keep the device screen on.
///
/// Only implemented on Android and iOS.
/// On Linux / Windows the plugin is not registered, so these calls are no-ops.
class Wakelock {
  static const _channel = MethodChannel('com.example.wakelock');

  /// Prevent the screen from turning off.
  static Future<bool> enable() async {
    try {
      await _channel.invokeMethod('enable');
      return true;
    } on MissingPluginException {
      // Plugin not registered on this platform — no-op
      return false;
    }
  }

  /// Allow the screen to turn off.
  static Future<bool> disable() async {
    try {
      await _channel.invokeMethod('disable');
      return true;
    } on MissingPluginException {
      return false;
    }
  }
}
