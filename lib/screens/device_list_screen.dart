import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../providers/auth_provider.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDevices());
  }

  Future<void> _loadDevices() async {
    final devices = await context.read<AuthProvider>().fetchDevices();
    if (mounted) setState(() => _devices = devices);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _connectToDevice(String deviceId) async {
    final authProvider = context.read<AuthProvider>();
    try {
      await authProvider.connectToDevice(deviceId);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/sessions');
    } catch (e) {
      _showError('Connection failed: $e');
    }
  }

  Future<void> _generateLinkToken() async {
    try {
      final token = await context.read<AuthProvider>().generateLinkToken();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Link Token'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Run this on your Mac (valid for 10 min):'),
              const SizedBox(height: 12),
              SelectableText(
                'RELAY_URL=$kRelayWsUrl DEVICE_TOKEN=$token npm start',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: token));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token copied to clipboard')),
                );
              },
              child: const Text('Copy Token'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Failed: $e');
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  Widget _buildBody(AuthProvider authProvider) {
    if (authProvider.isLoading && _devices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (authProvider.error != null && _devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                authProvider.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDevices,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadDevices,
      child: _devices.isEmpty
          ? const Center(child: Text('No devices found'))
          : ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                final isOnline = device['online'] == true;
                return ListTile(
                  leading: Icon(
                    Icons.circle,
                    size: 12,
                    color: isOnline
                        ? const Color(0xFF50FA7B)
                        : const Color(0xFF6272A4),
                  ),
                  title: Text(device['name'] as String? ?? device['id'] as String),
                  subtitle: Text(isOnline ? 'Online' : 'Offline'),
                  onTap: isOnline
                      ? () => _connectToDevice(device['id'] as String)
                      : null,
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Systems'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _generateLinkToken,
        tooltip: 'Add Mac',
        child: const Icon(Icons.add),
      ),
      body: _buildBody(authProvider),
    );
  }
}
