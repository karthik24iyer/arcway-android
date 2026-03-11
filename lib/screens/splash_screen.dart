import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _cursorCtrl;

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final authService = context.read<AuthService>();
    final settingsProvider = context.read<SettingsProvider>();

    final hasSavedSession = await authService.loadSavedSession();
    await settingsProvider.load();

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      hasSavedSession ? '/devices' : '/login',
    );
  }

  @override
  void dispose() {
    _cursorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const darkBg1 = Color(0xFF060C18);
    const darkBg2 = Color(0xFF0A1428);
    const darkPrimary = Color(0xFF4797F8);
    const darkTeal = Color(0xFF00D9C0);
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
            colors: isDark ? [darkBg1, darkBg2, darkBg1] : [lightBg1, lightBg2, lightBg1],
          ),
        ),
        child: Stack(
          children: [
            if (isDark)
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [darkPrimary.withValues(alpha: 0.08), Colors.transparent],
                      radius: 0.8,
                    ),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, teal],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? darkBorder : Colors.white.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: isDark ? 0.5 : 0.35),
                          blurRadius: 40,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.terminal, size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'Arcway',
                        style: TextStyle(
                          color: primary,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'JetBrainsMono',
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(width: 3),
                      FadeTransition(
                        opacity: _cursorCtrl,
                        child: Text(
                          '▋',
                          style: TextStyle(
                            color: teal,
                            fontSize: 28,
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'remote terminal',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF4A6080) : const Color(0xFF94A3B8),
                      fontSize: 12,
                      letterSpacing: 3,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                  const SizedBox(height: 60),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
