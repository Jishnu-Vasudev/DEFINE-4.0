import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_state.dart';

class Talker {
  final String userId, name;
  final int priority;
  Talker(this.userId, this.name, this.priority);
}

enum PttResult { granted, denied, error }

// One LiveKit room per channel, joined muted; mic opens only after the server grants the floor.
class Ptt extends ChangeNotifier {
  final AppState app;
  final Map<String, Room> _rooms = {};
  final Set<String> _joining = {};
  final Map<String, Talker> talkers = {};
  String? talkingIn; // channel where I hold the floor
  Map<String, dynamic>? alert; // pending broadcast shown full-screen
  bool alertEmergency = false;
  Map<String, dynamic>? incomingCall; // {room, name} while ringing

  void clearIncoming() {
    incomingCall = null;
    notifyListeners();
  }

  StreamSubscription? _sub;
  bool _started = false;

  Ptt(this.app) {
    _sub = app.events.listen(_onEvent);
    app.addListener(_onApp);
    _onApp();
  }

  void _onApp() {
    if (app.loggedIn && !_started) {
      _started = true;
      _start();
    } else if (!app.loggedIn && _started) {
      _started = false;
      _roomTimer?.cancel();
      for (final r in _rooms.values) {
        r.disconnect();
      }
      _rooms.clear();
      talkers.clear();
      FlutterForegroundTask.stopService();
    }
  }

  Future<void> _start() async {
    await Permission.microphone.request();
    await Permission.notification.request();
    try {
      await _startForeground(); // throws on Android 14+ if mic permission was denied
    } catch (e) {
      debugPrint('foreground service not started: $e');
    }
    _syncRooms();
    // picks up new channels and retries rooms that failed (e.g. LiveKit was down)
    _roomTimer = Timer.periodic(const Duration(seconds: 20), (_) => _syncRooms());
  }

  Timer? _roomTimer;

  Future<void> _startForeground() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'relay_live',
        channelName: 'Relay live audio',
        channelDescription: 'Keeps push-to-talk working while the screen is off.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceTypes: [ForegroundServiceTypes.microphone],
      notificationTitle: 'Relay is on',
      notificationText: 'Listening to your team channels',
      callback: startCallback,
    );
  }

  Future<Room?> _join(String channelId) async {
    if (_rooms[channelId] != null) return _rooms[channelId];
    if (!_joining.add(channelId)) return null;
    try {
      final t = await app.api!.get('/livekit/token?room=$channelId');
      final room = Room();
      await room.connect(t['url'], t['token']);
      _rooms[channelId] = room;
      // dropped rooms are forgotten so the 20 s sync rejoins them
      room.createListener().on<RoomDisconnectedEvent>((_) => _rooms.remove(channelId));
      // walkie-talkie audio belongs on the loudspeaker, not the earpiece
      await AudioManager.instance.setSpeakerOutputPreferred(true);
      return room;
    } catch (e) {
      debugPrint('livekit join $channelId failed: $e');
      return null;
    } finally {
      _joining.remove(channelId);
    }
  }

  void _syncRooms() {
    for (final c in app.channels) {
      _join(c['id']);
    }
  }

  bool _holding = false; // finger still on the button

  Future<PttResult> press(String channelId, {int priority = 1}) async {
    _holding = true;
    try {
      final r = await app.api!.post('/floor/request', {'channel_id': channelId, 'priority': priority});
      if (r['granted'] != true) {
        HapticFeedback.heavyImpact();
        return PttResult.denied;
      }
      talkingIn = channelId;
      notifyListeners();
      HapticFeedback.mediumImpact();
      if (!_holding) {
        await release(channelId); // let go before the grant arrived
        return PttResult.granted;
      }
      final room = await _join(channelId);
      if (talkingIn == channelId) await room?.localParticipant?.setMicrophoneEnabled(true);
      return PttResult.granted;
    } catch (_) {
      return PttResult.error;
    }
  }

  Future<void> release(String channelId) async {
    _holding = false;
    if (talkingIn != channelId) return;
    await _mute(channelId);
    try {
      await app.api!.post('/floor/release', {'channel_id': channelId});
    } catch (_) {}
  }

  Future<void> _mute(String channelId) async {
    talkingIn = null;
    notifyListeners();
    await _rooms[channelId]?.localParticipant?.setMicrophoneEnabled(false);
  }

  void _onEvent(Map<String, dynamic> e) {
    switch (e['t']) {
      case 'floor':
        final ch = e['channel_id'] as String;
        if (e['state'] == 'released') {
          if (talkers[ch]?.userId == e['user_id']) talkers.remove(ch);
          // pre-empted or timed out while I was talking
          if (e['user_id'] == app.userId && talkingIn == ch) _mute(ch);
        } else {
          talkers[ch] = Talker(e['user_id'], e['name'] ?? '', e['priority'] ?? 1);
        }
        notifyListeners();
      case 'message' || 'sos':
        final m = Map<String, dynamic>.from(e['message']);
        if (m['type'] != 'sos' || m['sender_id'] == app.userId) return;
        alert = m;
        alertEmergency = true;
        HapticFeedback.vibrate();
        notifyListeners();
      case 'call_invite':
        incomingCall = {'room': e['room'], 'name': (e['from'] as Map?)?['name'] ?? 'Someone'};
        HapticFeedback.vibrate();
        notifyListeners();
      case 'broadcast':
        alert = Map<String, dynamic>.from(e['message']);
        alertEmergency = e['emergency'] == true;
        HapticFeedback.vibrate();
        notifyListeners();
    }
  }

  Future<void> acknowledge() async {
    final id = alert?['id'];
    alert = null;
    notifyListeners();
    if (id == null) return;
    try {
      await app.api!.post('/ack', {'message_id': id});
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    app.removeListener(_onApp);
    super.dispose();
  }
}

@pragma('vm:entry-point')
void startCallback() => FlutterForegroundTask.setTaskHandler(_KeepAlive());

class _KeepAlive extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
