import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/protocol.dart';
import '../services/websocket_service.dart';

class SessionProvider extends ChangeNotifier {
  final WebSocketService _ws;
  StreamSubscription? _subscription;
  List<SessionInfo> _sessions = [];
  String? _currentSessionId;
  String? _sessionCreatedId;
  bool _isLoading = false;
  String? _error;
  bool _lastSkipPermissions = false;
  bool _isSessionConnected = false;
  List<String> _terminateAllQueue = [];

  SessionProvider(this._ws) {
    _subscription = _ws.messages.listen(_onMessage);
  }

  List<SessionInfo> get sessions => List.unmodifiable(_sessions);
  String? get currentSessionId => _currentSessionId;
  String? get sessionCreatedId => _sessionCreatedId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSessionConnected => _isSessionConnected;

  void clearSessionCreatedId() { _sessionCreatedId = null; }

  void _setLoading() {
    _isLoading = true;
    _error = null;
    notifyListeners();
  }

  void loadSessions() {
    _setLoading();
    final msg = SessionListRequest(
      timestamp: DateTime.now().toIso8601String(),
      id: 'list-${DateTime.now().millisecondsSinceEpoch}',
    );
    _ws.sendMessage(msg.toJson());
  }

  void createSession(String directory, {bool skipPermissions = false}) {
    _lastSkipPermissions = skipPermissions;
    _setLoading();
    final msg = SessionCreateRequest(
      directory: directory,
      skipPermissions: skipPermissions,
      timestamp: DateTime.now().toIso8601String(),
      id: 'create-${DateTime.now().millisecondsSinceEpoch}',
    );
    _ws.sendMessage(msg.toJson());
  }

  void setCurrentSession(String sessionId, {bool skipPermissions = false}) {
    _lastSkipPermissions = skipPermissions;
    _currentSessionId = sessionId;
    _isSessionConnected = false;
    _error = null;
    notifyListeners();
  }

  void connectToSession(String sessionId, {bool skipPermissions = false, int? cols, int? rows}) {
    _currentSessionId = sessionId;
    _isSessionConnected = false;
    _error = null;
    notifyListeners();

    final msg = SessionConnectRequest(
      sessionId: sessionId,
      skipPermissions: skipPermissions,
      cols: cols,
      rows: rows,
      timestamp: DateTime.now().toIso8601String(),
      id: 'connect-${DateTime.now().millisecondsSinceEpoch}',
    );
    _ws.sendMessage(msg.toJson());
  }

  void disconnectFromSession() {
    _currentSessionId = null;
    _isSessionConnected = false;
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

  void terminateAllSessions() {
    if (_sessions.isEmpty) return;
    _terminateAllQueue = _sessions.map((s) => s.id).toList();
    terminateSession(_terminateAllQueue.removeAt(0));
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
          final newSessionId = response.session?.id ?? response.sessionId;
          if (newSessionId != null) {
            _sessionCreatedId = newSessionId;
            setCurrentSession(newSessionId, skipPermissions: _lastSkipPermissions);
          } else {
            loadSessions();
          }
        } else {
          _error = response.message ?? 'Failed to create session';
        }
        notifyListeners();

      case 'session_connect_response':
        final response = SessionConnectResponse.fromJson(msg);
        if (response.success) {
          _isSessionConnected = true;
          if (_currentSessionId != null) {
            final idx = _sessions.indexWhere((s) => s.id == _currentSessionId);
            if (idx >= 0) _sessions[idx] = _sessions[idx].copyWith(status: SessionStatus.active, isActive: true);
          }
          notifyListeners();
        } else {
          _currentSessionId = null;
          _isSessionConnected = false;
          _error = response.message ?? 'Failed to connect to session';
          notifyListeners();
        }

      case 'session_terminate_response':
        final response = SessionTerminateResponse.fromJson(msg);
        if (_terminateAllQueue.isNotEmpty) {
          if (!response.success) {
            _error = response.message ?? 'Failed to terminate session';
            notifyListeners();
          }
          terminateSession(_terminateAllQueue.removeAt(0));
        } else if (response.success) {
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
          _sessions[idx] = _sessions[idx].copyWith(
            lastActivity: update.lastActivity,
            isActive: update.status == SessionStatus.active,
            status: update.status,
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
