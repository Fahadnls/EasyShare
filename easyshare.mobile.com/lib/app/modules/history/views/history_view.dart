import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/ui_constants.dart';
import '../../../data/model/transfer_history_item.dart';
import '../../../widgets/app_file_tile.dart';
import '../controllers/history_controller.dart';

class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer History'),
        leading: const BackButton(),
        actions: [
          Obx(
            () => controller.storage.history.isEmpty
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: controller.clearHistory,
                    child: const Text('Clear'),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Obx(() {
            final items = controller.storage.history;
            if (items.isEmpty) {
              return const _EmptyHistory();
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _HistoryCard(
                item: items[index],
                onOpen: () => controller.openFile(items[index]),
                onOpenFolder: () => controller.openFolder(items[index]),
                onShareAgain: () => controller.shareAgain(items[index]),
                onDelete: () => controller.deleteItem(items[index]),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF7C5CFC).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(kBorderRadius + 6),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 36,
                color: Color(0xFF7C5CFC),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No transfers yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Sent and received files will appear here.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.onOpen,
    required this.onOpenFolder,
    required this.onShareAgain,
    required this.onDelete,
  });

  final TransferHistoryItem item;
  final VoidCallback onOpen;
  final VoidCallback onOpenFolder;
  final VoidCallback onShareAgain;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final sent = item.direction == TransferDirection.sent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppFileTile(
                    name: item.name,
                    path: item.location,
                    subtitle:
                        '${sent ? 'Sent' : 'Received'} • ${item.type.toUpperCase()} • ${_formatBytes(item.size)}',
                    status: '${_formatDate(item.date)} • ${item.status.name}',
                    onTap: onOpen,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton(onPressed: onOpen, child: const Text('Open')),
                      TextButton(
                        onPressed: onOpenFolder,
                        child: const Text('Folder'),
                      ),
                      TextButton(
                        onPressed: onShareAgain,
                        child: const Text('Share again'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete history item',
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
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
