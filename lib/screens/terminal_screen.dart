import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import '../models/protocol.dart';
import '../providers/connection_provider.dart';
import '../providers/session_provider.dart';
import '../services/websocket_service.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final Terminal _terminal;
  late final WebSocketService _ws;
  StreamSubscription? _outputSub;
  int _seqNum = 0;
  String? _sessionId;
  Timer? _resizeDebounce;
  bool _optionActive = false;

  static const _draculaTheme = TerminalTheme(
    cursor: Color(0xFFF8F8F2),
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

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 1000);
    _ws = context.read<WebSocketService>();
    _sessionId = context.read<SessionProvider>().currentSessionId;

    // Don't wire onOutput yet — wait for session_connect_response (ttyd pattern)
    _terminal.onResize = _onTerminalResize;

    _outputSub = _ws.messages.listen(_onServerMessage);
  }

  void _onTerminalOutput(String data) {
    if (_sessionId == null) return;
    final input = (_optionActive && data == '\x7f') ? '\x1b\x7f' : data;
    final msg = TerminalInput(
      sessionId: _sessionId!,
      input: input,
      sequenceNumber: _seqNum++,
      timestamp: DateTime.now().toIso8601String(),
      id: 'input-${DateTime.now().millisecondsSinceEpoch}',
    );
    _ws.sendMessage(msg.toJson());
  }

  void _onTerminalResize(int width, int height, int pixelWidth, int pixelHeight) {
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
      if (msg['data']?['success'] == true) {
        _terminal.onOutput = _onTerminalOutput; // session ready — allow input
      }
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

  void _onVirtualKey(VoidCallback action) => action();

  SessionInfo? _currentSession(SessionProvider provider) {
    if (_sessionId == null) return null;
    final sessions = provider.sessions;
    final idx = sessions.indexWhere((s) => s.id == _sessionId);
    return idx >= 0 ? sessions[idx] : null;
  }

  @override
  void dispose() {
    _resizeDebounce?.cancel();
    _outputSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionProvider = context.watch<ConnectionProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final session = _currentSession(sessionProvider);
    final isDisconnected = !connectionProvider.isConnected;

    final statusColor = switch (session?.status) {
      SessionStatus.active => const Color(0xFF50FA7B),
      SessionStatus.idle => const Color(0xFFFFB86C),
      SessionStatus.crashed => const Color(0xFFFF5555),
      null => const Color(0xFF6272A4),
    };
    final statusLabel = switch (session?.status) {
      SessionStatus.active => 'Active',
      SessionStatus.idle => 'Idle',
      SessionStatus.crashed => 'Crashed',
      null => 'Unknown',
    };

    final titleText = session != null && session.name.isNotEmpty
        ? session.name
        : _sessionId?.substring(0, 8) ?? 'Terminal';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                titleText,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _disconnect,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Connection lost banner
            if (isDisconnected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: const Color(0xFFFF5555),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: Color(0xFFF8F8F2), size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Connection lost',
                        style: TextStyle(color: Color(0xFFF8F8F2), fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: _disconnect,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'BACK',
                        style: TextStyle(color: Color(0xFFF8F8F2), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            // Terminal view
            Expanded(
              child: TerminalView(
                _terminal,
                theme: _draculaTheme,
                textStyle: const TerminalStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                ),
                autofocus: true,
                deleteDetection: true,
                keyboardType: TextInputType.visiblePassword,
              ),
            ),
            // Virtual keyboard
            _buildVirtualKeyboard(),
          ],
        ),
      ),
    );
  }

  Widget _buildVirtualKeyboard() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF282A36),
        border: Border(top: BorderSide(color: Color(0xFF6272A4))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('ESC', () => _onVirtualKey(() => _sendRawInput('\x1b'))),
            _buildKey('Mode', () => _onVirtualKey(() => _sendRawInput('\x1b[Z'))),
            _buildKey('/', () => _onVirtualKey(() => _sendRawInput('/'))),
            _buildKey('/rename', () => _onVirtualKey(() => _sendRawInput('/rename '))),
            _buildKey('\u2191', () => _onVirtualKey(() => _sendRawInput('\x1b[A'))),
            _buildKey('\u2193', () => _onVirtualKey(() => _sendRawInput('\x1b[B'))),
            _buildKey('Opt', () => setState(() => _optionActive = !_optionActive), active: _optionActive),
            _buildKey('\u2190', () => _onVirtualKey(() => _sendRawInput(_optionActive ? '\x1bb' : '\x1b[D'))),
            _buildKey('\u2192', () => _onVirtualKey(() => _sendRawInput(_optionActive ? '\x1bf' : '\x1b[C'))),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String label, VoidCallback onTap, {bool active = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFBD93F9) : const Color(0xFF44475A),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF282A36) : const Color(0xFFF8F8F2),
            fontSize: 12,
            fontFamily: 'JetBrainsMono',
          ),
        ),
      ),
    );
  }
}
