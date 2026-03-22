import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/status_dot.dart';

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
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 48, color: Theme.of(context).dividerColor),
              const SizedBox(height: 16),
              Text(
                authProvider.error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadDevices,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.devices_other_rounded,
                    size: 34, color: Theme.of(context).dividerColor),
              ),
              const SizedBox(height: 16),
              Text(
                'No devices found',
                style: TextStyle(
                  color: Theme.of(context).dividerColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Open Arcway on your Mac to register it',
                style: TextStyle(
                  color:
                      Theme.of(context).dividerColor.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDevices,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        itemCount: _devices.length,
        itemBuilder: (context, index) => _buildDeviceCard(_devices[index]),
      ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final isOnline = device['online'] == true;
    final name =
        device['name'] as String? ?? device['id'] as String? ?? 'Unknown';
    final statusColor =
        isOnline ? const Color(0xFF21B568) : const Color(0xFF4A6080);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isOnline
                ? statusColor.withValues(alpha: 0.45)
                : Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap:
              isOnline ? () => _connectToDevice(device['id'] as String) : null,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                StatusDot(color: statusColor, pulse: isOnline),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isOnline
                              ? null
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOnline)
                  Icon(Icons.chevron_right_rounded,
                      color: Theme.of(context).dividerColor, size: 20)
                else
                  Icon(
                    Icons.signal_wifi_off_rounded,
                    color: Theme.of(context)
                        .dividerColor
                        .withValues(alpha: 0.4),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            tooltip: 'Logout',
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
      body: _buildBody(authProvider),
    );
  }
}

