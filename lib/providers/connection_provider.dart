import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/websocket_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final WebSocketService _ws;
  final AuthService _authService;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _countdownTimer;
  bool _isConnected = false;
  bool _isReconnecting = false;
  int _retryDelaySecs = 2;
  int _retryCountdown = 0;

  ConnectionProvider(this._ws, this._authService) {
    _isConnected = _ws.isConnected;
    _subscription = _ws.connectionState.listen((connected) {
      _isConnected = connected;
      notifyListeners();
      if (!connected && !_isReconnecting) {
        _retryDelaySecs = 2;
        _scheduleReconnect();
      }
    });
  }

  bool get isConnected => _isConnected;
  int get retryCountdown => _retryCountdown;

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _countdownTimer?.cancel();
    _retryCountdown = _retryDelaySecs;
    notifyListeners();
    _reconnectTimer = Timer(Duration(seconds: _retryDelaySecs), _attemptReconnect);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_retryCountdown > 0) {
        _retryCountdown--;
        notifyListeners();
      }
    });
  }

  Future<void> _attemptReconnect() async {
    _countdownTimer?.cancel();
    if (_isReconnecting) return;
    _isReconnecting = true;
    try {
      await _authService.reconnect().timeout(const Duration(seconds: 4));
      _retryDelaySecs = 2;
      _retryCountdown = 0;
      notifyListeners();
    } catch (_) {
      _retryDelaySecs = (_retryDelaySecs * 2).clamp(2, 30);
      if (!_isConnected) _scheduleReconnect();
    } finally {
      _isReconnecting = false;
    }
  }

  Future<void> reconnect() async {
    _reconnectTimer?.cancel();
    _countdownTimer?.cancel();
    _retryDelaySecs = 2;
    await _attemptReconnect();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _countdownTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
