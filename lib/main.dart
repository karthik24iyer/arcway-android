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
import 'screens/splash_screen.dart';
import 'screens/terminal_screen.dart';
import 'services/auth_service.dart';
import 'services/websocket_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final wsService = WebSocketService();
  final authService = AuthService(wsService);
  final settingsProvider = SettingsProvider();
  runApp(ClaudeRemoteApp(
    wsService: wsService,
    authService: authService,
    settingsProvider: settingsProvider,
  ));
}

class ClaudeRemoteApp extends StatefulWidget {
  final WebSocketService wsService;
  final AuthService authService;
  final SettingsProvider settingsProvider;

  const ClaudeRemoteApp({
    super.key,
    required this.wsService,
    required this.authService,
    required this.settingsProvider,
  });

  @override
  State<ClaudeRemoteApp> createState() => _ClaudeRemoteAppState();
}

class _ClaudeRemoteAppState extends State<ClaudeRemoteApp> {
  @override
  void dispose() {
    widget.wsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<WebSocketService>.value(value: widget.wsService),
        Provider<AuthService>.value(value: widget.authService),
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider(widget.wsService, widget.authService),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(widget.authService),
        ),
        ChangeNotifierProvider(
          create: (_) => SessionProvider(widget.wsService),
        ),
        ChangeNotifierProvider.value(value: widget.settingsProvider),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Arcway',
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/devices': (context) => const DeviceListScreen(),
            '/sessions': (context) => const SessionListScreen(),
            '/terminal': (context) => const TerminalScreen(),
          },
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    // Termius-inspired deep navy palette
    const bg = Color(0xFF060C18);
    const surface = Color(0xFF0D1526);
    const surfaceVar = Color(0xFF132040);
    const border = Color(0xFF1C2B4A);
    const primary = Color(0xFF4797F8);
    const teal = Color(0xFF00D9C0);
    const foreground = Color(0xFFC2D0E8);
    const muted = Color(0xFF4A6080);
    const red = Color(0xFFF07178);
    const yellow = Color(0xFFFFCB6B);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      canvasColor: surface,
      fontFamily: 'JetBrainsMono',
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: teal,
        tertiary: yellow,
        onTertiary: bg,
        surface: surface,
        error: red,
        onPrimary: Colors.white,
        onSecondary: bg,
        onSurface: foreground,
        onError: Colors.white,
        surfaceContainerHighest: surfaceVar,
        outline: border,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: foreground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'JetBrainsMono',
          letterSpacing: 1.5,
        ),
        iconTheme: IconThemeData(color: muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVar,
        hintStyle: const TextStyle(color: muted, fontSize: 13),
        labelStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: foreground, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: foreground, fontFamily: 'JetBrainsMono'),
        bodyMedium: TextStyle(color: foreground, fontFamily: 'JetBrainsMono'),
        labelLarge: TextStyle(color: foreground, fontFamily: 'JetBrainsMono'),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: border,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceVar,
        contentTextStyle: TextStyle(color: foreground, fontFamily: 'JetBrainsMono'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        dragHandleColor: border,
        showDragHandle: true,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: foreground,
        iconColor: muted,
        minLeadingWidth: 0,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(muted),
          overlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.12)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const bg = Color(0xFFF0F4FA);
    const surface = Color(0xFFFFFFFF);
    const surfaceVar = Color(0xFFE8EEF8);
    const border = Color(0xFFDDE3EF);
    const primary = Color(0xFF2563EB);
    const teal = Color(0xFF0891B2);
    const foreground = Color(0xFF0F172A);
    const muted = Color(0xFF64748B);
    const red = Color(0xFFDC2626);
    const yellow = Color(0xFFD97706);

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: bg,
      canvasColor: surface,
      fontFamily: 'JetBrainsMono',
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: teal,
        tertiary: yellow,
        onTertiary: Colors.white,
        surface: surface,
        error: red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: foreground,
        onError: Colors.white,
        surfaceContainerHighest: surfaceVar,
        outline: border,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: foreground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'JetBrainsMono',
          letterSpacing: 1.5,
        ),
        iconTheme: IconThemeData(color: muted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVar,
        hintStyle: const TextStyle(color: muted, fontSize: 13),
        labelStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: foreground, fontFamily: 'JetBrainsMono', fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: foreground, fontFamily: 'JetBrainsMono'),
        bodyMedium: TextStyle(color: foreground, fontFamily: 'JetBrainsMono'),
        labelLarge: TextStyle(color: foreground, fontFamily: 'JetBrainsMono'),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: border,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: foreground,
        contentTextStyle: TextStyle(color: Colors.white, fontFamily: 'JetBrainsMono'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
        elevation: 8,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        dragHandleColor: border,
        showDragHandle: true,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: foreground,
        iconColor: muted,
        minLeadingWidth: 0,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(muted),
          overlayColor: WidgetStateProperty.all(primary.withValues(alpha: 0.10)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
