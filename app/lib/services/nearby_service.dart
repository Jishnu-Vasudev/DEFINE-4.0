import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import '../models/message.dart';

class NearbyService {
  static const String serviceId = 'com.example.ptt_app';
  static const Strategy strategy = Strategy.P2P_CLUSTER;

  final String userName;
  final Function(Message message)? onMessageReceived;
  final Function(String status)? onStatusChanged;

  final Set<String> _connectedEndpoints = {};
  bool _isRunning = false;

  NearbyService({
    required this.userName,
    this.onMessageReceived,
    this.onStatusChanged,
  });

  bool get isRunning => _isRunning;
  int get connectedPeerCount => _connectedEndpoints.size;

  Future<void> startNearby() async {
    if (_isRunning) return;
    _isRunning = true;
    onStatusChanged?.call('Starting Nearby mesh...');

    try {
      // Start Advertising
      await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _connectedEndpoints.add(id);
            onStatusChanged?.call('Connected to peer ($id)');
          } else {
            _connectedEndpoints.remove(id);
          }
        },
        onDisconnected: (id) {
          _connectedEndpoints.remove(id);
          onStatusChanged?.call('Disconnected from peer ($id)');
        },
        serviceId: serviceId,
      );

      // Start Discovery
      await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, sid) {
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: _onConnectionInitiated,
            onConnectionResult: (id, status) {
              if (status == Status.CONNECTED) {
                _connectedEndpoints.add(id);
                onStatusChanged?.call('Connected to peer ($id)');
              } else {
                _connectedEndpoints.remove(id);
              }
            },
            onDisconnected: (id) {
              _connectedEndpoints.remove(id);
            },
          );
        },
        onEndpointLost: (id) {
          _connectedEndpoints.remove(id);
        },
        serviceId: serviceId,
      );
    } catch (e) {
      onStatusChanged?.call('Nearby error: $e');
    }
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endpointId, payload) {
        if (payload.type == PayloadType.BYTES && payload.bytes != null) {
          try {
            final str = utf8.decode(payload.bytes!);
            final json = jsonDecode(str) as Map<String, dynamic>;
            final msg = Message(
              id: json['id'] as String,
              channelId: json['channel_id'] as String,
              senderId: json['sender_id'] as String,
              type: json['type'] as String,
              body: (json['body'] as String?) ?? '',
              createdAt: (json['created_at'] as num).toInt(),
              offline: 1,
              status: OutboxStatus.delivered,
            );
            onMessageReceived?.call(msg);
          } catch (_) {}
        }
      },
    );
  }

  Future<void> broadcastNearbyMessage(Map<String, dynamic> payload) async {
    if (_connectedEndpoints.isEmpty) return;
    final jsonStr = jsonEncode(payload);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));

    for (final endpoint in _connectedEndpoints) {
      try {
        await Nearby().sendBytesPayload(endpoint, bytes);
      } catch (_) {}
    }
  }

  Future<void> stopNearby() async {
    if (!_isRunning) return;
    _isRunning = false;
    _connectedEndpoints.clear();
    try {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    } catch (_) {}
    onStatusChanged?.call('Nearby mesh stopped');
  }

  void dispose() {
    stopNearby();
  }
}

extension on Set {
  int get size => length;
}
