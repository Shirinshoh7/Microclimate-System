import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/climate_provider.dart';

class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  final _deviceIdCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _deviceIdCtrl.dispose();
    _secretCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    await _runAction(
      () => context.read<ClimateProvider>().registerDevice(
            deviceId: _deviceIdCtrl.text.trim(),
            secret: _secretCtrl.text.trim(),
            name: _nameCtrl.text.trim(),
          ),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
      if (!mounted) return;
      final provider = context.read<ClimateProvider>();
      if (provider.devices.isNotEmpty) {
        final firstId = provider.selectedDeviceId ??
            (provider.devices.first['device_id']?.toString() ??
                provider.devices.first['id']?.toString() ??
                '');
        if (firstId.isNotEmpty) {
          await provider.setSelectedDevice(firstId);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ClimateProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Devices')),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => provider.loadDevices(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'My Devices',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  if (provider.devices.isEmpty)
                    const Text(
                        'No devices. Register a new device.')
                  else
                    ...provider.devices.map(
                      (device) {
                        final id = device['device_id']?.toString() ??
                            device['id']?.toString() ??
                            '';
                        final name = device['name']?.toString() ?? id;
                        final selected = provider.selectedDeviceId == id;
                        return Card(
                          child: ListTile(
                            title: Text(name),
                            subtitle: Text(id),
                            trailing: selected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : null,
                            onTap: id.isEmpty
                                ? null
                                : () async {
                                    await provider.setSelectedDevice(id);
                                  },
                          ),
                        );
                      },
                    ),
                  const Divider(height: 32),
                  TextFormField(
                    controller: _deviceIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Device ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _secretCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Secret',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Register'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
