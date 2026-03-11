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

  void _setLoading() {
    _isLoading = true;
    _error = null;
    notifyListeners();
  }

  void _handleError(dynamic e) {
    _isLoading = false;
    _error = e.toString();
    notifyListeners();
  }

  Future<bool> login(String username, String password, String serverUrl) async {
    _setLoading();
    try {
      final response = await _authService.login(username, password, serverUrl);
      _isLoading = false;
      _error = response.success ? null : (response.message ?? response.error ?? 'Authentication failed');
      notifyListeners();
      return response.success;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  Future<bool> loginWithApple(String identityToken) async {
    _setLoading();
    try {
      final response = await _authService.loginWithApple(identityToken);
      _isLoading = false;
      _error = response.success ? null : (response.message ?? response.error ?? 'Apple sign-in failed');
      notifyListeners();
      return response.success;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  Future<bool> loginWithGoogle(String idToken) async {
    _setLoading();
    try {
      final response = await _authService.loginWithGoogle(idToken);
      _isLoading = false;
      _error = response.success ? null : (response.message ?? response.error ?? 'Google sign-in failed');
      notifyListeners();
      return response.success;
    } catch (e) {
      _handleError(e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDevices() async {
    _setLoading();
    try {
      final devices = await _authService.fetchDevices();
      _isLoading = false;
      _error = null;
      notifyListeners();
      return devices;
    } catch (e) {
      _handleError(e);
      return [];
    }
  }

  Future<String> generateLinkToken() async {
    return await _authService.generateLinkToken();
  }

  Future<void> connectToDevice(String deviceId) async {
    _setLoading();
    try {
      await _authService.connectToDevice(deviceId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _handleError(e);
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
