import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

// permission_handler throws if two requests overlap. Mic, notification and Nearby
// permissions were asked from different places at login, so one of them failed
// and the mic stayed denied. Every request now goes through this single queue.
class Perms {
  static Future<void> _tail = Future.value();

  static Future<T> _queue<T>(Future<T> Function() job) {
    final done = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        done.complete(await job());
      } catch (e, s) {
        done.completeError(e, s);
      }
    });
    return done.future;
  }

  static Future<void> request(List<Permission> list) => _queue(() => list.request());

  static Future<void>? _startup;

  // One batch, asked once per app run: mic first, then the rest.
  static Future<void> startup() => _startup ??= request([
    Permission.microphone,
    Permission.notification,
    Permission.location,
    Permission.bluetoothScan,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.nearbyWifiDevices,
  ]);

  // True when the mic is usable; asks again if it was never answered.
  static Future<bool> mic() => _queue(() async {
    var s = await Permission.microphone.status;
    if (!s.isGranted) s = await Permission.microphone.request();
    return s.isGranted;
  });
}
