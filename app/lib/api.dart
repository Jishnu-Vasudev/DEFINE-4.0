import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiError implements Exception {
  final int status;
  final String message;
  ApiError(this.status, this.message);
  @override
  String toString() => message;
}

class Api {
  String host;
  int port;
  String? jwt;
  Api(this.host, this.port, [this.jwt]);

  String get base => 'http://$host:$port';
  String get wsUrl => 'ws://$host:$port/ws?token=$jwt';

  Map<String, String> get _headers => {'Content-Type': 'application/json', if (jwt != null) 'Authorization': 'Bearer $jwt'};

  Future<dynamic> get(String path) async =>
      _decode(await http.get(Uri.parse('$base$path'), headers: _headers).timeout(const Duration(seconds: 8)));

  Future<dynamic> post(String path, Map<String, dynamic> body) async =>
      _decode(await http.post(Uri.parse('$base$path'), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 8)));

  Future<bool> health() async {
    try {
      final r = await http.get(Uri.parse('$base/health')).timeout(const Duration(seconds: 3));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Map<String, String> get authHeader => {'Authorization': 'Bearer $jwt'};
  String mediaUrl(String file) => '$base/media/$file';

  Future<String> upload(String path) async {
    final req = http.MultipartRequest('POST', Uri.parse('$base/media'))
      ..headers.addAll(authHeader)
      ..files.add(await http.MultipartFile.fromPath('file', path));
    final r = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 30)));
    return _decode(r)['media'];
  }

  dynamic _decode(http.Response r) {
    final j = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode >= 400) throw ApiError(r.statusCode, (j is Map ? j['error'] : null) ?? 'Error ${r.statusCode}');
    return j;
  }
}
