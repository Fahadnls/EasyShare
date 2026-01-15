import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BT Share (Android)'),
        actions: [
          IconButton(
            onPressed: controller.refreshBonded,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Obx(() {
        final enabled = controller.isEnabled.value;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _topCard(cs, enabled),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: enabled
                        ? controller.startDiscovery
                        : controller.enableBluetooth,
                    icon: Icon(enabled ? Icons.search : Icons.bluetooth),
                    label: Text(enabled ? 'Scan Nearby' : 'Enable Bluetooth'),
                  ),
                ),
                const SizedBox(width: 10),
                Obx(() {
                  return IconButton.filledTonal(
                    onPressed: controller.isDiscovering.value
                        ? controller.stopDiscovery
                        : null,
                    icon: const Icon(Icons.stop),
                  );
                }),
              ],
            ),

            const SizedBox(height: 18),
            const Text(
              'Paired Devices',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (controller.bonded.isEmpty) {
                return const Text(
                  'No paired devices found. Pair from Android settings first.',
                );
              }
              return Column(
                children: controller.bonded
                    .map(
                      (d) => _deviceTile(
                        title: d.name ?? 'Unknown',
                        subtitle: d.address,
                        trailing: const Icon(Icons.chat_bubble_outline),
                        onTap: () => controller.openChat(d),
                      ),
                    )
                    .toList(),
              );
            }),

            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Nearby Devices',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Obx(
                  () => controller.isDiscovering.value
                      ? const Text('Scanning...')
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Obx(() {
              if (controller.discovered.isEmpty) {
                return const Text('No nearby devices yet. Tap "Scan Nearby".');
              }
              return Column(
                children: controller.discovered.map((r) {
                  final BluetoothDevice d = r.device;
                  final name = d.name ?? 'Unknown';
                  final rssi = r.rssi;
                  return _deviceTile(
                    title: name,
                    subtitle: '${d.address}  •  RSSI $rssi',
                    trailing: const Icon(Icons.chat_bubble_outline),
                    onTap: () => controller.openChat(d),
                  );
                }).toList(),
              );
            }),
          ],
        );
      }),
    );
  }

  Widget _topCard(ColorScheme cs, bool enabled) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: enabled ? cs.primary : cs.outlineVariant,
            child: Icon(
              enabled ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: cs.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              enabled ? 'Bluetooth is ON' : 'Bluetooth is OFF',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deviceTile({
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      child: ListTile(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
