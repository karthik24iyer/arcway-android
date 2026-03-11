// Pure Widget Rendering Tests
// No mocking, no backend needed. Tests widget tree structure only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:claude_remote_android/main.dart';
import 'package:claude_remote_android/providers/auth_provider.dart';
import 'package:claude_remote_android/providers/connection_provider.dart';
import 'package:claude_remote_android/providers/session_provider.dart';
import 'package:claude_remote_android/providers/settings_provider.dart';
import 'package:claude_remote_android/screens/login_screen.dart';
import 'package:claude_remote_android/services/auth_service.dart';
import 'package:claude_remote_android/services/websocket_service.dart';

// Real services (not connected -- only used for provider wiring)
Widget _buildTestApp({String initialRoute = '/login'}) {
  final ws = WebSocketService();
  final auth = AuthService(ws);
  return MultiProvider(
    providers: [
      Provider<WebSocketService>.value(value: ws),
      ChangeNotifierProvider(create: (_) => ConnectionProvider(ws, auth)),
      ChangeNotifierProvider(create: (_) => AuthProvider(auth)),
      ChangeNotifierProvider(create: (_) => SessionProvider(ws)),
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(),
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    ),
  );
}

void main() {
  // App structure
  group('App structure', () {
    test('ClaudeRemoteApp is a StatefulWidget', () {
      final ws = WebSocketService();
      final auth = AuthService(ws);
      expect(
        ClaudeRemoteApp(
          wsService: ws,
          authService: auth,
          settingsProvider: SettingsProvider(),
        ),
        isA<StatefulWidget>(),
      );
    });
  });

  // Login screen rendering
  group('Login screen rendering', () {
    testWidgets('shows Sign in with Google button', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('shows terminal icon', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.byIcon(Icons.terminal), findsOneWidget);
    });

    testWidgets('shows Claude Remote title', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      expect(find.text('Claude Remote'), findsOneWidget);
    });
  });
}
