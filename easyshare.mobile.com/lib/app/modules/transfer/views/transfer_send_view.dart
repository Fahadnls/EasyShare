import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../controllers/transfer_send_controller.dart';

class TransferSendView extends GetView<TransferSendController> {
  const TransferSendView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _CanvasBackground(),
          SafeArea(
            child: Obx(() {
              final url = controller.serverUrl.value;
              final isSetup = controller.files.isEmpty;

              if (isSetup) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    _ScreenHeader(
                      title: 'Send files',
                      subtitle: 'Prepare the transfer on this device.',
                      action: const _AddMenu(),
                    ),
                    const SizedBox(height: 20),
                    _StatusPanel(
                      status: controller.statusText.value,
                      count: controller.files.length,
                    ),
                    const SizedBox(height: 18),
                    const _SelectionPanel(),
                    if (Platform.isMacOS) ...[
                      const SizedBox(height: 18),
                      const _MacDropZone(expanded: true),
                    ],
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  _ScreenHeader(
                    title: 'Send files',
                    subtitle: 'Choose a receiver, then send.',
                    action: const _AddMenu(),
                  ),
                  const SizedBox(height: 20),
                  _StatusPanel(
                    status: controller.statusText.value,
                    count: controller.files.length,
                  ),
                  const SizedBox(height: 18),
                  const _SelectionPanel(compact: true),
                  const SizedBox(height: 18),
                  const _SendProgressPanel(),
                  const SizedBox(height: 18),
                  const _NearbyPanel(),
                  const SizedBox(height: 18),
                  if (Platform.isMacOS) ...[
                    const _MacDropZone(),
                    const SizedBox(height: 18),
                  ],
                  _SharePanel(
                    url: url,
                    statusText: controller.statusText.value,
                  ),
                  const SizedBox(height: 18),
                  _TransferCodePanel(url: url),
                  const SizedBox(height: 18),
                  const _FileList(),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _AddMenu extends GetView<TransferSendController> {
  const _AddMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Add files or folder',
      icon: const Icon(Icons.add_rounded),
      onSelected: (value) {
        if (value == 'folder') {
          controller.pickFolder();
        } else if (value == 'restart') {
          controller.startServer();
        } else {
          controller.pickFiles();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'files',
          child: ListTile(
            leading: Icon(Icons.insert_drive_file_rounded),
            title: Text('Add files'),
          ),
        ),
        PopupMenuItem(
          value: 'folder',
          child: ListTile(
            leading: Icon(Icons.folder_copy_rounded),
            title: Text('Add folder'),
          ),
        ),
        PopupMenuItem(
          value: 'restart',
          child: ListTile(
            leading: Icon(Icons.refresh_rounded),
            title: Text('Restart transfer'),
          ),
        ),
      ],
    );
  }
}

class _SelectionPanel extends GetView<TransferSendController> {
  const _SelectionPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final options = <(IconData, String, VoidCallback)>[
      (Icons.insert_drive_file_rounded, 'Files', controller.pickFiles),
      (Icons.photo_library_rounded, 'Photos', controller.pickPhotos),
      (Icons.video_library_rounded, 'Videos', controller.pickVideos),
      (Icons.description_rounded, 'Documents', controller.pickDocuments),
      (Icons.folder_copy_rounded, 'Folder', controller.pickFolder),
      if (Platform.isAndroid) (Icons.apps_rounded, 'Apps', controller.openApps),
    ];
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              compact ? 'Add more' : 'What do you want to send?',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!compact) ...[
              const SizedBox(height: 5),
              Text(
                'You can combine multiple file types in one transfer.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 620 ? 3 : 2;
                const spacing = 10.0;
                final width =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final option in options)
                      SizedBox(
                        width: width,
                        child: Material(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: option.$3,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 15,
                              ),
                              child: Column(
                                children: [
                                  Icon(option.$1, size: 27),
                                  const SizedBox(height: 7),
                                  Text(
                                    option.$2,
                                    maxLines: 1,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CanvasBackground extends StatelessWidget {
  const _CanvasBackground();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            cs.secondaryContainer.withValues(alpha: 0.45),
            cs.primaryContainer.withValues(alpha: 0.3),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 48, right: 20),
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: Get.back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(subtitle, style: textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        action,
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.status, required this.count});

  final String status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cs.onPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(Icons.upload_file_rounded, color: cs.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transfer status',
                  style: textTheme.labelLarge?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.84),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.isEmpty ? 'Preparing transfer...' : status,
                  style: textTheme.bodyMedium?.copyWith(color: cs.onPrimary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.onPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count files',
              style: textTheme.labelLarge?.copyWith(color: cs.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendProgressPanel extends GetView<TransferSendController> {
  const _SendProgressPanel();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Obx(() {
      if (!controller.hasTransferStarted.value) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waiting for receiver',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select a nearby device or let the receiver scan the QR code. Progress appears when downloading starts.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      final percent = controller.progress * 100;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transfer progress',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${percent.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: controller.totalBytes == 0 ? 0 : controller.progress,
                minHeight: 9,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _Metric(
                    label: 'Size',
                    value: _formatTransferBytes(controller.totalBytes),
                  ),
                  _Metric(
                    label: 'Sent',
                    value: _formatTransferBytes(controller.sentBytes.value),
                  ),
                  _Metric(
                    label: 'Remaining',
                    value: _formatTransferBytes(controller.remainingBytes),
                  ),
                  _Metric(
                    label: 'Speed',
                    value:
                        '${(controller.transferSpeed.value / (1024 * 1024)).toStringAsFixed(2)} MB/s',
                  ),
                  _Metric(
                    label: 'Time left',
                    value: _formatDuration(controller.estimatedTime),
                  ),
                ],
              ),
              if (controller.connectionStatus.value == 'failed') ...[
                const SizedBox(height: 12),
                Text(
                  'The receiver can retry safely; completed bytes are not re-downloaded.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _NearbyPanel extends GetView<TransferSendController> {
  const _NearbyPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final devices = controller.nearbyDevices;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nearby receivers',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _connectionLabel(controller.connectionStatus.value),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: controller.isDiscovering.value
                        ? null
                        : controller.discoverDevices,
                    icon: controller.isDiscovering.value
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    tooltip: 'Search again',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (devices.isEmpty)
                Text(
                  controller.isDiscovering.value
                      ? 'Searching the local network...'
                      : 'No receiver found. Open Receive on the other device, or use the QR code below.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                ...devices.map(
                  (device) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Icon(_deviceIcon(device.platform)),
                    ),
                    title: Text(device.name),
                    subtitle: Text(device.platform),
                    trailing: controller.selectedDevice.value?.id == device.id
                        ? Icon(
                            controller.connectionStatus.value == 'connected'
                                ? Icons.check_circle_rounded
                                : Icons.sync_rounded,
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () => controller.chooseDevice(device),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text('$label: $value', style: Theme.of(context).textTheme.bodySmall);
  }
}

String _connectionLabel(String status) {
  switch (status) {
    case 'connecting':
      return 'Connecting...';
    case 'connected':
      return 'Connected';
    case 'failed':
      return 'Connection failed — tap a device to retry';
    default:
      return 'Searching for devices with Receive open';
  }
}

IconData _deviceIcon(String platform) {
  if (platform == 'android') return Icons.android_rounded;
  if (platform == 'ios') return Icons.phone_iphone_rounded;
  return Icons.computer_rounded;
}

String _formatDuration(Duration? duration) {
  if (duration == null) return '—';
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';
}

String _formatTransferBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  final value = unitIndex == 0
      ? size.toStringAsFixed(0)
      : size.toStringAsFixed(1);
  return '$value ${units[unitIndex]}';
}

class _SharePanel extends StatelessWidget {
  const _SharePanel({required this.url, required this.statusText});

  final String url;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canShare = url.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              canShare ? 'Receiver scan area' : 'Waiting for files',
              style: textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              canShare
                  ? 'The other device can scan this and start downloading immediately.'
                  : 'Add files and Next Share will generate a receiver link automatically.',
              style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: url.isEmpty
                ? Container(
                    key: const ValueKey('empty'),
                    width: 260,
                    height: 260,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 54,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          statusText.isEmpty
                              ? 'Drop files or choose them to begin.'
                              : statusText,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    key: const ValueKey('qr'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: QrImageView(
                      data: url,
                      size: 232,
                      backgroundColor: Colors.white,
                    ),
                  ),
          ),
          if (url.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              url,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _MacDropZone extends GetView<TransferSendController> {
  const _MacDropZone({this.expanded = false});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(expanded ? 28 : 20),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: expanded ? 84 : 68,
            height: expanded ? 84 : 68,
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              Icons.file_upload_outlined,
              size: expanded ? 42 : 34,
              color: cs.secondary,
            ),
          ),
          SizedBox(height: expanded ? 18 : 14),
          Text(
            'Drag files here on Mac',
            style: textTheme.titleLarge?.copyWith(fontSize: expanded ? 24 : 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Drop one or many files into this window, or choose them manually.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: expanded ? 22 : 16),
          FilledButton.icon(
            onPressed: controller.pickFiles,
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('Choose files'),
          ),
          if (expanded) ...[
            const SizedBox(height: 14),
            Text(
              'The QR and transfer code will appear as soon as files are ready.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _TransferCodePanel extends GetView<TransferSendController> {
  const _TransferCodePanel({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transfer code', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            url.isEmpty
                ? 'The connection code appears after the transfer is ready.'
                : 'Use this if scanning the QR code is inconvenient.',
            style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(7),
            ),
            child: SelectableText(
              url.isEmpty
                  ? 'Preparing transfer code...'
                  : controller.transferCode.value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: url.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(text: controller.transferCode.value),
                      );
                      Get.snackbar(
                        'Code copied',
                        'Paste it on the receiver device to start the transfer.',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy code'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileList extends GetView<TransferSendController> {
  const _FileList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selected files', style: textTheme.titleLarge),
          const SizedBox(height: 14),
          if (controller.files.isEmpty)
            Text('No files selected.', style: textTheme.bodyMedium)
          else
            ...controller.files.map(
              (f) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  children: [
                    _FileThumbnail(item: f),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName(f),
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatBytes(f.size),
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _displayName(SendFileItem item) {
    final raw = item.name.trim();
    if (raw.isNotEmpty) return raw;
    return item.path.split(Platform.pathSeparator).last;
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex += 1;
    }
    final value = unitIndex == 0
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(1);
    return '$value ${units[unitIndex]}';
  }
}

class _FileThumbnail extends StatelessWidget {
  const _FileThumbnail({required this.item});

  final SendFileItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final path = item.path.toLowerCase();
    final isImage = _matches(path, const [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.heic',
      '.heif',
      '.bmp',
    ]);
    final isVideo = _matches(path, const [
      '.mp4',
      '.mov',
      '.m4v',
      '.avi',
      '.mkv',
      '.webm',
    ]);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 52,
        height: 52,
        color: cs.primaryContainer,
        child: isImage
            ? Image.file(
                File(item.path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _FallbackThumb(
                  icon: Icons.image_rounded,
                  color: cs.primary,
                ),
              )
            : isVideo
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFF1F2A44)),
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white.withValues(alpha: 0.92),
                    size: 28,
                  ),
                ],
              )
            : _FallbackThumb(
                icon: Icons.insert_drive_file_rounded,
                color: cs.primary,
              ),
      ),
    );
  }

  bool _matches(String path, List<String> suffixes) {
    for (final suffix in suffixes) {
      if (path.endsWith(suffix)) return true;
    }
    return false;
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(child: Icon(icon, color: color, size: 28));
  }
}
