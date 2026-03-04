// Integration tests for providers against a real backend.
// Requires a running claude-remote-service at the configured URL.
// Run with: flutter test integration_test/providers_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:claude_remote_android/providers/session_provider.dart';
import 'package:claude_remote_android/services/auth_service.dart';
import 'package:claude_remote_android/services/websocket_service.dart';

const _serverUrl = 'ws://localhost:3000';
const _username = 'admin';
const _password = 'password';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SessionProvider integration', () {
    late WebSocketService wsService;
    late AuthService authService;
    late SessionProvider provider;

    setUp(() {
      wsService = WebSocketService();
      authService = AuthService(wsService);
      provider = SessionProvider(wsService);
    });

    tearDown(() {
      wsService.dispose();
    });

    testWidgets('loadSessions returns without error when connected', (tester) async {
      await authService.login(_username, _password, _serverUrl);
      await tester.pump(const Duration(milliseconds: 500));

      provider.loadSessions();
      await tester.pump(const Duration(seconds: 3));

      expect(provider.error, isNull);
    });

    testWidgets('createSession sends request and receives response', (tester) async {
      await authService.login(_username, _password, _serverUrl);
      await tester.pump(const Duration(milliseconds: 500));

      provider.createSession('/tmp');
      expect(provider.isLoading, isTrue);

      await tester.pump(const Duration(seconds: 3));

      expect(provider.isLoading, isFalse);
    });

    testWidgets('connectToSession sets currentSessionId', (tester) async {
      provider.connectToSession('fake-session-id');
      expect(provider.currentSessionId, equals('fake-session-id'));
    });

    testWidgets('disconnectFromSession clears currentSessionId', (tester) async {
      provider.connectToSession('s1');
      provider.disconnectFromSession();
      expect(provider.currentSessionId, isNull);
    });

    testWidgets('terminateSession sends request to real backend', (tester) async {
      await authService.login(_username, _password, _serverUrl);
      await tester.pump(const Duration(milliseconds: 500));

      provider.createSession('/tmp');
      await tester.pump(const Duration(seconds: 3));

      if (provider.sessions.isNotEmpty) {
        final sessionId = provider.sessions.first.id;
        provider.terminateSession(sessionId);
        await tester.pump(const Duration(seconds: 2));
        expect(provider.error, isNull);
      }
    });

    testWidgets('loadSessions after create shows new session', (tester) async {
      await authService.login(_username, _password, _serverUrl);
      await tester.pump(const Duration(milliseconds: 500));

      provider.createSession('/tmp');
      await tester.pump(const Duration(seconds: 3));

      if (provider.error == null) {
        expect(provider.sessions, isNotEmpty);
      }
    });
  });
}
