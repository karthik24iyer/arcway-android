import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/protocol.dart';
import '../services/websocket_service.dart';

class SessionProvider extends ChangeNotifier {
  final WebSocketService _ws;
  StreamSubscription? _subscription;
  List<SessionInfo> _sessions = [];
  String? _currentSessionId;
  bool _isLoading = false;
  String? _error;

  SessionProvider(this._ws) {
    _subscription = _ws.messages.listen(_onMessage);
  }

  List<SessionInfo> get sessions => List.unmodifiable(_sessions);
  String? get currentSessionId => _currentSessionId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void loadSessions() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final msg = SessionListRequest(
      timestamp: DateTime.now().toIso8601String(),
      id: 'list-${DateTime.now().millisecondsSinceEpoch}',
    );
    _ws.sendMessage(msg.toJson());
  }

  void createSession(String directory, {bool skipPermissions = false}) {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final msg = SessionCreateRequest(
      directory: directory,
      skipPermissions: skipPermissions,
      timestamp: DateTime.now().toIso8601String(),
      id: 'create-${DateTime.now().millisecondsSinceEpoch}',
    );
    _ws.sendMessage(msg.toJson());
  }

  void connectToSession(String sessionId, {bool skipPermissions = false}) {
    _currentSessionId = sessionId;
    _error = null;
    notifyListeners();

    final msg = SessionConnectRequest(
      sessionId: sessionId,
      skipPermissions: skipPermissions,
      timestamp: DateTime.now().toIso8601String(),
      id: 'connect-${DateTime.now().millisecondsSinceEpoch}',
    );
    _ws.sendMessage(msg.toJson());
  }

  void disconnectFromSession() {
    _currentSessionId = null;
    notifyListeners();
  }

  void terminateSession(String sessionId) {
    final msg = SessionTerminateRequest(
      sessionId: sessionId,
      timestamp: DateTime.now().toIso8601String(),
      id: 'terminate-${DateTime.now().millisecondsSinceEpoch}',
    );
    _ws.sendMessage(msg.toJson());
  }

  void _onMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;

    switch (type) {
      case 'session_list_response':
        final response = SessionListResponse.fromJson(msg);
        _sessions = response.sessions;
        _isLoading = false;
        _error = null;
        notifyListeners();

      case 'session_create_response':
        final response = SessionCreateResponse.fromJson(msg);
        _isLoading = false;
        if (response.success) {
          _error = null;
          loadSessions();
        } else {
          _error = response.message ?? 'Failed to create session';
          notifyListeners();
        }

      case 'session_connect_response':
        final response = SessionConnectResponse.fromJson(msg);
        if (!response.success) {
          _currentSessionId = null;
          _error = response.message ?? 'Failed to connect to session';
          notifyListeners();
        }

      case 'session_terminate_response':
        final response = SessionTerminateResponse.fromJson(msg);
        if (response.success) {
          _error = null;
          loadSessions();
        } else {
          _error = response.message ?? 'Failed to terminate session';
          notifyListeners();
        }

      case 'error':
        _isLoading = false;
        _error = (msg['data']?['message'] as String?) ?? 'Server error';
        notifyListeners();

      case 'status_update':
        final update = StatusUpdate.fromJson(msg);
        final idx = _sessions.indexWhere((s) => s.id == update.sessionId);
        if (idx >= 0) {
          _sessions[idx] = SessionInfo(
            id: _sessions[idx].id,
            name: _sessions[idx].name,
            workingDirectory: _sessions[idx].workingDirectory,
            created: _sessions[idx].created,
            lastActivity: update.lastActivity,
            isActive: update.status == SessionStatus.active,
            status: update.status,
            pid: _sessions[idx].pid,
          );
          notifyListeners();
        }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
