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

class _TerminalScreenState extends State<TerminalScreen> {
  late final Terminal _terminal;
  late final WebSocketService _ws;
  late final TextEditingController _inputController;
  late final FocusNode _inputFocusNode;
  StreamSubscription? _outputSub;
  int _seqNum = 0;
  String? _sessionId;
  Timer? _resizeDebounce;
  // True until session_connect_response arrives; gates the loading overlay.
  late bool _isConnecting;
  late final ConnectionProvider _connectionProvider;
  bool _wasDisconnected = false;
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
  }

  void _onConnectionChange() {
    if (!_connectionProvider.isConnected) {
      _wasDisconnected = true;
    } else if (_wasDisconnected && _sessionId != null && mounted) {
      _wasDisconnected = false;
      setState(() => _isConnecting = true);
      context.read<SessionProvider>().connectToSession(
        _sessionId!,
        skipPermissions: context.read<SettingsProvider>().skipPermissions,
      );
    }
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
    // Only follow output if the user is within one viewport of the bottom.
    if (pos.pixels >= pos.maxScrollExtent - pos.viewportDimension) {
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
        // isolate AppBar in Consumer so session status changes
        // don't trigger a full widget rebuild (and a TerminalView repaint).
        title: Consumer<SessionProvider>(
          builder: (context, sessionProvider, _) {
            final idx = _sessionId != null ? sessionProvider.sessions.indexWhere((s) => s.id == _sessionId) : -1;
            final session = idx >= 0 ? sessionProvider.sessions[idx] : null;
            final titleText = session != null && session.name.isNotEmpty
                ? session.name
                : _sessionId?.substring(0, 8) ?? 'Terminal';
            // Removed status badge — all open chats are active
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
                  skipPermissions: context.read<SettingsProvider>().skipPermissions,
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // isolated Consumer so the banner appearing/disappearing
            // doesn't rebuild TerminalView.
            Consumer<ConnectionProvider>(
              builder: (context, connectionProvider, _) {
                if (!connectionProvider.isConnected) {
                  return Container(
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
                  );
                }
                return const SizedBox.shrink();
              },
            ),
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
                          theme: _draculaTheme,
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
                    const Positioned.fill(child: _SessionLoadingOverlay()),
                ],
              ),
            ),
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
    return Container(
      color: const Color(0xFF21222C),
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
              style: const TextStyle(
                color: Color(0xFFF8F8F2),
                fontSize: 13,
                fontFamily: 'JetBrainsMono',
              ),
              decoration: InputDecoration(
                hintText: 'Type command…',
                hintStyle: const TextStyle(color: Color(0xFF6272A4), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF282A36),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF44475A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF44475A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFBD93F9)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: _sendLine,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBD93F9),
              foregroundColor: const Color(0xFF282A36),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 6),
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

class _SessionLoadingOverlay extends StatefulWidget {
  const _SessionLoadingOverlay();

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
    return Container(
      color: const Color(0xFF282A36),
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
                        Color.lerp(
                          const Color(0xFFBD93F9),
                          const Color(0xFF8BE9FD),
                          _controller.value,
                        )!,
                      ),
                      backgroundColor: const Color(0xFF44475A),
                    ),
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF44475A),
                  ),
                  child: const Center(
                    child: Text(
                      '>_',
                      style: TextStyle(
                        color: Color(0xFFBD93F9),
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
                return Text(
                  'Starting session$dots$pad',
                  style: const TextStyle(
                    color: Color(0xFFF8F8F2),
                    fontSize: 14,
                    fontFamily: 'JetBrainsMono',
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'loading history…',
              style: TextStyle(
                color: Color(0xFF6272A4),
                fontSize: 12,
                fontFamily: 'JetBrainsMono',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
