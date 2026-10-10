// AudioProcessingMode is marked experimental in livekit_client; it is the only way to force software AGC/NS.
// ignore_for_file: experimental_member_use

import 'package:livekit_client/livekit_client.dart';

// One voice pipeline for push-to-talk and calls.
// Capture: software AGC + noise suppression (consistent across phones), hardware-or-software echo cancel,
// high-pass to cut wind/handling rumble. The mic track stays published while muted so a PTT press
// only flips mute instead of restarting capture and renegotiating (the main source of start-up delay).
const voiceCapture = AudioCaptureOptions(
  noiseSuppression: true,
  noiseSuppressionMode: AudioProcessingMode.software,
  autoGainControl: true,
  autoGainControlMode: AudioProcessingMode.software,
  echoCancellation: true,
  highPassFilter: true,
  typingNoiseDetection: false,
  stopAudioCaptureOnMute: false,
);

// Opus for speech: 32 kbps mono is clear voice on a busy LAN. DTX off so the first syllable after
// un-muting is not clipped; RED adds redundancy against Wi-Fi packet loss without extra buffering.
const voicePublish = AudioPublishOptions(encoding: AudioEncoding(maxBitrate: 32000), dtx: false, red: true);

// Android audio session for a walkie-talkie: voice-communication mode (hardware echo cancel),
// transient focus that only ducks music/navigation instead of stopping it, loudspeaker routing.
Future<void> configureVoiceAudioSession() async {
  try {
    await AudioManager.instance.setAudioSessionOptions(
      const AudioSessionOptions.communication(
        android: AndroidAudioSessionConfiguration(
          audioMode: AndroidAudioMode.inCommunication,
          manageAudioFocus: true,
          focusMode: AndroidAudioFocusMode.gainTransientMayDuck,
          streamType: AndroidAudioStreamType.voiceCall,
          usageType: AndroidAudioAttributesUsageType.voiceCommunication,
          contentType: AndroidAudioAttributesContentType.speech,
        ),
      ),
    );
    await AudioManager.instance.setSpeakerOutputPreferred(true);
  } catch (_) {}
}

// Walkie-talkie audio belongs on the loudspeaker; the earpiece is what makes it sound quiet.
RoomOptions voiceRoomOptions() => const RoomOptions(
  defaultAudioCaptureOptions: voiceCapture,
  defaultAudioPublishOptions: voicePublish,
  defaultAudioOutputOptions: AudioOutputOptions(speakerOn: true),
  adaptiveStream: false,
  dynacast: false,
);
