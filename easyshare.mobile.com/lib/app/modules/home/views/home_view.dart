import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/model/transfer_history_item.dart';
import '../../../routes/app_pages.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              children: [
                _TopBar(
                  onHistory: () => Get.toNamed(Routes.TRANSFER_HISTORY),
                  onSettings: () => Get.toNamed(Routes.SETTINGS),
                ),
                const SizedBox(height: 36),
                _ActionRow(
                  onSend: () => Get.toNamed(Routes.TRANSFER_SEND),
                  onReceive: () => Get.toNamed(Routes.TRANSFER_RECEIVE),
                ),
                const SizedBox(height: 32),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final device = _DeviceCard(
                      deviceName: controller.storage.deviceName.value,
                    );
                    const quickSend = _QuickSendCard();
                    if (constraints.maxWidth >= 700) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: device),
                          const SizedBox(width: 14),
                          const Expanded(flex: 6, child: quickSend),
                        ],
                      );
                    }
                    return Column(
                      children: [device, const SizedBox(height: 14), quickSend],
                    );
                  },
                ),
                const SizedBox(height: 14),
                const _RecentTransfersCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.deviceName});

  final String deviceName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF7C5CFC).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.devices_rounded,
                color: Color(0xFF7C5CFC),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This device',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ready to share nearby',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSendCard extends StatelessWidget {
  const _QuickSendCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick send', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickSendButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Photos',
                    action: 'photos',
                    color: const Color(0xFF00A7A0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickSendButton(
                    icon: Icons.video_library_rounded,
                    label: 'Videos',
                    action: 'videos',
                    color: const Color(0xFFFF8A3D),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickSendButton(
                    icon: Icons.description_rounded,
                    label: 'Documents',
                    action: 'documents',
                    color: const Color(0xFF5B6FF9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSendButton extends StatelessWidget {
  const _QuickSendButton({
    required this.icon,
    required this.label,
    required this.action,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed(
        Routes.TRANSFER_SEND,
        arguments: {'initialAction': action},
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransfersCard extends GetView<HomeController> {
  const _RecentTransfersCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Obx(() {
          final recent = controller.storage.history.take(3).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent transfers',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Get.toNamed(Routes.TRANSFER_HISTORY),
                    child: Text(recent.isEmpty ? 'Open history' : 'View all'),
                  ),
                ],
              ),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF7C5CFC,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.history_rounded,
                          color: Color(0xFF7C5CFC),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your sent and received files will appear here.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final item in recent) _RecentTransferTile(item: item),
            ],
          );
        }),
      ),
    );
  }
}

class _RecentTransferTile extends StatelessWidget {
  const _RecentTransferTile({required this.item});

  final TransferHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final sent = item.direction == TransferDirection.sent;
    final color = sent ? const Color(0xFF3478F6) : const Color(0xFF22B573);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          sent ? Icons.north_east_rounded : Icons.south_west_rounded,
          color: color,
        ),
      ),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${sent ? 'Sent' : 'Received'} • ${_formatBytes(item.size)}',
      ),
      trailing: Text(
        item.status == TransferHistoryStatus.completed
            ? 'Done'
            : item.status.name,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () => Get.toNamed(Routes.TRANSFER_HISTORY),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onHistory, required this.onSettings});

  final VoidCallback onHistory;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Image.asset('assets/logo_launcher.png', width: 32, height: 32),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next Share', style: textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text('Connect. Share. Done.', style: textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
        _TopBadge(
          icon: Icons.history_rounded,
          color: const Color(0xFF7C5CFC),
          tooltip: 'Transfer history',
          onTap: onHistory,
        ),
        const SizedBox(width: 10),
        _TopBadge(
          icon: Icons.settings_rounded,
          color: const Color(0xFFFF8A3D),
          tooltip: 'Settings',
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _TopBadge extends StatelessWidget {
  const _TopBadge({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3E9F3)),
          ),
          child: Icon(icon, size: 21, color: color),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.onSend, required this.onReceive});

  final VoidCallback onSend;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.send_rounded,
            label: 'Send',
            // colors: const [Color(0xFF4D9BFF), Color(0xFF2572F5)],
            colors: const [
              Color(0xFF2E86FF),
              Color(0xFF0D47A1),
              // Color(0xFF2E86FF),
              // Color(0xFF0D47A1),
              // Color(0xFF4FACFE), Color(0xFF0066FF)
            ],
            onTap: onSend,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ActionButton(
            icon: Icons.move_to_inbox_rounded,
            label: 'Receive',
            colors: const [
              // Color(0xFF67C8FF), Color(0xFF2196F3),
              Color(0xFF67C8FF),
              Color(0xFF2196F3),
              // colors: const [Color(0xFF37C98B), Color(0xFF159A70)]
            ],
            onTap: onReceive,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 12),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} ${units[unit]}';
}
