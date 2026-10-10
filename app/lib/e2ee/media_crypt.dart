import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

// Media is encrypted on the phone with a one-off AES-256-GCM key; that key travels only
// inside the end-to-end encrypted message, so the server stores an opaque blob.
class MediaKey {
  final Uint8List key, iv; // 32 + 12 bytes
  MediaKey(this.key, this.iv);

  factory MediaKey.random() {
    final r = Random.secure();
    Uint8List rnd(int n) => Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
    return MediaKey(rnd(32), rnd(12));
  }

  factory MediaKey.fromBytes(Uint8List b) => MediaKey(b.sublist(0, 32), b.sublist(32, 44));
  Uint8List get bytes => Uint8List.fromList([...key, ...iv]);

  Uint8List _run(bool encrypt, Uint8List input) {
    final gcm = GCMBlockCipher(AESEngine())..init(encrypt, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    return gcm.process(input);
  }

  Uint8List encrypt(Uint8List plain) => _run(true, plain);
  Uint8List decrypt(Uint8List cipher) => _run(false, cipher); // throws if tampered
}
