import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/message.dart';

class ApiService {
  String baseUrl;
  String? jwtToken;

  ApiService({required this.baseUrl, this.jwtToken});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (jwtToken != null) 'Authorization': 'Bearer $jwtToken',
  };

  Future<Map<String, dynamic>> join({
    required String host,
    required int port,
    required String code,
    required String name,
  }) async {
    baseUrl = 'http://$host:$port';
    final url = Uri.parse('$baseUrl/auth/join');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'name': name}),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      jwtToken = data['jwt'];
      return data;
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['error'] ?? 'Join failed (${res.statusCode})');
    }
  }

  Future<List<Channel>> getChannels() async {
    final url = Uri.parse('$baseUrl/me/channels');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((item) => Channel.fromJson(item)).toList();
    }
    throw Exception('Failed to fetch channels: ${res.body}');
  }

  Future<List<Message>> getMessages(String channelId, {int afterSeq = 0}) async {
    final url = Uri.parse('$baseUrl/channels/$channelId/messages?after_seq=$afterSeq');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((item) => Message.fromJson(item)).toList();
    }
    throw Exception('Failed to fetch messages: ${res.body}');
  }

  Future<int> sendMessage(Message msg) async {
    final url = Uri.parse('$baseUrl/messages');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode(msg.toApiPayload()),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return (data['seq'] as num).toInt();
    }
    throw Exception('Failed to send message: ${res.body}');
  }

  Future<String> uploadMedia(Uint8List fileBytes, String filename) async {
    final url = Uri.parse('$baseUrl/media');
    final req = http.MultipartRequest('POST', url);
    if (jwtToken != null) {
      req.headers['Authorization'] = 'Bearer $jwtToken';
    }
    req.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: filename));

    final streamedRes = await req.send();
    final res = await http.Response.fromStream(streamedRes);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      return data['media'] as String;
    }
    throw Exception('Media upload failed: ${res.body}');
  }

  Future<String> callInvite(String toUserId) async {
    final url = Uri.parse('$baseUrl/call/invite');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'to_user_id': toUserId}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['room'] as String;
    }
    throw Exception('Call invite failed: ${res.body}');
  }

  Future<void> ackMessage(String messageId) async {
    final url = Uri.parse('$baseUrl/ack');
    await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'message_id': messageId}),
    );
  }

  Future<Map<String, dynamic>> requestFloor(String channelId, {int priority = 1}) async {
    final url = Uri.parse('$baseUrl/floor/request');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'channel_id': channelId, 'priority': priority}),
    );
    return jsonDecode(res.body);
  }

  Future<void> releaseFloor(String channelId) async {
    final url = Uri.parse('$baseUrl/floor/release');
    await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'channel_id': channelId}),
    );
  }

  Future<Map<String, dynamic>> getLiveKitToken(String room) async {
    final url = Uri.parse('$baseUrl/livekit/token?room=$room');
    final res = await http.get(url, headers: _headers);
    return jsonDecode(res.body);
  }
}
