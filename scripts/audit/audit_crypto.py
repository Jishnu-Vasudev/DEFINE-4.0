"""Audit-key cryptography; must match app/lib/e2ee/audit_seal.dart and media_crypt.dart.

Envelope: base64(eph_pub[32] | nonce[12] | AES-256-GCM(ciphertext+tag)), key = HKDF-SHA256(
X25519(audit_priv, eph_pub), salt = eph_pub | audit_pub, info = "relay-audit-v1"), AAD = info.
"""
import base64
import json
import os

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.hashes import SHA256
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

INFO = b"relay-audit-v1"


def load_or_create_key(path):
    """Returns (private_key, public_b64_for_server). The private key never leaves this laptop."""
    if os.path.exists(path):
        with open(path, "rb") as f:
            priv = X25519PrivateKey.from_private_bytes(f.read())
    else:
        priv = X25519PrivateKey.generate()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(priv.private_bytes(serialization.Encoding.Raw, serialization.PrivateFormat.Raw, serialization.NoEncryption()))
        try:
            os.chmod(path, 0o600)
        except OSError:
            pass
    pub = priv.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    return priv, base64.b64encode(b"\x05" + pub).decode()  # 0x05 = Signal "djb" key type, as the app expects


def open_envelope(priv, envelope_b64):
    raw = base64.b64decode(envelope_b64)
    eph, nonce, ct = raw[:32], raw[32:44], raw[44:]
    shared = priv.exchange(X25519PublicKey.from_public_bytes(eph))
    mine = priv.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
    key = HKDF(algorithm=SHA256(), length=32, salt=eph + mine, info=INFO).derive(shared)
    return json.loads(AESGCM(key).decrypt(nonce, ct, INFO))


def decrypt_media(media_key_b64, blob):
    """Media blobs: AES-256-GCM, key = first 32 bytes, iv = next 12 (see media_crypt.dart)."""
    k = base64.b64decode(media_key_b64)
    return AESGCM(k[:32]).decrypt(k[32:44], blob, None)
