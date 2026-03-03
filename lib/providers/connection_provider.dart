import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/websocket_service.dart';

class ConnectionProvider extends ChangeNotifier {
  final WebSocketService _ws;
  final AuthService _authService;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _isReconnecting = false;

  ConnectionProvider(this._ws, this._authService) {
    _subscription = _ws.connectionState.listen((connected) {
      _isConnected = connected;
      notifyListeners();
      if (!connected && !_isReconnecting) {
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 2), _reconnect);
      }
    });
  }

  bool get isConnected => _isConnected;

  Future<void> reconnect() async {
    if (_isReconnecting) return;
    _isReconnecting = true;
    try {
      await _authService.reconnect();
    } catch (_) {} finally {
      _isReconnecting = false;
    }
  }

  void _reconnect() => reconnect();

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
