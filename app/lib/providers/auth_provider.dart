import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/channel.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _userId;
  String? _userName;
  String? _userRole;
  String? _jwtToken;
  String _host = '10.0.2.2'; // default android emulator host or LAN IP
  int _port = 3000;
  bool _isLoading = false;
  String? _errorMessage;

  List<Channel> _channels = [];

  String? get userId => _userId;
  String? get userName => _userName;
  String? get userRole => _userRole;
  String? get jwtToken => _jwtToken;
  String get host => _host;
  int get port => _port;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _jwtToken != null && _userId != null;
  List<Channel> get channels => _channels;

  ApiService? _apiService;
  ApiService get apiService {
    _apiService ??= ApiService(baseUrl: 'http://$_host:$_port', jwtToken: _jwtToken);
    return _apiService!;
  }

  Future<bool> joinWithQrOrCode(String rawCodeOrJson, String displayName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String code = rawCodeOrJson.trim();
      String parsedHost = _host;
      int parsedPort = _port;

      if (code.startsWith('{') && code.endsWith('}')) {
        try {
          final payload = jsonDecode(code) as Map<String, dynamic>;
          if (payload['host'] != null) parsedHost = payload['host'].toString();
          if (payload['port'] != null) parsedPort = (payload['port'] as num).toInt();
          if (payload['code'] != null) code = payload['code'].toString();
        } catch (_) {}
      }

      _host = parsedHost;
      _port = parsedPort;
      _apiService = ApiService(baseUrl: 'http://$_host:$_port');

      final res = await _apiService!.join(
        host: _host,
        port: _port,
        code: code,
        name: displayName.isEmpty ? 'Operator' : displayName,
      );

      _jwtToken = res['jwt'];
      _userId = res['user']['id'];
      _userName = res['user']['name'];
      _userRole = res['user']['role'];
      _apiService!.jwtToken = _jwtToken;

      final chList = (res['channels'] as List)
          .map((item) => Channel.fromJson(item))
          .toList();
      _channels = chList;
      await DbService.instance.saveChannels(chList);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshChannels() async {
    if (!isAuthenticated) return;
    try {
      final chs = await apiService.getChannels();
      _channels = chs;
      await DbService.instance.saveChannels(chs);
      notifyListeners();
    } catch (_) {}
  }
}
