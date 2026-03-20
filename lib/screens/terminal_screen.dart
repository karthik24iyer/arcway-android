import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import '../models/protocol.dart';
import '../providers/connection_provider.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../services/websocket_service.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

abstract final class _TerminalPalette {
  // Light chrome
  static const lightBg = Color(0xFFFDF6E3); // matches Solarized bg — no seam
  static const lightSurface = Color(0xFFEEE8D5);
  static const lightBorder = Color(0xFFDDDDDD);
  static const lightText = Color(0xFF212121);
  static const lightHint = Color(0xFF9E9E9E);
  static const lightAccent = Color(0xFF2563EB);
  // Dark chrome (Dracula-matched)
  static const darkBg = Color(0xFF21222C);
  static const darkSurface = Color(0xFF282A36);
  static const darkBorder = Color(0xFF44475A);
  static const darkText = Color(0xFFF8F8F2);
  static const darkHint = Color(0xFF6272A4);
  static const darkAccent = Color(0xFF4797F8);
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final Terminal _terminal;
  late final WebSocketService _ws;
  late final TextEditingController _inputController;
  late final FocusNode _inputFocusNode;
  StreamSubscription? _outputSub;
  int _seqNum = 0;
  String? _sessionId;
  Timer? _resizeDebounce;
  int _termCols = 0;
  int _termRows = 0;
  // True until session_connect_response arrives; gates the loading overlay.
  late bool _isConnecting;
  bool _isNetworkIssue = false;
  late final ConnectionProvider _connectionProvider;
  Timer? _disconnectTimer;
  static const _inputAreaHeight = 100.0;
  final _terminalScrollController = ScrollController();

  static const _draculaTheme = TerminalTheme(
    cursor: Color(0x00000000),
    selection: Color(0xFF44475A),
    foreground: Color(0xFFF8F8F2),
    background: Color(0xFF282A36),
    black: Color(0xFF21222C),
    red: Color(0xFFFF5555),
    green: Color(0xFF50FA7B),
    yellow: Color(0xFFF1FA8C),
    blue: Color(0xFFBD93F9),
    magenta: Color(0xFFFF79C6),
    cyan: Color(0xFF8BE9FD),
    white: Color(0xFFF8F8F2),
    brightBlack: Color(0xFF6272A4),
    brightRed: Color(0xFFFF6E6E),
    brightGreen: Color(0xFF69FF94),
    brightYellow: Color(0xFFFFFFA5),
    brightBlue: Color(0xFFD6ACFF),
    brightMagenta: Color(0xFFFF92DF),
    brightCyan: Color(0xFFA4FFFF),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFFFFB86C),
    searchHitBackgroundCurrent: Color(0xFFFF79C6),
    searchHitForeground: Color(0xFF282A36),
  );

  static const _solarizedLightTheme = TerminalTheme(
    cursor: Color(0xFF657B83),
    selection: Color(0xFFEEE8D5),
    foreground: Color(0xFF657B83),
    background: Color(0xFFFDF6E3),
    black: Color(0xFF073642),
    red: Color(0xFFDC322F),
    green: Color(0xFF859900),
    yellow: Color(0xFFB58900),
    blue: Color(0xFF268BD2),
    magenta: Color(0xFFD33682),
    cyan: Color(0xFF2AA198),
    white: Color(0xFFEEE8D5),
    brightBlack: Color(0xFF002B36),
    brightRed: Color(0xFFCB4B16),
    brightGreen: Color(0xFF586E75),
    brightYellow: Color(0xFF657B83),
    brightBlue: Color(0xFF839496),
    brightMagenta: Color(0xFF6C71C4),
    brightCyan: Color(0xFF93A1A1),
    brightWhite: Color(0xFFFDF6E3),
    searchHitBackground: Color(0xFFB58900),
    searchHitBackgroundCurrent: Color(0xFFD33682),
    searchHitForeground: Color(0xFFFDF6E3),
  );

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 5000);
    _inputController = TextEditingController();
    _inputFocusNode = FocusNode();
    _ws = context.read<WebSocketService>();
    final sessionProvider = context.read<SessionProvider>();
    _sessionId = sessionProvider.currentSessionId;
    _isConnecting = !sessionProvider.isSessionConnected;

    _connectionProvider = context.read<ConnectionProvider>();
    _connectionProvider.addListener(_onConnectionChange);

    _terminal.onResize = _onTerminalResize;
    _terminal.addListener(_onTerminalUpdate);
    _outputSub = _ws.messages.listen(_onServerMessage);

    if (_sessionId != null && !sessionProvider.isSessionConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _sessionId == null) return;
        context.read<SessionProvider>().connectToSession(
          _sessionId!,
          cols: _termCols > 0 ? _termCols : null,
          rows: _termRows > 0 ? _termRows : null,
          skipPermissions: context.read<SettingsProvider>().skipPermissions,
        );
      });
    }
  }

  void _onConnectionChange() {
    if (!_connectionProvider.isConnected) {
      _disconnectTimer?.cancel();
      _disconnectTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) _disconnect();
      });
      if (mounted) setState(() { _isConnecting = true; _isNetworkIssue = true; });
    } else if (_isNetworkIssue) {
      _disconnectTimer?.cancel();
      if (mounted) {
        setState(() { _isConnecting = true; _isNetworkIssue = false; });
        context.read<SessionProvider>().connectToSession(
          _sessionId!,
          cols: _termCols > 0 ? _termCols : null,
          rows: _termRows > 0 ? _termRows : null,
          skipPermissions: context.read<SettingsProvider>().skipPermissions,
        );
      }
    }
  }

  void _onTerminalResize(int width, int height, int pixelWidth, int pixelHeight) {
    _termCols = width;
    _termRows = height;
    if (_sessionId == null) return;
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 300), () {
      final msg = TerminalResize(
        sessionId: _sessionId!,
        cols: width,
        rows: height,
        timestamp: DateTime.now().toIso8601String(),
        id: 'resize-${DateTime.now().millisecondsSinceEpoch}',
      );
      _ws.sendMessage(msg.toJson());
    });
  }

  void _onServerMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == 'terminal_output') {
      final output = TerminalOutput.fromJson(msg);
      if (output.sessionId == _sessionId) {
        _terminal.write(output.output);
      }
    } else if (type == 'session_connect_response') {
      // Server has finished setting up the session (history sent, PTY attached).
      if (_isConnecting && mounted) {
        setState(() => _isConnecting = false);
        // Explicitly jump to bottom after overlay disappears — also resets
        // xterm's internal _stickToBottom flag to true.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _terminalScrollController.hasClients) {
            _terminalScrollController.jumpTo(
              _terminalScrollController.position.maxScrollExtent,
            );
          }
        });
      }
    }
  }

  // Manage scroll manually to work around xterm v4 stickToBottom race condition.
  void _onTerminalUpdate() {
    if (!mounted || !_terminalScrollController.hasClients) return;
    final pos = _terminalScrollController.position;
    // Only follow output if user is essentially at the bottom (within 5px).
    // When _onTerminalUpdate fires, layout hasn't run yet so maxScrollExtent is
    // still the old value — for a user AT the bottom this is always true.
    // A small threshold (vs the old viewportDimension) lets users freely scroll
    // up by even a tiny amount without being snapped back on the next PTY update.
    if (pos.pixels >= pos.maxScrollExtent - 5.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _terminalScrollController.hasClients) {
          _terminalScrollController.jumpTo(
            _terminalScrollController.position.maxScrollExtent,
          );
        }
      });
    }
  }

  void _disconnect() {
    context.read<SessionProvider>().disconnectFromSession();
    Navigator.of(context).pop();
  }

  void _sendRawInput(String data) {
    if (_sessionId == null) return;
    final msg = TerminalInput(
      sessionId: _sessionId!,
      input: data,
      sequenceNumber: _seqNum++,
      timestamp: DateTime.now().toIso8601String(),
      id: 'vk-${DateTime.now().millisecondsSinceEpoch}',
    );
    _ws.sendMessage(msg.toJson());
  }

  void _sendLine() {
    final text = _inputController.text;
    if (text.isNotEmpty) _sendRawInput(text);
    _sendEnter();
    _inputController.clear();
    _inputFocusNode.unfocus();
  }

  void _sendEnter() {
    if (_sessionId == null) return;
    final msg = SpecialKeyInput(
      sessionId: _sessionId!,
      key: 'enter',
      modifiers: [],
      sequenceNumber: _seqNum++,
      timestamp: DateTime.now().toIso8601String(),
      id: 'sk-${DateTime.now().millisecondsSinceEpoch}',
    );
    _ws.sendMessage(msg.toJson());
  }

  @override
  void dispose() {
    _connectionProvider.removeListener(_onConnectionChange);
    _disconnectTimer?.cancel();
    _resizeDebounce?.cancel();
    _outputSub?.cancel();
    _terminal.removeListener(_onTerminalUpdate);
    _terminalScrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // viewInsetsOf only moves the input overlay, not the terminal canvas.
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      // prevent scaffold from resizing the body when keyboard opens.
      // Without this, the Column squishes TerminalView → onResize fires → tmux reflows content.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        centerTitle: false,
        // isolate AppBar in Consumer so session status changes
        // don't trigger a full widget rebuild (and a TerminalView repaint).
        title: Consumer<SessionProvider>(
          builder: (context, sessionProvider, _) {
            final idx = _sessionId != null ? sessionProvider.sessions.indexWhere((s) => s.id == _sessionId) : -1;
            final session = idx >= 0 ? sessionProvider.sessions[idx] : null;
            final titleText = session != null && session.name.isNotEmpty
                ? session.name
                : _sessionId?.substring(0, 8) ?? 'Terminal';
            return Text(
              titleText,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15),
            );
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _disconnect,
        ),
        actions: [
          if (!_isConnecting)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => _isConnecting = true);
                context.read<SessionProvider>().connectToSession(
                  _sessionId!,
                  cols: _termCols > 0 ? _termCols : null,
                  rows: _termRows > 0 ? _termRows : null,
                  skipPermissions: context.read<SettingsProvider>().skipPermissions,
                );
              },
            ),
          Consumer<SettingsProvider>(
            builder: (context, settings, _) => IconButton(
              icon: Icon(
                settings.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              ),
              onPressed: settings.toggleTheme,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stack keeps TerminalView at a fixed size while the
            // input overlay floats above the keyboard. No canvas resize = no reflow.
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: _inputAreaHeight, // reserve space for virtual keyboard + input bar
                    child: RepaintBoundary(
                      child: FocusScope(
                        canRequestFocus: false,
                        child: TerminalView(
                          _terminal,
                          theme: context.watch<SettingsProvider>().isDarkMode
                              ? _draculaTheme
                              : _solarizedLightTheme,
                          scrollController: _terminalScrollController,
                          textStyle: const TerminalStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 13,
                          ),
                          autofocus: false,
                          deleteDetection: true,
                          keyboardType: TextInputType.visiblePassword,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: keyboardHeight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildVirtualKeyboard(),
                        _buildInputBar(),
                      ],
                    ),
                  ),
                  if (_isConnecting)
                    Positioned.fill(child: _SessionLoadingOverlay(isNetworkIssue: _isNetworkIssue)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVirtualKeyboard() {
    final isDark = context.watch<SettingsProvider>().isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _TerminalPalette.darkSurface : _TerminalPalette.lightBg,
        border: Border(top: BorderSide(color: isDark ? _TerminalPalette.darkBorder : _TerminalPalette.lightBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('Clear/Rewind', () { _sendRawInput('\x1b'); _sendRawInput('\x1b'); }),
            _buildKey('Mode', () => _sendRawInput('\x1b[Z')),
            _buildKey('/', () => _sendRawInput('/')),
            _buildKey('/rename', () => _sendRawInput('/rename ')),
            _buildKey('↑', () => _sendRawInput('\x1b[A'), horizontalPadding: 12),
            _buildKey('↓', () => _sendRawInput('\x1b[B'), horizontalPadding: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final isDark = context.watch<SettingsProvider>().isDarkMode;
    return Container(
      color: isDark ? _TerminalPalette.darkBg : _TerminalPalette.lightBg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocusNode,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: TextStyle(
                color: isDark ? _TerminalPalette.darkText : _TerminalPalette.lightText,
                fontSize: 13,
                fontFamily: 'JetBrainsMono',
              ),
              decoration: InputDecoration(
                hintText: 'Type command…',
                hintStyle: TextStyle(color: isDark ? _TerminalPalette.darkHint : _TerminalPalette.lightHint, fontSize: 13),
                filled: true,
                fillColor: isDark ? _TerminalPalette.darkSurface : _TerminalPalette.lightSurface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: isDark ? _TerminalPalette.darkBorder : _TerminalPalette.lightBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: isDark ? _TerminalPalette.darkBorder : _TerminalPalette.lightBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: isDark ? _TerminalPalette.darkAccent : _TerminalPalette.lightAccent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: _sendLine,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? _TerminalPalette.darkAccent : _TerminalPalette.lightAccent,
              foregroundColor: isDark ? _TerminalPalette.darkSurface : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Send', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String label, VoidCallback onTap, {bool active = false, double horizontalPadding = 8}) {
    final isDark = context.watch<SettingsProvider>().isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 6),
        decoration: BoxDecoration(
          color: active ? (isDark ? _TerminalPalette.darkAccent : _TerminalPalette.lightAccent) : (isDark ? _TerminalPalette.darkBorder : _TerminalPalette.lightBorder),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? (isDark ? _TerminalPalette.darkSurface : Colors.white) : (isDark ? _TerminalPalette.darkText : _TerminalPalette.lightText),
            fontSize: 12,
            fontFamily: 'JetBrainsMono',
          ),
        ),
      ),
    );
  }
}

class _SessionLoadingOverlay extends StatefulWidget {
  const _SessionLoadingOverlay({required this.isNetworkIssue});
  final bool isNetworkIssue;

  @override
  State<_SessionLoadingOverlay> createState() => _SessionLoadingOverlayState();
}

class _SessionLoadingOverlayState extends State<_SessionLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<SettingsProvider>().isDarkMode;
    final bg = isDark ? _TerminalPalette.darkSurface : _TerminalPalette.lightBg;
    final accent = isDark ? _TerminalPalette.darkAccent : _TerminalPalette.lightAccent;
    final spinnerTrack = isDark ? _TerminalPalette.darkBorder : _TerminalPalette.lightBorder;
    final iconBg = isDark ? _TerminalPalette.darkBorder : _TerminalPalette.lightBorder;
    final primaryText = isDark ? _TerminalPalette.darkText : _TerminalPalette.lightText;
    final secondaryText = isDark ? _TerminalPalette.darkHint : _TerminalPalette.lightHint;

    return Container(
      color: bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) => CircularProgressIndicator(
                      value: null,
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(
                        Color.lerp(accent, isDark ? const Color(0xFF8BE9FD) : const Color(0xFF26C6DA), _controller.value)!,
                      ),
                      backgroundColor: spinnerTrack,
                    ),
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
                  child: Center(
                    child: Text(
                      '>_',
                      style: TextStyle(
                        color: accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final dots = '.' * ((_controller.value * 4).floor() % 4);
                final pad = '   '.substring(dots.length);
                final label = widget.isNetworkIssue ? 'Network issue$dots$pad' : 'Starting session$dots$pad';
                return Text(
                  label,
                  style: TextStyle(color: primaryText, fontSize: 14, fontFamily: 'JetBrainsMono'),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              widget.isNetworkIssue ? 'retrying…' : 'loading history…',
              style: TextStyle(color: secondaryText, fontSize: 12, fontFamily: 'JetBrainsMono'),
            ),
          ],
        ),
      ),
    );
  }
}
