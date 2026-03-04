// Protocol message serialization tests
// Pure unit tests — no Flutter, no backend.
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_remote_android/models/protocol.dart';

void main() {
  group('AuthRequest', () {
    test('toJson includes type, username, password', () {
      final req = AuthRequest(
        username: 'testuser',
        password: 'testpass',
        clientInfo: ClientInfo(platform: 'android', version: '0.1.0', deviceId: 'test-device'),
        timestamp: '2026-03-01T00:00:00Z',
        id: 'auth-1',
      );
      final json = req.toJson();
      expect(json['type'], equals('auth_request'));
      expect(json['data']['username'], equals('testuser'));
      expect(json['data']['password'], equals('testpass'));
    });
  });

  group('SessionListRequest', () {
    test('toJson has correct type', () {
      final req = SessionListRequest(
        timestamp: '2026-03-01T00:00:00Z',
        id: 'list-1',
      );
      final json = req.toJson();
      expect(json['type'], equals('session_list_request'));
    });
  });

  group('SessionCreateRequest', () {
    test('toJson includes directory and skip_permissions', () {
      final req = SessionCreateRequest(
        directory: '/home/user',
        skipPermissions: true,
        timestamp: '2026-03-01T00:00:00Z',
        id: 'create-1',
      );

      final json = req.toJson();
      expect(json['type'], equals('session_create_request'));
      expect(json['data']['directory'], equals('/home/user'));
      expect(json['data']['skip_permissions'], isTrue);
    });

    test('skip_permissions defaults to false', () {
      final req = SessionCreateRequest(
        directory: '~',
        timestamp: '2026-03-01T00:00:00Z',
        id: 'create-2',
      );
      final json = req.toJson();
      expect(json['data']['skip_permissions'], isFalse);
    });
  });

  group('SessionConnectRequest', () {
    test('toJson includes session_id and skip_permissions', () {
      final req = SessionConnectRequest(
        sessionId: 'abc-123',
        skipPermissions: true,
        timestamp: '2026-03-01T00:00:00Z',
        id: 'connect-1',
      );
      final json = req.toJson();
      expect(json['type'], equals('session_connect_request'));
      expect(json['data']['session_id'], equals('abc-123'));
      expect(json['data']['skip_permissions'], isTrue);
    });

    test('skip_permissions defaults to false', () {
      final req = SessionConnectRequest(
        sessionId: 'abc-123',
        timestamp: '2026-03-01T00:00:00Z',
        id: 'connect-2',
      );
      final json = req.toJson();
      expect(json['data']['skip_permissions'], isFalse);
    });
  });

  group('SessionTerminateRequest', () {
    test('toJson includes session_id', () {
      final req = SessionTerminateRequest(
        sessionId: 'abc-123',
        timestamp: '2026-03-01T00:00:00Z',
        id: 'terminate-1',
      );
      final json = req.toJson();
      expect(json['type'], equals('session_terminate_request'));
      expect(json['data']['session_id'], equals('abc-123'));
    });
  });

  group('TerminalInput', () {
    test('toJson includes session_id and input', () {
      final msg = TerminalInput(
        sessionId: 'abc-123',
        input: 'ls -la\n',
        sequenceNumber: 0,
        timestamp: '2026-03-01T00:00:00Z',
        id: 'input-1',
      );
      final json = msg.toJson();
      expect(json['type'], equals('terminal_input'));
      expect(json['data']['session_id'], equals('abc-123'));
      expect(json['data']['input'], equals('ls -la\n'));
    });
  });

  group('TerminalResize', () {
    test('toJson includes cols and rows', () {
      final msg = TerminalResize(
        sessionId: 'abc-123',
        cols: 80,
        rows: 24,
        timestamp: '2026-03-01T00:00:00Z',
        id: 'resize-1',
      );
      final json = msg.toJson();
      expect(json['type'], equals('terminal_resize'));
      expect(json['data']['cols'], equals(80));
      expect(json['data']['rows'], equals(24));
    });
  });

  group('SessionListResponse.fromJson', () {
    test('parses sessions array', () {
      final json = {
        'type': 'session_list_response',
        'data': {
          'sessions': [
            {
              'id': 'sess-1',
              'name': 'my-project',
              'working_directory': '/home/user',
              'created': '2026-03-01T00:00:00Z',
              'last_activity': '2026-03-01T01:00:00Z',
              'is_active': true,
              'status': 'active',
              'pid': 1234,
            }
          ]
        },
        'timestamp': '2026-03-01T00:00:00Z',
        'id': 'list-resp-1',
      };
      final response = SessionListResponse.fromJson(json);
      expect(response.sessions.length, equals(1));
      expect(response.sessions.first.id, equals('sess-1'));
      expect(response.sessions.first.status, equals(SessionStatus.active));
    });

    test('handles empty sessions array', () {
      final json = {
        'type': 'session_list_response',
        'data': {'sessions': []},
        'timestamp': '2026-03-01T00:00:00Z',
        'id': 'list-resp-2',
      };
      final response = SessionListResponse.fromJson(json);
      expect(response.sessions, isEmpty);
    });
  });
}
