import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/protocol.dart';
import 'websocket_service.dart';

class AuthService {
  final WebSocketService _ws;
  String? _token;
  Completer<AuthResponse>? _authCompleter;
  StreamSubscription? _messageSubscription;

  static const _keySessionToken = 'session_token';

  String? _sessionToken;
  String? _deviceId;

  String? get _effectiveToken => _sessionToken ?? _token;

  AuthService(this._ws);

  String? get token => _token;
  bool get isAuthenticated => _token != null;

  Future<void> logout() async {
    _token = null;
    _ws.disconnect();
    await _clearCredentials();
  }

  Future<bool> loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();

    final sessionToken = prefs.getString(_keySessionToken);
    if (sessionToken != null) {
      _sessionToken = sessionToken;
      _token = sessionToken;
      return true;
    }
    return false;
  }

  Future<AuthResponse> loginWithApple(String identityToken) async {
    final response = await http.post(
      Uri.parse('$kRelayHttpUrl/auth/apple'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identity_token': identityToken}),
    );

    if (response.statusCode != 200) {
      return AuthResponse(
        success: false,
        message: 'Apple sign-in failed: ${response.statusCode}',
        timestamp: DateTime.now().toIso8601String(),
        id: 'apple-auth-error',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final sessionToken = body['session_token'] as String?;
    if (sessionToken == null) {
      return AuthResponse(
        success: false,
        message: 'No session token in response',
        timestamp: DateTime.now().toIso8601String(),
        id: 'apple-auth-error',
      );
    }

    _sessionToken = sessionToken;
    _token = sessionToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionToken, sessionToken);

    return AuthResponse(
      success: true,
      token: sessionToken,
      timestamp: DateTime.now().toIso8601String(),
      id: 'apple-auth-ok',
    );
  }

  Future<AuthResponse> loginWithGoogle(String idToken) async {
    final response = await http.post(
      Uri.parse('$kRelayHttpUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    if (response.statusCode != 200) {
      return AuthResponse(
        success: false,
        message: 'Google sign-in failed: ${response.statusCode}',
        timestamp: DateTime.now().toIso8601String(),
        id: 'google-auth-error',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final sessionToken = body['session_token'] as String?;
    if (sessionToken == null) {
      return AuthResponse(
        success: false,
        message: 'No session token in response',
        timestamp: DateTime.now().toIso8601String(),
        id: 'google-auth-error',
      );
    }

    _sessionToken = sessionToken;
    _token = sessionToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionToken, sessionToken);

    return AuthResponse(
      success: true,
      token: sessionToken,
      timestamp: DateTime.now().toIso8601String(),
      id: 'google-auth-ok',
    );
  }

  Future<List<Map<String, dynamic>>> fetchDevices() async {
    final response = await http.get(
      Uri.parse('$kRelayHttpUrl/api/devices'),
      headers: {'Authorization': 'Bearer $_effectiveToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch devices: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> list = body['devices'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> reconnect() async {
    if (_deviceId != null) await connectToDevice(_deviceId!);
  }

  Future<void> connectToDevice(String deviceId) async {
    _deviceId = deviceId;
    final wsUrl = '$kRelayWsUrl/client';

    _authCompleter = Completer<AuthResponse>();
    await _ws.connect(wsUrl);

    _messageSubscription = _ws.messages.listen((msg) {
      final type = msg['type'] as String?;
      if ((type == 'welcome' || type == 'auth_response') &&
          _authCompleter?.isCompleted == false) {
        _authCompleter!.complete(AuthResponse(
          success: true,
          token: token,
          timestamp: DateTime.now().toIso8601String(),
          id: 'device-connect-ok',
        ));
      }
    }, onError: (e) {
      if (_authCompleter != null && !_authCompleter!.isCompleted) {
        _authCompleter!.completeError(e);
      }
    });

    _ws.sendMessage({
      'type': 'auth',
      'session_token': _effectiveToken,
      'device_id': deviceId,
    });

    try {
      await _authCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Device connection timed out'),
      );
    } finally {
      _clearAuthState();
    }
  }

  void _clearAuthState() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _authCompleter = null;
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_keySessionToken);
    _sessionToken = null;
    _token = null;
  }
}
