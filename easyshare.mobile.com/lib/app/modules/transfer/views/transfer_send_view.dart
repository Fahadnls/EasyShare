import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../data/service/device_discovery_service.dart';
import '../../../data/service/qr_transfer_service.dart';
import '../controllers/transfer_send_controller.dart';
import 'transfer_ui.dart';

class TransferSendView extends GetView<TransferSendController> {
  const TransferSendView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Obx(() {
            if (controller.files.isEmpty) return const _ChooseFileTypePage();
            if (controller.hasTransferStarted.value || controller.isComplete) {
              final file = controller.currentFile;
              return TransferProgressPage(
                title: 'Sending',
                peerLabel: 'Receiver',
                peerName:
                    controller.selectedDevice.value?.name ??
                    (controller.qrReceiverName.value.isEmpty
                        ? 'QR receiver'
                        : controller.qrReceiverName.value),
                status: controller.statusText.value,
                fileName: file?.name ?? controller.files.last.name,
                fileIndex: controller.currentFileIndex,
                fileCount: controller.files.length,
                overallProgress: controller.progress,
                fileProgress: controller.currentFileProgress,
                speedBytes: controller.transferSpeed.value,
                transferredBytes: controller.sentBytes.value,
                totalBytes: controller.totalBytes,
                estimatedTime: controller.estimatedTime,
                isComplete: controller.isComplete,
                files: controller.files
                    .map(
                      (item) => TransferProgressItem(
                        name: item.name,
                        size: item.size,
                        transferred: controller.sentBytesFor(item),
                        progress: controller.progressFor(item),
                        status: controller.statusFor(item),
                      ),
                    )
                    .toList(growable: false),
                onCancel: () async {
                  await controller.cancelTransfer();
                  Get.back();
                },
                onOpenFile: controller.openTransferredFile,
                onOpenFolder: controller.openTransferredFolder,
              );
            }
            return const _FindReceiverPage();
          }),
          Obx(
            () => controller.isPreparingFiles.value
                ? _PreparationOverlay(message: controller.preparationText.value)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PreparationOverlay extends StatelessWidget {
  const _PreparationOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.32),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please keep Next Share open.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChooseFileTypePage extends GetView<TransferSendController> {
  const _ChooseFileTypePage();

  @override
  Widget build(BuildContext context) {
    final options = <_FileTypeOption>[
      _FileTypeOption(
        icon: Icons.insert_drive_file_rounded,
        label: 'Files',
        color: const Color(0xFF3478F6),
        onTap: controller.pickFiles,
      ),
      _FileTypeOption(
        icon: Icons.photo_library_rounded,
        label: 'Photos',
        color: const Color(0xFF00A7A0),
        onTap: controller.pickPhotos,
      ),
      _FileTypeOption(
        icon: Icons.video_library_rounded,
        label: 'Videos',
        color: const Color(0xFFFF8A3D),
        onTap: controller.pickVideos,
      ),
      _FileTypeOption(
        icon: Icons.description_rounded,
        label: 'Documents',
        color: const Color(0xFF5B6FF9),
        onTap: controller.pickDocuments,
      ),
      _FileTypeOption(
        icon: Icons.folder_copy_rounded,
        label: 'Folder',
        color: const Color(0xFFFFB020),
        onTap: controller.pickFolder,
      ),
      if (Platform.isAndroid || Platform.isIOS)
        _FileTypeOption(
          icon: Icons.apps_rounded,
          label: 'Apps',
          color: const Color(0xFF22B573),
          onTap: controller.openApps,
          supported: Platform.isAndroid,
        ),
    ];
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              const TransferHeader(
                title: 'What do you want to send?',
                subtitle: 'Choose a type, then select one or more items.',
              ),
              const SizedBox(height: 28),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: options.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 600
                      ? 3
                      : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                ),
                itemBuilder: (context, index) =>
                    _FileTypeCard(option: options[index]),
              ),
              if (Platform.isMacOS) ...[
                const SizedBox(height: 20),
                Card(
                  child: InkWell(
                    onTap: controller.pickFiles,
                    borderRadius: BorderRadius.circular(18),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.file_upload_outlined),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You can also drag files into this window',
                            ),
                          ),
                          Text('Choose files'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              Obx(() {
                if (controller.statusText.value.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    controller.statusText.value,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileTypeOption {
  const _FileTypeOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.supported = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool supported;
}

class _FileTypeCard extends StatelessWidget {
  const _FileTypeCard({required this.option});

  final _FileTypeOption option;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: option.color.withValues(alpha: 0.06),
      child: InkWell(
        onTap: option.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: option.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(option.icon, color: option.color),
              ),
              const SizedBox(height: 10),
              Text(
                option.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!option.supported)
                Text(
                  'Not available on iOS',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FindReceiverPage extends GetView<TransferSendController> {
  const _FindReceiverPage();

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                TransferHeader(
                  title: 'Find a receiver',
                  subtitle:
                      '${controller.localDeviceName} • Keep both devices on the same Wi-Fi.',
                  trailing: IconButton.filledTonal(
                    onPressed: controller.serverUrl.value.isEmpty
                        ? null
                        : () => _showQrSheet(context),
                    tooltip: 'Show QR code',
                    icon: const Icon(Icons.qr_code_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                RadarView(
                  active:
                      controller.isDiscovering.value ||
                      controller.connectionStatus.value == 'searching',
                ),
                Text(
                  controller.connectionStatus.value == 'connecting'
                      ? 'Waiting for receiver to accept…'
                      : 'Finding nearby receivers…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '${controller.files.length} file(s) • ${formatBytes(controller.totalBytes)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                const _SelectedFilesCard(),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Nearby receivers',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              onPressed: controller.isDiscovering.value
                                  ? null
                                  : controller.discoverDevices,
                              tooltip: 'Search again',
                              icon: controller.isDiscovering.value
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        if (controller.nearbyDevices.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              controller.isDiscovering.value
                                  ? 'Scanning…'
                                  : 'No receiver found yet. Open Receive on the other device.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        else
                          for (final device in controller.nearbyDevices)
                            _ReceiverTile(device: device),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  controller.statusText.value,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: controller.connectionStatus.value == 'declined'
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: controller.pickMore,
                  icon: const Icon(Icons.add_rounded),
                  label: Text('Add more ${controller.selectedCategory.value}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showQrSheet(BuildContext context) async {
    final link = controller.serverUrl.value;
    QrTransferService.logGenerated(link);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Receive with QR',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: Navigator.of(context).pop,
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                'Scan this code on the receiving device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: link,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              SelectableText(
                controller.transferCode.value,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    await QrTransferService.copyLink(link);
                    Get.snackbar('Link copied', 'Paste it on the receiver.');
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy Link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedFilesCard extends GetView<TransferSendController> {
  const _SelectedFilesCard();

  @override
  Widget build(BuildContext context) {
    final visibleFiles = controller.files.take(4).toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Selected ${controller.selectedCategory.value}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${controller.files.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final file in visibleFiles)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _fileColor(file.type).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _fileIcon(file.type),
                    color: _fileColor(file.type),
                  ),
                ),
                title: Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(formatBytes(file.size)),
              ),
            if (controller.files.length > visibleFiles.length)
              Text(
                '+ ${controller.files.length - visibleFiles.length} more',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceiverTile extends GetView<TransferSendController> {
  const _ReceiverTile({required this.device});

  final NearbyDevice device;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedDevice.value?.id == device.id;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: controller.connectionStatus.value == 'connecting'
          ? null
          : () => controller.chooseDevice(device),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF7C5CFC).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          _deviceIcon(device.platform),
          color: const Color(0xFF7C5CFC),
        ),
      ),
      title: Text(device.name),
      subtitle: Text(device.platform),
      trailing: selected && controller.connectionStatus.value == 'connecting'
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right_rounded),
    );
  }
}

IconData _fileIcon(String type) {
  if (const {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'heic',
    'heif',
  }.contains(type)) {
    return Icons.image_rounded;
  }
  if (const {'mp4', 'mov', 'mkv', 'avi', 'webm', '3gp'}.contains(type)) {
    return Icons.video_file_rounded;
  }
  if (type == 'apk') return Icons.android_rounded;
  return Icons.insert_drive_file_rounded;
}

Color _fileColor(String type) {
  if (const {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'heic',
    'heif',
  }.contains(type)) {
    return const Color(0xFF00A7A0);
  }
  if (const {'mp4', 'mov', 'mkv', 'avi', 'webm', '3gp'}.contains(type)) {
    return const Color(0xFFFF8A3D);
  }
  if (type == 'apk') return const Color(0xFF22B573);
  return const Color(0xFF5B6FF9);
}

IconData _deviceIcon(String platform) {
  if (platform == 'android') return Icons.android_rounded;
  if (platform == 'ios') return Icons.phone_iphone_rounded;
  return Icons.computer_rounded;
}
