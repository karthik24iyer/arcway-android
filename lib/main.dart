import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/session_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/device_list_screen.dart';
import 'screens/login_screen.dart';
import 'screens/session_list_screen.dart';
import 'screens/terminal_screen.dart';
import 'services/auth_service.dart';
import 'services/websocket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final wsService = WebSocketService();
  final authService = AuthService(wsService);
  final settingsProvider = SettingsProvider();
  final hasSavedSession = await authService.loadSavedSession();
  await settingsProvider.load();
  runApp(ClaudeRemoteApp(
    wsService: wsService,
    authService: authService,
    settingsProvider: settingsProvider,
    initialRoute: hasSavedSession ? '/devices' : '/login',
  ));
}

class ClaudeRemoteApp extends StatefulWidget {
  final WebSocketService wsService;
  final AuthService authService;
  final SettingsProvider settingsProvider;
  final String initialRoute;

  const ClaudeRemoteApp({
    super.key,
    required this.wsService,
    required this.authService,
    required this.settingsProvider,
    required this.initialRoute,
  });

  @override
  State<ClaudeRemoteApp> createState() => _ClaudeRemoteAppState();
}

class _ClaudeRemoteAppState extends State<ClaudeRemoteApp> {
  late final WebSocketService _wsService;
  late final AuthService _authService;
  late final SettingsProvider _settingsProvider;

  @override
  void initState() {
    super.initState();
    _wsService = widget.wsService;
    _authService = widget.authService;
    _settingsProvider = widget.settingsProvider;
  }

  @override
  void dispose() {
    _wsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<WebSocketService>.value(value: _wsService),
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider(_wsService, _authService),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(_authService),
        ),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(_wsService),
        ),
        ChangeNotifierProvider.value(value: _settingsProvider),
      ],
      child: MaterialApp(
        title: 'Arcway',
        debugShowCheckedModeBanner: false,
        theme: _buildDraculaTheme(),
        initialRoute: widget.initialRoute,
        routes: {
          '/login': (context) => const LoginScreen(),
          '/devices': (context) => const DeviceListScreen(),
          '/sessions': (context) => const SessionListScreen(),
          '/terminal': (context) => const TerminalScreen(),
        },
      ),
    );
  }

  ThemeData _buildDraculaTheme() {
    // Dracula color palette
    const background = Color(0xFF282A36);
    const currentLine = Color(0xFF44475A);
    const foreground = Color(0xFFF8F8F2);
    const comment = Color(0xFF6272A4);
    const green = Color(0xFF50FA7B);
    const pink = Color(0xFFFF79C6);
    const purple = Color(0xFFBD93F9);
    const red = Color(0xFFFF5555);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      fontFamily: 'JetBrainsMono',
      colorScheme: const ColorScheme.dark(
        primary: purple,
        secondary: pink,
        surface: background,
        error: red,
        onPrimary: background,
        onSecondary: background,
        onSurface: foreground,
        onError: foreground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: currentLine,
        foregroundColor: foreground,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: purple,
          foregroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: currentLine,
        hintStyle: const TextStyle(color: comment),
        labelStyle: const TextStyle(color: foreground),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: comment),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: comment),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: purple),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: foreground, fontFamily: 'JetBrainsMono'),
        bodyLarge: TextStyle(color: foreground, fontFamily: 'JetBrainsMono'),
        bodyMedium: TextStyle(color: foreground, fontFamily: 'JetBrainsMono'),
        labelLarge: TextStyle(color: foreground, fontFamily: 'JetBrainsMono'),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: green,
        foregroundColor: background,
      ),
      cardTheme: const CardThemeData(
        color: currentLine,
        elevation: 0,
      ),
      dividerColor: comment,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: currentLine,
        contentTextStyle: TextStyle(color: foreground, fontFamily: 'JetBrainsMono'),
      ),
    );
  }
}
