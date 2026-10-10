import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import 'dtn.dart';

// Phone-to-phone mesh. Offline phones talk to each other through it; in bridge mode phones that
// still reach the server keep it running too and act as gateways (upload bundles, forward
// server messages down to offline peers, send delivery acks back).
class NearbyMesh {
  final String name;
  final void Function(Map<String, dynamic> msg) onMessage;
  final VoidCallback onPeersChanged;
  // store-and-forward: bundles this phone carries, and a sink for new ones (true = was new)
  final Future<List<Bundle>> Function() carried;
  final Future<bool> Function(Bundle b) onBundle;
  // bridge mode: server messages a gateway passed down, and delivery confirmations passed back
  final void Function(Map<String, dynamic> msg) onForward;
  final void Function(List<String> ids) onAck;
  final Set<String> peers = {};
  final Set<String> offlinePeers = {}; // peers that told us they lost the server
  bool offline = false; // my own state, announced to peers
  final Set<String> _seen = {}; // message ids already handled, stops relay loops
  bool running = false;
  static const _maxHops = 6;
  static const _service = 'com.hack.relay.mesh';

  NearbyMesh({
    required this.name,
    required this.onMessage,
    required this.onPeersChanged,
    required this.carried,
    required this.onBundle,
    required this.onForward,
    required this.onAck,
  });

  // ---- lifecycle: start until it works, explain why when it cannot ----
  bool _wanted = false, _starting = false;
  String _problem = '';
  Timer? _retry, _watchdog;
  final String _token = (Random.secure().nextInt(1 << 32)).toRadixString(16).padLeft(8, '0');
  String get _endpointName => '$name|$_token';

  // Shown in the side menu and the nearby banner.
  String get status {
    if (!_wanted) return 'Off';
    if (_problem.isNotEmpty) return _problem;
    if (!running) return 'Starting…';
    return peers.isEmpty ? 'Searching for phones nearby…' : '${peers.length} phone${peers.length == 1 ? '' : 's'} connected';
  }

  Future<void> start() async {
    _wanted = true;
    if (running || _starting) return;
    _starting = true;
    _retry?.cancel();
    try {
      final why = await _preflight();
      if (why != null) {
        _problem = why;
        _retryIn(const Duration(seconds: 15));
        return;
      }
      await Nearby().startAdvertising(
        _endpointName,
        Strategy.P2P_CLUSTER,
        serviceId: _service,
        onConnectionInitiated: _accept,
        onConnectionResult: _result,
        onDisconnected: _lost,
      );
      await Nearby().startDiscovery(
        _endpointName,
        Strategy.P2P_CLUSTER,
        serviceId: _service,
        onEndpointFound: _found,
        onEndpointLost: (id) => _lost(id ?? ''),
      );
      running = true;
      _problem = '';
      // discovery can go stale on some phones: restart it if nobody shows up for a while
      _watchdog?.cancel();
      _watchdog = Timer.periodic(const Duration(seconds: 30), (_) => _refreshDiscovery());
    } catch (e) {
      _problem = 'Nearby error: ${'$e'.split('\n').first}';
      try {
        await Nearby().stopAdvertising();
        await Nearby().stopDiscovery();
      } catch (_) {}
      _retryIn(const Duration(seconds: 10));
    } finally {
      _starting = false;
      onPeersChanged();
    }
  }

  void _retryIn(Duration d) {
    _retry?.cancel();
    _retry = Timer(d, () {
      if (_wanted && !running) start();
    });
  }

  // Permissions and switches Nearby needs; a readable reason when something is missing.
  Future<String?> _preflight() async {
    Map<Permission, PermissionStatus> res = {};
    for (var i = 0; i < 5; i++) {
      try {
        res = await [
          Permission.location,
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
          Permission.nearbyWifiDevices,
        ].request();
        break;
      } catch (e) {
        // another permission dialog (e.g. microphone) is open: wait and ask again
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    if (res.isEmpty) return 'Waiting for permission dialogs…';
    final missing = res.entries.where((e) => !e.value.isGranted && !e.value.isLimited).map((e) => e.key).toList();
    if (missing.isNotEmpty) {
      final perm = missing.any((p) => p == Permission.location) ? 'Location' : 'Nearby devices';
      return 'Allow "$perm" for Bunny Hop in phone settings';
    }
    try {
      if (await Permission.location.serviceStatus.isDisabled) return 'Turn on Location';
      if (await Permission.bluetooth.serviceStatus.isDisabled) return 'Turn on Bluetooth';
    } catch (_) {}
    return null;
  }

  Future<void> _refreshDiscovery() async {
    if (!running || peers.isNotEmpty) return;
    try {
      await Nearby().stopDiscovery();
      await Nearby().startDiscovery(
        _endpointName,
        Strategy.P2P_CLUSTER,
        serviceId: _service,
        onEndpointFound: _found,
        onEndpointLost: (id) => _lost(id ?? ''),
      );
    } catch (e) {
      debugPrint('nearby rediscovery failed: $e');
    }
  }

  // Both phones discover each other; only the lower token asks, so requests do not collide.
  // The other side asks too if nothing happened after 8 s (older app versions have no token).
  void _found(String id, String endpointName, String _) {
    if (peers.contains(id)) return;
    final theirs = endpointName.contains('|') ? endpointName.split('|').last : null;
    void ask() {
      if (peers.contains(id) || !running) return;
      Nearby()
          .requestConnection(_endpointName, id, onConnectionInitiated: _accept, onConnectionResult: _result, onDisconnected: _lost)
          .catchError((Object e) {
            debugPrint('nearby request $id: $e');
            return false;
          });
    }

    if (theirs == null || _token.compareTo(theirs) < 0) {
      ask();
    } else {
      Timer(const Duration(seconds: 8), ask);
    }
  }

  Future<void> stop() async {
    _wanted = false;
    _retry?.cancel();
    _watchdog?.cancel();
    _problem = '';
    if (!running) return onPeersChanged();
    running = false;
    peers.clear();
    offlinePeers.clear();
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
          if (m['k'] == 'sum') {
            _sendMissing(from, BundleBloom.decode(m['bloom']));
            return;
          }
          if (m['k'] == 'st') {
            (m['off'] == true) ? offlinePeers.add(from) : offlinePeers.remove(from);
            return;
          }
          if (m['k'] == 'fwd' || m['k'] == 'ack') {
            if (!_seen.add('${m['k']}:${m['fid']}')) return;
            if (m['k'] == 'fwd') {
              onForward(Map<String, dynamic>.from(m['m']));
            } else {
              onAck(List<String>.from(m['ids']));
            }
            final hops = (m['hops'] as int? ?? _maxHops) - 1;
            if (hops > 0) _flood({...m, 'hops': hops}, except: from);
            return;
          }
          if (m['k'] == 'b') {
            _gotBundle(from, Bundle.fromJson(Map<String, dynamic>.from(m['b'])));
            return;
          }
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
      _to(id, {'k': 'st', 'off': offline});
      _sendSummary(id);
    }
  }

  void _lost(String id) {
    offlinePeers.remove(id);
    if (peers.remove(id)) onPeersChanged();
  }

  // Payload per CONTRACT: {id, channel_id, type, body, created_at, sender_id, name}
  void send(Map<String, dynamic> m) {
    _seen.add('${m['id']}');
    _flood({...m, 'hops': _maxHops});
  }

  // Handshake: tell a new peer what I already carry; it replies with only what I am missing.
  Future<void> _sendSummary(String id) async {
    final bloom = BundleBloom();
    for (final b in await carried()) {
      bloom.add(b.id);
    }
    _to(id, {'k': 'sum', 'bloom': bloom.encode()});
  }

  Future<void> _sendMissing(String id, BundleBloom theirs) async {
    for (final b in await carried()) {
      if (!theirs.mightContain(b.id)) _to(id, {'k': 'b', 'b': b.toJson()});
    }
  }

  Future<void> _gotBundle(String from, Bundle b) async {
    final carried = Bundle.fromJson({...b.toJson(), 'hops': b.hops + 1});
    if (await onBundle(carried)) _flood({'k': 'b', 'b': carried.toJson()}, except: from);
  }

  // Tell everyone in range whether I can still reach the server.
  void setOffline(bool v) {
    offline = v;
    _flood({'k': 'st', 'off': v});
  }

  // Gateway: pass a message from the server down to peers that lost it (still end-to-end encrypted).
  void forward(Map<String, dynamic> m) {
    if (offlinePeers.isEmpty || !_seen.add('fwd:${m['id']}')) return;
    final f = {'k': 'fwd', 'fid': m['id'], 'm': m, 'hops': _maxHops};
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(f)));
    for (final id in offlinePeers) {
      Nearby().sendBytesPayload(id, bytes).catchError((_) {});
    }
  }

  // Gateway: these bundles reached the server; their senders can stop waiting.
  void ack(List<String> ids) {
    if (ids.isEmpty || peers.isEmpty) return;
    final fid = '${ids.first}+${ids.length}';
    _seen.add('ack:$fid');
    _flood({'k': 'ack', 'fid': fid, 'ids': ids, 'hops': _maxHops});
  }

  // Hand a freshly created bundle to everyone in range.
  void pushBundle(Bundle b) => _flood({'k': 'b', 'b': b.toJson()});

  void _to(String id, Map<String, dynamic> m) =>
      Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(jsonEncode(m)))).catchError((_) {});

  void _flood(Map<String, dynamic> m, {String? except}) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(m)));
    for (final id in peers) {
      if (id != except) Nearby().sendBytesPayload(id, bytes).catchError((_) {});
    }
  }
}
