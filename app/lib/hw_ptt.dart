import 'package:flutter/services.dart';

import 'app_state.dart';
import 'ptt.dart';

// Volume-key push-to-talk (Android accessibility service, see PttAccessibilityService.kt).
// Key down/up arrive here and drive the same floor request + mic path as the on-screen button,
// on the channel the user last opened. The keys are only captured while this is armed.
class HwPtt {
  static const _ch = MethodChannel('relay/hwptt');
  final AppState app;
  final Ptt ptt;
  String? _talking;

  HwPtt(this.app, this.ptt) {
    _ch.setMethodCallHandler((call) async {
      if (call.method != 'key') return;
      final channel = app.pttChannelId;
      if (call.arguments == 'down' && channel != null) {
        _talking = channel;
        await ptt.press(channel);
      } else if (call.arguments == 'up' && _talking != null) {
        final c = _talking!;
        _talking = null;
        await ptt.release(c);
      }
    });
    app.addListener(_sync);
    _sync();
  }

  bool get armed => app.hwPtt && app.loggedIn && app.pttChannelId != null;

  void _sync() => _ch.invokeMethod('setArmed', armed).catchError((_) {});

  static Future<bool> serviceEnabled() async => await _ch.invokeMethod<bool>('isEnabled').catchError((_) => false) ?? false;
  static Future<void> openSettings() => _ch.invokeMethod('openSettings');
}
