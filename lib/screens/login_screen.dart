import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _googleSignIn = GoogleSignIn(
    clientId: defaultTargetPlatform == TargetPlatform.iOS
        ? '260109272007-4lat0ms48rhhr8h73d71ophja0bi81fs.apps.googleusercontent.com'
        : null,
    serverClientId: '260109272007-6bqlpils04thtrp426reojome3hnlef2.apps.googleusercontent.com',
  );

  late final AnimationController _cursorCtrl;

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cursorCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = context.read<AuthProvider>();
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        _showError('Failed to get ID token');
        return;
      }

      final success = await authProvider.loginWithGoogle(idToken);
      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushReplacementNamed('/devices');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _handleAppleSignIn() async {
    final authProvider = context.read<AuthProvider>();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null) {
        _showError('Failed to get Apple identity token');
        return;
      }

      final success = await authProvider.loginWithApple(identityToken);
      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushReplacementNamed('/devices');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final isLoading = authProvider.isLoading;
    final isDark = settings.isDarkMode;

    const darkBg1 = Color(0xFF060C18);
    const darkBg2 = Color(0xFF0A1428);
    const darkPrimary = Color(0xFF4797F8);
    const darkTeal = Color(0xFF00D9C0);
    const darkSurface = Color(0xFF0D1526);
    const darkBorder = Color(0xFF1C2B4A);

    const lightBg1 = Color(0xFFF0F4FA);
    const lightBg2 = Color(0xFFE4EDFF);
    const lightPrimary = Color(0xFF2563EB);
    const lightTeal = Color(0xFF0891B2);

    final primary = isDark ? darkPrimary : lightPrimary;
    final teal = isDark ? darkTeal : lightTeal;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [darkBg1, darkBg2, darkBg1]
                : [lightBg1, lightBg2, lightBg1],
          ),
        ),
        child: Stack(
          children: [
            // Subtle radial glow behind the card (dark only)
            if (isDark)
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 350,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        darkPrimary.withValues(alpha: 0.07),
                        Colors.transparent,
                      ],
                      radius: 0.8,
                    ),
                  ),
                ),
              ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
                        decoration: BoxDecoration(
                          color: isDark
                              ? darkSurface.withValues(alpha: 0.88)
                              : Colors.white.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark
                                ? darkBorder.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.7),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? darkPrimary.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.07),
                              blurRadius: 60,
                              spreadRadius: 0,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Gradient icon
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [primary, teal],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(alpha: isDark ? 0.45 : 0.3),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.terminal, size: 34, color: Colors.white),
                            ),
                            const SizedBox(height: 22),

                            // Title with blinking cursor
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'Arcway',
                                  style: TextStyle(
                                    color: primary,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'JetBrainsMono',
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                FadeTransition(
                                  opacity: _cursorCtrl,
                                  child: Text(
                                    '▋',
                                    style: TextStyle(
                                      color: teal,
                                      fontSize: 24,
                                      fontFamily: 'JetBrainsMono',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'remote terminal',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF4A6080)
                                    : const Color(0xFF94A3B8),
                                fontSize: 11,
                                letterSpacing: 2.5,
                                fontFamily: 'JetBrainsMono',
                              ),
                            ),
                            const SizedBox(height: 40),

                            if (authProvider.error != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .error
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  authProvider.error!,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _handleGoogleSignIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: isLoading
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          const Text('SIGNING IN...'),
                                        ],
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SvgPicture.asset(
                                            'assets/images/google_logo.svg',
                                            width: 20,
                                            height: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Sign in with Google',
                                            style: TextStyle(
                                              fontSize: defaultTargetPlatform == TargetPlatform.iOS ? 16 : 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            if (defaultTargetPlatform == TargetPlatform.iOS ||
                                defaultTargetPlatform == TargetPlatform.macOS) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: SignInWithAppleButton(
                                  onPressed: isLoading ? () {} : _handleAppleSignIn,
                                  style: isDark
                                      ? SignInWithAppleButtonStyle.white
                                      : SignInWithAppleButtonStyle.black,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Theme toggle — top right
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 22,
                  ),
                  color: isDark
                      ? const Color(0xFF4A6080)
                      : const Color(0xFF94A3B8),
                  tooltip: isDark ? 'Switch to light' : 'Switch to dark',
                  onPressed: settings.toggleTheme,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
