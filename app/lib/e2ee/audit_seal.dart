import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:pointycastle/export.dart';

// Organisation audit envelope (sealed box): ephemeral X25519 with the control room's audit key,
// HKDF-SHA256, AES-256-GCM. Only the audit service holding the private key can open it; the relay
// server stores it as an opaque string. Wire: base64(eph_pub[32] | nonce[12] | ciphertext+tag).
// Must match scripts/audit/audit_crypto.py.
const _info = 'relay-audit-v1';

Uint8List _hkdf(List<int> ikm, List<int> salt, int len) {
  final prk = Hmac(sha256, salt).convert(ikm).bytes;
  final out = <int>[];
  var t = <int>[];
  for (var i = 1; out.length < len; i++) {
    t = Hmac(sha256, prk).convert([...t, ...utf8.encode(_info), i]).bytes;
    out.addAll(t);
  }
  return Uint8List.fromList(out.sublist(0, len));
}

// auditKeyB64 = 33-byte (0x05-prefixed) X25519 public key, as published by the audit service.
String sealForAudit(String auditKeyB64, Map<String, dynamic> payload) {
  final audit = base64.decode(auditKeyB64);
  final eph = Curve.generateKeyPair();
  final shared = Curve.calculateAgreement(Curve.decodePoint(audit, 0), eph.privateKey);
  final ephPub = eph.publicKey.serialize().sublist(1);
  final key = _hkdf(shared, [...ephPub, ...audit.sublist(audit.length - 32)], 32);
  final r = Random.secure();
  final nonce = Uint8List.fromList(List.generate(12, (_) => r.nextInt(256)));
  final gcm = GCMBlockCipher(AESEngine())
    ..init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List.fromList(utf8.encode(_info))));
  final ct = gcm.process(Uint8List.fromList(utf8.encode(jsonEncode(payload))));
  return base64.encode([...ephPub, ...nonce, ...ct]);
}
