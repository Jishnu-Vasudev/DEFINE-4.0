import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

// Phone-to-phone mesh used only while the server is unreachable.
class NearbyMesh {
  final String name;
  final void Function(Map<String, dynamic> msg) onMessage;
  final VoidCallback onPeersChanged;
  final Set<String> peers = {};
  final Set<String> _seen = {}; // message ids already handled, stops relay loops
  bool running = false;
  static const _maxHops = 6;
  static const _service = 'com.hack.relay.mesh';

  NearbyMesh({required this.name, required this.onMessage, required this.onPeersChanged});

  Future<void> start() async {
    if (running) return;
    running = true;
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();
    try {
      await Nearby().startAdvertising(
        name,
        Strategy.P2P_CLUSTER,
        serviceId: _service,
        onConnectionInitiated: _accept,
        onConnectionResult: _result,
        onDisconnected: _lost,
      );
      await Nearby().startDiscovery(
        name,
        Strategy.P2P_CLUSTER,
        serviceId: _service,
        onEndpointFound: (id, _, _) {
          if (peers.contains(id)) return;
          Nearby().requestConnection(name, id, onConnectionInitiated: _accept, onConnectionResult: _result, onDisconnected: _lost);
        },
        onEndpointLost: (id) => _lost(id ?? ''),
      );
    } catch (e) {
      debugPrint('nearby start failed: $e');
    }
  }

  Future<void> stop() async {
    if (!running) return;
    running = false;
    peers.clear();
    onPeersChanged();
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (_) {}
  }

  void _accept(String id, ConnectionInfo _) {
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (from, p) {
        if (p.type != PayloadType.BYTES || p.bytes == null) return;
        try {
          final m = jsonDecode(utf8.decode(p.bytes!)) as Map<String, dynamic>;
          if (!_seen.add('${m['id']}')) return;
          onMessage(m);
          // multi-hop: pass it on so phones out of the sender's range still get it
          final hops = (m['hops'] as int? ?? _maxHops) - 1;
          if (hops > 0) _flood({...m, 'hops': hops}, except: from);
        } catch (_) {}
      },
    );
  }

  void _result(String id, Status s) {
    if (s == Status.CONNECTED) {
      peers.add(id);
      onPeersChanged();
    }
  }

  void _lost(String id) {
    if (peers.remove(id)) onPeersChanged();
  }

  // Payload per CONTRACT: {id, channel_id, type, body, created_at, sender_id, name}
  void send(Map<String, dynamic> m) {
    _seen.add('${m['id']}');
    _flood({...m, 'hops': _maxHops});
  }

  void _flood(Map<String, dynamic> m, {String? except}) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(m)));
    for (final id in peers) {
      if (id != except) Nearby().sendBytesPayload(id, bytes).catchError((_) {});
    }
  }
}
