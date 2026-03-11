import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/protocol.dart';
import '../providers/auth_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/status_dot.dart';

class SessionListScreen extends StatefulWidget {
  const SessionListScreen({super.key});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionProvider>().loadSessions();
    });
  }

  void _createSession() {
    _isCreating = true;
    final settings = context.read<SettingsProvider>();
    context.read<SessionProvider>().createSession(
          settings.defaultWorkingDirectory,
          skipPermissions: settings.skipPermissions,
        );
  }

  void _connectToSession(String sessionId) {
    final settings = context.read<SettingsProvider>();
    final provider = context.read<SessionProvider>();
    provider.connectToSession(sessionId, skipPermissions: settings.skipPermissions);
    Navigator.of(context).pushNamed('/terminal').then((_) {
      if (mounted) provider.loadSessions();
    });
  }

  void _showTerminateSheet(SessionInfo session) {
    final label = session.name.isNotEmpty ? session.name : session.id;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.stop_circle_outlined,
                    color: Theme.of(context).colorScheme.error),
                title: Text(
                  'Terminate Session',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<SessionProvider>().terminateSession(session.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    final settings = context.read<SettingsProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SettingsSheet(settings: settings),
    );
  }

  void _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Logout?',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _logout();
                  },
                  child: const Text('Yes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final connectionProvider = context.watch<ConnectionProvider>();
    final sessions = sessionProvider.sessions;

    if (_isCreating && sessionProvider.sessionCreatedId != null) {
      _isCreating = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<SessionProvider>();
        provider.clearSessionCreatedId();
        if (!mounted) return;
        Navigator.of(context).pushNamed('/terminal').then((_) {
          if (mounted) provider.loadSessions();
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Chats'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacementNamed('/devices'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _showLogoutConfirmDialog,
          ),
          Consumer<SettingsProvider>(
            builder: (context, settings, _) => IconButton(
              icon: Icon(
                settings.isDarkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
              ),
              tooltip: settings.isDarkMode ? 'Switch to light' : 'Switch to dark',
              onPressed: settings.toggleTheme,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!connectionProvider.isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              color: Theme.of(context).colorScheme.error,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.onError),
                  const SizedBox(width: 6),
                  Text(
                    'Disconnected from server',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onError,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          if (sessionProvider.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              color: Theme.of(context).colorScheme.tertiary,
              child: Text(
                sessionProvider.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          Expanded(
            child: sessionProvider.isLoading && sessions.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      final conn = context.read<ConnectionProvider>();
                      if (!conn.isConnected) await conn.reconnect();
                      sessionProvider.loadSessions();
                    },
                    child: sessions.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.45,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Icon(
                                        Icons.terminal_rounded,
                                        size: 34,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No active sessions',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap + to start a new session',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
                            itemCount: sessions.length,
                            itemBuilder: (context, index) =>
                                _buildSessionCard(sessions[index]),
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSession,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildSessionCard(SessionInfo session) {
    final isActive = session.status == SessionStatus.active;

    final statusColor = switch (session.status) {
      SessionStatus.active => const Color(0xFF21B568),
      SessionStatus.idle => const Color(0xFFFFB86C),
      SessionStatus.crashed => const Color(0xFFF07178),
    };

    final displayName = session.name.isNotEmpty ? session.name : session.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isActive
                ? statusColor.withValues(alpha: 0.5)
                : Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _connectToSession(session.id),
          onLongPress: () => _showTerminateSheet(session),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                StatusDot(color: statusColor, pulse: isActive),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              session.workingDirectory,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (session.lastActivity.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _relativeTime(session.lastActivity),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (isActive)
                  IconButton(
                    icon: const Icon(Icons.stop_circle_outlined, size: 20),
                    color: Theme.of(context).dividerColor,
                    onPressed: () =>
                        context.read<SessionProvider>().terminateSession(session.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.settings});
  final SettingsProvider settings;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final TextEditingController _dirController;

  @override
  void initState() {
    super.initState();
    _dirController =
        TextEditingController(text: widget.settings.defaultWorkingDirectory);
  }

  @override
  void dispose() {
    widget.settings.setDefaultWorkingDirectory(_dirController.text);
    _dirController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 4, 20, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _dirController,
              decoration: const InputDecoration(
                labelText: 'Default Working Directory',
                hintText: '~',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              onChanged: widget.settings.setDefaultWorkingDirectory,
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              title: const Text('Skip Permissions'),
              subtitle: const Text(
                'Run claude with --dangerously-skip-permissions',
                style: TextStyle(fontSize: 11),
              ),
              value: widget.settings.skipPermissions,
              onChanged: (v) => widget.settings.setSkipPermissions(v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }
}
