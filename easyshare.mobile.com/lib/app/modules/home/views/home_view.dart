import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../../../routes/app_pages.dart';

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
                  child: _actionCard(
                    cs: cs,
                    icon: Icons.send,
                    title: 'Send',
                    subtitle: 'Pick a file and send to a paired device.',
                    buttonText: 'Send File',
                    onPressed: _startSendFlow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionCard(
                    cs: cs,
                    icon: Icons.download,
                    title: 'Receive',
                    subtitle: 'Connect to a device to receive files.',
                    buttonText: 'Receive',
                    onPressed: _startReceiveFlow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

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

  Widget _actionCard({
    required ColorScheme cs,
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.primary,
            child: Icon(icon, color: cs.onPrimary, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Future<void> _startSendFlow() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (res == null || res.files.isEmpty) return;

    Get.toNamed(
      Routes.TRANSFER_SEND,
      arguments: {'files': res.files},
    );
  }

  Future<void> _startReceiveFlow() async {
    Get.toNamed(Routes.TRANSFER_RECEIVE);
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
