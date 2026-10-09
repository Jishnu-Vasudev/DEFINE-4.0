import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsService {
  final String host;
  final int port;
  final String token;
  final Function(Map<String, dynamic> event) onEvent;
  final Function(bool isConnected)? onConnectionChanged;

  WebSocketChannel? _channel;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _isConnected = false;

  WsService({
    required this.host,
    required this.port,
    required this.token,
    required this.onEvent,
    this.onConnectionChanged,
  }) {
    connect();
  }

  bool get isConnected => _isConnected;

  void connect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();

    final uri = Uri.parse('ws://$host:$port/ws?token=$token');
    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      onConnectionChanged?.call(true);

      _startPing();

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data.toString()) as Map<String, dynamic>;
            onEvent(json);
          } catch (_) {}
        },
        onError: (err) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isConnected && _channel != null) {
        send({'t': 'ping'});
      }
    });
  }

  void send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {}
  }

  void setOfflineMode(bool on) {
    send({'t': 'offline_mode', 'on': on});
  }

  void _handleDisconnect() {
    _isConnected = false;
    onConnectionChanged?.call(false);
    _pingTimer?.cancel();
    _channel = null;

    if (!_disposed) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        connect();
      });
    }
  }

  void dispose() {
    _disposed = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
  }
}
