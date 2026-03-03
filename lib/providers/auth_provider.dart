import 'package:flutter/foundation.dart';

import '../models/protocol.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._authService);

  bool get isAuthenticated => _authService.isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;
  UserInfo? get userInfo => _authService.userInfo;
  String? get token => _authService.token;

  Future<bool> login(String username, String password, String serverUrl) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.login(username, password, serverUrl);
      _isLoading = false;

      if (response.success) {
        _error = null;
      } else {
        _error = response.message ?? response.error ?? 'Authentication failed';
      }

      notifyListeners();
      return response.success;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithGoogle(String idToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.loginWithGoogle(idToken);
      _isLoading = false;
      if (!response.success) {
        _error = response.message ?? response.error ?? 'Google sign-in failed';
      }
      notifyListeners();
      return response.success;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDevices() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final devices = await _authService.fetchDevices();
      _isLoading = false;
      notifyListeners();
      return devices;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<String> generateLinkToken() async {
    return await _authService.generateLinkToken();
  }

  Future<void> connectToDevice(String deviceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.connectToDevice(deviceId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _error = null;
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    return await _authService.loadSavedSession();
  }
}
