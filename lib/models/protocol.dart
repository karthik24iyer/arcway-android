import 'dart:convert';

abstract class BaseMessage {
  final String type;
  final String timestamp;
  final String id;

  BaseMessage({
    required this.type,
    required this.timestamp,
    required this.id,
  });

  Map<String, dynamic> toJson();

  factory BaseMessage.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'welcome':
        return WelcomeMessage.fromJson(json);
      case 'auth_response':
        return AuthResponse.fromJson(json);
      case 'session_list_response':
        return SessionListResponse.fromJson(json);
      case 'session_create_response':
        return SessionCreateResponse.fromJson(json);
      case 'session_connect_response':
        return SessionConnectResponse.fromJson(json);
      case 'session_terminate_response':
        return SessionTerminateResponse.fromJson(json);
      case 'terminal_output':
        return TerminalOutput.fromJson(json);
      case 'error':
        return ErrorMessage.fromJson(json);
      case 'connection_error':
        return ConnectionError.fromJson(json);
      case 'status_update':
        return StatusUpdate.fromJson(json);
      default:
        throw Exception('Unknown message type: ${json['type']}');
    }
  }
}

class WelcomeMessage extends BaseMessage {
  final String message;
  final String? serverVersion;

  WelcomeMessage({
    required this.message,
    this.serverVersion,
    required super.timestamp,
    required super.id,
  }) : super(type: 'welcome');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'message': message,
        if (serverVersion != null) 'server_version': serverVersion,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }

  factory WelcomeMessage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return WelcomeMessage(
      message: data['message'] as String? ?? '',
      serverVersion: data['server_version'] as String?,
      timestamp: json['timestamp'] as String? ?? '',
      id: json['id'] as String? ?? '',
    );
  }
}

class AuthResponse extends BaseMessage {
  final bool success;
  final String? token;
  final String? expiresAt;
  final UserInfo? userInfo;
  final String? error;
  final String? message;
  final int? retryAfter;

  AuthResponse({
    required this.success,
    this.token,
    this.expiresAt,
    this.userInfo,
    this.error,
    this.message,
    this.retryAfter,
    required super.timestamp,
    required super.id,
  }) : super(type: 'auth_response');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'success': success,
        if (token != null) 'token': token,
        if (expiresAt != null) 'expires_at': expiresAt,
        if (userInfo != null) 'user_info': userInfo!.toJson(),
        if (error != null) 'error': error,
        if (message != null) 'message': message,
        if (retryAfter != null) 'retry_after': retryAfter,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return AuthResponse(
      success: data['success'] as bool? ?? false,
      token: data['token'] as String?,
      expiresAt: data['expires_at'] as String?,
      userInfo: data['user_info'] != null
          ? UserInfo.fromJson(data['user_info'] as Map<String, dynamic>)
          : null,
      error: data['error'] as String?,
      message: data['message'] as String?,
      retryAfter: data['retry_after'] as int?,
      timestamp: json['timestamp'] as String? ?? '',
      id: json['id'] as String? ?? '',
    );
  }
}

class UserInfo {
  final String username;
  final List<String> permissions;

  UserInfo({
    required this.username,
    required this.permissions,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'permissions': permissions,
    };
  }

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      username: json['username'] as String? ?? '',
      permissions: List<String>.from(json['permissions'] as List? ?? []),
    );
  }
}

enum SessionStatus { active, idle, crashed }

class SessionInfo {
  final String id;
  final String name;
  final String workingDirectory;
  final String created;
  final String lastActivity;
  final bool isActive;
  final SessionStatus status;

  SessionInfo({
    required this.id,
    required this.name,
    required this.workingDirectory,
    required this.created,
    required this.lastActivity,
    required this.isActive,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': id,
      'name': name,
      'directory': workingDirectory,
      'created': created,
      'lastActivity': lastActivity,
      'isActive': isActive,
      'status': status.name,
    };
  }

  SessionInfo copyWith({
    String? id,
    String? name,
    String? workingDirectory,
    String? created,
    String? lastActivity,
    bool? isActive,
    SessionStatus? status,
  }) {
    return SessionInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      created: created ?? this.created,
      lastActivity: lastActivity ?? this.lastActivity,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
    );
  }

  // Server sends camelCase keys; some older responses use snake_case fallbacks.
  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      id: (json['sessionId'] ?? json['id']) as String? ?? '',
      name: json['name'] as String? ?? '',
      workingDirectory: (json['directory'] ?? json['working_directory']) as String? ?? '',
      created: json['created'] as String? ?? '',
      lastActivity: (json['lastActivity'] ?? json['last_activity']) as String? ?? '',
      isActive: (json['isActive'] ?? json['is_active']) as bool? ?? false,
      status: SessionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SessionStatus.idle,
      ),
    );
  }
}

class SessionListRequest extends BaseMessage {
  SessionListRequest({
    required super.timestamp,
    required super.id,
  }) : super(type: 'session_list_request');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {},
      'timestamp': timestamp,
      'id': id,
    };
  }
}

class SessionListResponse extends BaseMessage {
  final List<SessionInfo> sessions;

  SessionListResponse({
    required this.sessions,
    required super.timestamp,
    required super.id,
  }) : super(type: 'session_list_response');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'sessions': sessions.map((s) => s.toJson()).toList(),
      },
      'timestamp': timestamp,
      'id': id,
    };
  }

  factory SessionListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return SessionListResponse(
      sessions: (data['sessions'] as List? ?? [])
          .map((s) => SessionInfo.fromJson(s as Map<String, dynamic>))
          .toList(),
      timestamp: json['timestamp'] as String? ?? '',
      id: json['id'] as String? ?? '',
    );
  }
}

class SessionCreateRequest extends BaseMessage {
  final String directory;
  final bool skipPermissions;

  SessionCreateRequest({
    required this.directory,
    this.skipPermissions = false,
    required super.timestamp,
    required super.id,
  }) : super(type: 'session_create_request');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'directory': directory,
        'skip_permissions': skipPermissions,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }
}

class SessionCreateResponse extends BaseMessage {
  final bool success;
  final SessionInfo? session;
  final String? sessionId;
  final String? error;
  final String? message;

  SessionCreateResponse({
    required this.success,
    this.session,
    this.sessionId,
    this.error,
    this.message,
    required super.timestamp,
    required super.id,
  }) : super(type: 'session_create_response');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'success': success,
        if (session != null) 'session': session!.toJson(),
        if (sessionId != null) 'session_id': sessionId,
        if (error != null) 'error': error,
        if (message != null) 'message': message,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }

  factory SessionCreateResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return SessionCreateResponse(
      success: data['success'] as bool? ?? false,
      session: data['session'] != null
          ? SessionInfo.fromJson(data['session'] as Map<String, dynamic>)
          : null,
      sessionId: data['session_id'] as String?,
      error: data['error'] as String?,
      message: data['message'] as String?,
      timestamp: json['timestamp'] as String? ?? '',
      id: json['id'] as String? ?? '',
    );
  }
}

class SessionConnectRequest extends BaseMessage {
  final String sessionId;
  final bool skipPermissions;
  final int? cols;
  final int? rows;

  SessionConnectRequest({
    required this.sessionId,
    this.skipPermissions = false,
    this.cols,
    this.rows,
    required super.timestamp,
    required super.id,
  }) : super(type: 'session_connect_request');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'session_id': sessionId,
        'skip_permissions': skipPermissions,
        if (cols != null) 'cols': cols,
        if (rows != null) 'rows': rows,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }
}

class SessionConnectResponse extends BaseMessage {
  final bool success;
  final String? sessionId;
  final TerminalSize? terminalSize;
  final String? error;
  final String? message;

  SessionConnectResponse({
    required this.success,
    this.sessionId,
    this.terminalSize,
    this.error,
    this.message,
    required super.timestamp,
    required super.id,
  }) : super(type: 'session_connect_response');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'success': success,
        if (sessionId != null) 'session_id': sessionId,
        if (terminalSize != null) 'terminal_size': terminalSize!.toJson(),
        if (error != null) 'error': error,
        if (message != null) 'message': message,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }

  factory SessionConnectResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return SessionConnectResponse(
      success: data['success'] as bool? ?? false,
      sessionId: data['session_id'] as String?,
      terminalSize: data['terminal_size'] != null
          ? TerminalSize.fromJson(data['terminal_size'] as Map<String, dynamic>)
          : null,
      error: data['error'] as String?,
      message: data['message'] as String?,
      timestamp: json['timestamp'] as String? ?? '',
      id: json['id'] as String? ?? '',
    );
  }
}

class SessionTerminateRequest extends BaseMessage {
  final String sessionId;

  SessionTerminateRequest({
    required this.sessionId,
    required super.timestamp,
    required super.id,
  }) : super(type: 'session_terminate_request');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'session_id': sessionId,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }
}

class SessionTerminateResponse extends BaseMessage {
  final bool success;
  final String? sessionId;
  final String? error;
  final String? message;

  SessionTerminateResponse({
    required this.success,
    this.sessionId,
    this.error,
    this.message,
    required super.timestamp,
    required super.id,
  }) : super(type: 'session_terminate_response');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'success': success,
        if (sessionId != null) 'session_id': sessionId,
        if (error != null) 'error': error,
        if (message != null) 'message': message,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }

  factory SessionTerminateResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return SessionTerminateResponse(
      success: data['success'] as bool? ?? false,
      sessionId: data['session_id'] as String?,
      error: data['error'] as String?,
      message: data['message'] as String?,
      timestamp: json['timestamp'] as String? ?? '',
      id: json['id'] as String? ?? '',
    );
  }
}

class TerminalSize {
  final int rows;
  final int cols;

  TerminalSize({
    required this.rows,
    required this.cols,
  });

  Map<String, dynamic> toJson() {
    return {
      'rows': rows,
      'cols': cols,
    };
  }

  factory TerminalSize.fromJson(Map<String, dynamic> json) {
    return TerminalSize(
      rows: json['rows'] as int? ?? 24,
      cols: json['cols'] as int? ?? 80,
    );
  }
}

class TerminalInput extends BaseMessage {
  final String sessionId;
  final String input;
  final int sequenceNumber;

  TerminalInput({
    required this.sessionId,
    required this.input,
    required this.sequenceNumber,
    required super.timestamp,
    required super.id,
  }) : super(type: 'terminal_input');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'session_id': sessionId,
        'input': input,
        'sequence_number': sequenceNumber,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }
}

class TerminalOutput extends BaseMessage {
  final String sessionId;
  final String output;
  final int sequenceNumber;
  final bool isComplete;

  TerminalOutput({
    required this.sessionId,
    required this.output,
    required this.sequenceNumber,
    required this.isComplete,
    required super.timestamp,
    required super.id,
  }) : super(type: 'terminal_output');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'session_id': sessionId,
        'output': output,
        'sequence_number': sequenceNumber,
        'is_complete': isComplete,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }

  factory TerminalOutput.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return TerminalOutput(
      sessionId: data['session_id'] as String? ?? '',
      output: data['output'] as String? ?? '',
      sequenceNumber: data['sequence_number'] as int? ?? 0,
      isComplete: data['is_complete'] as bool? ?? false,
      timestamp: json['timestamp'] as String? ?? '',
      id: json['id'] as String? ?? '',
    );
  }
}

class TerminalResize extends BaseMessage {
  final String sessionId;
  final int rows;
  final int cols;

  TerminalResize({
    required this.sessionId,
    required this.rows,
    required this.cols,
    required super.timestamp,
    required super.id,
  }) : super(type: 'terminal_resize');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'session_id': sessionId,
        'rows': rows,
        'cols': cols,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }
}

class SpecialKeyInput extends BaseMessage {
  final String sessionId;
  final String key;
  final List<String> modifiers;
  final int sequenceNumber;

  SpecialKeyInput({
    required this.sessionId,
    required this.key,
    required this.modifiers,
    required this.sequenceNumber,
    required super.timestamp,
    required super.id,
  }) : super(type: 'special_key_input');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'session_id': sessionId,
        'key': key,
        'modifiers': modifiers,
        'sequence_number': sequenceNumber,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }
}

enum ErrorCode {
  invalidCredentials,
  tokenExpired,
  tokenInvalid,
  rateLimited,
  unauthorized,
  sessionNotFound,
  sessionCreateFailed,
  sessionLimitExceeded,
  directoryNotFound,
  directoryAccessDenied,
  terminalNotReady,
  terminalCrashed,
  terminalTimeout,
  invalidInput,
  connectionLost,
  connectionTimeout,
  serverUnavailable,
  protocolError,
}

class ErrorMessage extends BaseMessage {
  final ErrorCode errorCode;
  final String message;
  final bool retryable;
  final dynamic details;

  ErrorMessage({
    required this.errorCode,
    required this.message,
    required this.retryable,
    this.details,
    required super.timestamp,
    required super.id,
  }) : super(type: 'error');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'error_code': errorCodeToString(errorCode),
        'message': message,
        'retryable': retryable,
        if (details != null) 'details': details,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }

  factory ErrorMessage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return ErrorMessage(
      errorCode: stringToErrorCode(data['error_code'] as String? ?? ''),
      message: data['message'] as String? ?? '',
      retryable: data['retryable'] as bool? ?? false,
      details: data['details'],
      timestamp: json['timestamp'] as String? ?? '',
      id: json['id'] as String? ?? '',
    );
  }

  static String errorCodeToString(ErrorCode code) {
    switch (code) {
      case ErrorCode.invalidCredentials: return 'INVALID_CREDENTIALS';
      case ErrorCode.tokenExpired: return 'TOKEN_EXPIRED';
      case ErrorCode.tokenInvalid: return 'TOKEN_INVALID';
      case ErrorCode.rateLimited: return 'RATE_LIMITED';
      case ErrorCode.unauthorized: return 'UNAUTHORIZED';
      case ErrorCode.sessionNotFound: return 'SESSION_NOT_FOUND';
      case ErrorCode.sessionCreateFailed: return 'SESSION_CREATE_FAILED';
      case ErrorCode.sessionLimitExceeded: return 'SESSION_LIMIT_EXCEEDED';
      case ErrorCode.directoryNotFound: return 'DIRECTORY_NOT_FOUND';
      case ErrorCode.directoryAccessDenied: return 'DIRECTORY_ACCESS_DENIED';
      case ErrorCode.terminalNotReady: return 'TERMINAL_NOT_READY';
      case ErrorCode.terminalCrashed: return 'TERMINAL_CRASHED';
      case ErrorCode.terminalTimeout: return 'TERMINAL_TIMEOUT';
      case ErrorCode.invalidInput: return 'INVALID_INPUT';
      case ErrorCode.connectionLost: return 'CONNECTION_LOST';
      case ErrorCode.connectionTimeout: return 'CONNECTION_TIMEOUT';
      case ErrorCode.serverUnavailable: return 'SERVER_UNAVAILABLE';
      case ErrorCode.protocolError: return 'PROTOCOL_ERROR';
    }
  }

  static ErrorCode stringToErrorCode(String code) {
    switch (code) {
      case 'INVALID_CREDENTIALS': return ErrorCode.invalidCredentials;
      case 'TOKEN_EXPIRED': return ErrorCode.tokenExpired;
      case 'TOKEN_INVALID': return ErrorCode.tokenInvalid;
      case 'RATE_LIMITED': return ErrorCode.rateLimited;
      case 'UNAUTHORIZED': return ErrorCode.unauthorized;
      case 'SESSION_NOT_FOUND': return ErrorCode.sessionNotFound;
      case 'SESSION_CREATE_FAILED': return ErrorCode.sessionCreateFailed;
      case 'SESSION_LIMIT_EXCEEDED': return ErrorCode.sessionLimitExceeded;
      case 'DIRECTORY_NOT_FOUND': return ErrorCode.directoryNotFound;
      case 'DIRECTORY_ACCESS_DENIED': return ErrorCode.directoryAccessDenied;
      case 'TERMINAL_NOT_READY': return ErrorCode.terminalNotReady;
      case 'TERMINAL_CRASHED': return ErrorCode.terminalCrashed;
      case 'TERMINAL_TIMEOUT': return ErrorCode.terminalTimeout;
      case 'INVALID_INPUT': return ErrorCode.invalidInput;
      case 'CONNECTION_LOST': return ErrorCode.connectionLost;
      case 'CONNECTION_TIMEOUT': return ErrorCode.connectionTimeout;
      case 'SERVER_UNAVAILABLE': return ErrorCode.serverUnavailable;
      case 'PROTOCOL_ERROR': return ErrorCode.protocolError;
      default: return ErrorCode.protocolError;
    }
  }
}

class ConnectionError extends BaseMessage {
  final ErrorCode errorCode;
  final String message;
  final bool retryable;
  final int? retryAfter;
  final String? sessionId;

  ConnectionError({
    required this.errorCode,
    required this.message,
    required this.retryable,
    this.retryAfter,
    this.sessionId,
    required super.timestamp,
    required super.id,
  }) : super(type: 'connection_error');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'error_code': ErrorMessage.errorCodeToString(errorCode),
        'message': message,
        'retryable': retryable,
        if (retryAfter != null) 'retry_after': retryAfter,
        if (sessionId != null) 'session_id': sessionId,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }

  factory ConnectionError.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return ConnectionError(
      errorCode: ErrorMessage.stringToErrorCode(data['error_code'] as String? ?? ''),
      message: data['message'] as String? ?? '',
      retryable: data['retryable'] as bool? ?? false,
      retryAfter: data['retry_after'] as int?,
      sessionId: data['session_id'] as String?,
      timestamp: json['timestamp'] as String? ?? '',
      id: json['id'] as String? ?? '',
    );
  }
}

class StatusUpdate extends BaseMessage {
  final String sessionId;
  final SessionStatus status;
  final String lastActivity;
  final double cpuUsage;
  final double memoryUsage;

  StatusUpdate({
    required this.sessionId,
    required this.status,
    required this.lastActivity,
    required this.cpuUsage,
    required this.memoryUsage,
    required super.timestamp,
    required super.id,
  }) : super(type: 'status_update');

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': {
        'session_id': sessionId,
        'status': status.name,
        'last_activity': lastActivity,
        'cpu_usage': cpuUsage,
        'memory_usage': memoryUsage,
      },
      'timestamp': timestamp,
      'id': id,
    };
  }

  factory StatusUpdate.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return StatusUpdate(
      sessionId: data['session_id'] as String? ?? '',
      status: SessionStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => SessionStatus.idle,
      ),
      lastActivity: data['last_activity'] as String? ?? '',
      cpuUsage: (data['cpu_usage'] as num?)?.toDouble() ?? 0.0,
      memoryUsage: (data['memory_usage'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] as String? ?? '',
      id: json['id'] as String? ?? '',
    );
  }
}

class MessageValidator {
  static bool validateMessage(String jsonString) {
    try {
      final json = jsonDecode(jsonString);
      return json is Map<String, dynamic> &&
          json.containsKey('type') &&
          json.containsKey('timestamp') &&
          json.containsKey('id') &&
          json.containsKey('data');
    } catch (e) {
      return false;
    }
  }

  static String? getMessageType(String jsonString) {
    try {
      final json = jsonDecode(jsonString);
      return json['type'] as String?;
    } catch (e) {
      return null;
    }
  }
}
