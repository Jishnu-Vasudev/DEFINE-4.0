import 'package:livekit_client/livekit_client.dart';
import 'api_service.dart';

class LivekitService {
  final ApiService apiService;
  Room? _room;
  String? _currentRoomId;
  bool _isMicMuted = true;

  LivekitService({required this.apiService});

  Room? get room => _room;
  bool get isConnected => _room != null && _room!.connectionState == ConnectionState.connected;
  bool get isMicMuted => _isMicMuted;

  Future<void> joinChannelRoom(String channelId) async {
    if (_currentRoomId == channelId && isConnected) return;

    await leaveRoom();

    try {
      final tokenData = await apiService.getLiveKitToken(channelId);
      final token = tokenData['token'] as String;
      final url = tokenData['url'] as String;

      _room = Room();
      await _room!.connect(
        url,
        token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: AudioPublishOptions(
            dtx: true,
          ),
        ),
      );

      _currentRoomId = channelId;

      // Ensure local mic starts disabled (muted)
      await _room!.localParticipant?.setMicrophoneEnabled(false);
      _isMicMuted = true;
    } catch (_) {}
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (_room == null || !isConnected) return;
    try {
      await _room!.localParticipant?.setMicrophoneEnabled(enabled);
      _isMicMuted = !enabled;
    } catch (_) {}
  }

  Future<void> leaveRoom() async {
    if (_room != null) {
      await _room!.disconnect();
      await _room!.dispose();
      _room = null;
      _currentRoomId = null;
      _isMicMuted = true;
    }
  }

  void dispose() {
    leaveRoom();
  }
}
