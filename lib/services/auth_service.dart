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
  UserInfo? _userInfo;
  Completer<AuthResponse>? _authCompleter;
  StreamSubscription? _messageSubscription;

  static const _keyToken = 'auth_token';
  static const _keySessionToken = 'session_token';
  static const _keyUsername = 'auth_username';
  static const _keyPermissions = 'auth_permissions';

  String? _sessionToken;
  String? _deviceId;

  AuthService(this._ws);

  String? get token => _token;
  UserInfo? get userInfo => _userInfo;
  bool get isAuthenticated => _token != null;

  Future<AuthResponse> login(
    String username,
    String password,
    String serverUrl,
  ) async {
    await _ws.connect(serverUrl);

    _authCompleter = Completer<AuthResponse>();
    _messageSubscription = _ws.messages.listen((msg) {
      final type = msg['type'] as String?;
      if (type == 'auth_response') {
        final response = AuthResponse.fromJson(msg);
        if (!_authCompleter!.isCompleted) {
          _authCompleter!.complete(response);
        }
      } else if (type == 'welcome') {
        // Backend sends welcome on connect, send auth after
      }
    }, onError: (e) {
      if (_authCompleter != null && !_authCompleter!.isCompleted) {
        _authCompleter!.completeError(e);
      }
    });

    final authMsg = AuthRequest(
      username: username,
      password: password,
      clientInfo: ClientInfo(
        platform: 'android',
        version: '0.1.0',
        deviceId: 'claude-remote-android',
      ),
      timestamp: DateTime.now().toIso8601String(),
      id: 'auth-${DateTime.now().millisecondsSinceEpoch}',
    );
    _ws.sendMessage(authMsg.toJson());

    try {
      final response = await _authCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => AuthResponse(
          success: false,
          message: 'Authentication timed out',
          timestamp: DateTime.now().toIso8601String(),
          id: 'timeout',
        ),
      );

      _messageSubscription?.cancel();
      _messageSubscription = null;
      _authCompleter = null;

      if (response.success && response.token != null) {
        _token = response.token;
        _userInfo = response.userInfo;
        await _saveCredentials(serverUrl);
      } else {
        _ws.disconnect();
      }

      return response;
    } catch (e) {
      _messageSubscription?.cancel();
      _messageSubscription = null;
      _authCompleter = null;
      _ws.disconnect();
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    _userInfo = null;
    _ws.disconnect();
    await _clearCredentials();
  }

  Future<bool> loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();

    // Check for relay session token first (Phase 3)
    final sessionToken = prefs.getString(_keySessionToken);
    if (sessionToken != null) {
      _sessionToken = sessionToken;
      _token = sessionToken;
      return true;
    }

    // Fall back to legacy auth_token
    final token = prefs.getString(_keyToken);
    final username = prefs.getString(_keyUsername);
    final permissions = prefs.getStringList(_keyPermissions);

    if (token != null && username != null) {
      _token = token;
      _userInfo = UserInfo(
        username: username,
        permissions: permissions ?? [],
      );
      return true;
    }
    return false;
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
    final token = _sessionToken ?? _token;
    final response = await http.get(
      Uri.parse('$kRelayHttpUrl/api/devices'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch devices: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> list = body['devices'] as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Future<String> generateLinkToken() async {
    final token = _sessionToken ?? _token;
    final response = await http.post(
      Uri.parse('$kRelayHttpUrl/api/devices/link-token'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to generate link token: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['token'] as String;
  }

  Future<void> reconnect() async {
    if (_deviceId != null) await connectToDevice(_deviceId!);
  }

  Future<void> connectToDevice(String deviceId) async {
    _deviceId = deviceId;
    final token = _sessionToken ?? _token;
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
      'session_token': token,
      'device_id': deviceId,
    });

    try {
      await _authCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Device connection timed out'),
      );
    } finally {
      _messageSubscription?.cancel();
      _messageSubscription = null;
      _authCompleter = null;
    }
  }

  Future<void> _saveCredentials(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) prefs.setString(_keyToken, _token!);
    if (_userInfo != null) {
      prefs.setString(_keyUsername, _userInfo!.username);
      prefs.setStringList(_keyPermissions, _userInfo!.permissions);
    }
  }

  Future<void> _clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_keyToken);
    prefs.remove(_keySessionToken);
    prefs.remove(_keyUsername);
    prefs.remove(_keyPermissions);
    _sessionToken = null;
  }
}
