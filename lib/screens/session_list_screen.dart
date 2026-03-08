import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/protocol.dart';
import '../providers/auth_provider.dart';
import '../providers/connection_provider.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';

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
    context.read<SessionProvider>().connectToSession(
      sessionId,
      skipPermissions: settings.skipPermissions,
    );
    Navigator.of(context).pushNamed('/terminal');
  }

  void _showTerminateSheet(SessionInfo session) {
    final label = session.name.isNotEmpty ? session.name : session.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF44475A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.stop_circle_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
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
      backgroundColor: const Color(0xFF44475A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => _SettingsSheet(settings: settings),
    );
  }

  void _logout() async {
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
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

    if (_isCreating && sessionProvider.currentSessionId != null && !sessionProvider.isLoading) {
      _isCreating = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushNamed('/terminal');
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arcway'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!connectionProvider.isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.error,
              child: Text(
                'Disconnected from server',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onError,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          if (sessionProvider.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFFB86C),
              child: Text(
                sessionProvider.error!,
                style: const TextStyle(color: Color(0xFF282A36), fontSize: 13),
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
                                height: MediaQuery.of(context).size.height * 0.4,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.terminal, size: 48, color: Theme.of(context).dividerColor),
                                    const SizedBox(height: 12),
                                    Text('No active sessions', style: TextStyle(color: Theme.of(context).dividerColor, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text('Tap + to create your first session', style: TextStyle(color: Theme.of(context).dividerColor, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: sessions.length,
                            itemBuilder: (context, index) => _buildSessionCard(sessions[index]),
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSession,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSessionCard(SessionInfo session) {
    final statusColor = switch (session.status) {
      SessionStatus.active => const Color(0xFF50FA7B),
      SessionStatus.idle => const Color(0xFFFFB86C),
      SessionStatus.crashed => const Color(0xFFFF5555),
    };
    final statusLabel = switch (session.status) {
      SessionStatus.active => 'Active',
      SessionStatus.idle => 'Idle',
      SessionStatus.crashed => 'Crashed',
    };
    final displayName = session.name.isNotEmpty ? session.name : session.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _connectToSession(session.id),
        onLongPress: () => _showTerminateSheet(session),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '> $displayName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.workingDirectory,
                      style: TextStyle(
                        color: Theme.of(context).dividerColor,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (session.lastActivity.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _relativeTime(session.lastActivity),
                        style: TextStyle(
                          color: Theme.of(context).dividerColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
    _dirController = TextEditingController(text: widget.settings.defaultWorkingDirectory);
  }

  @override
  void dispose() {
    _dirController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
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
