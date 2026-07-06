import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../controllers/transfer_receive_controller.dart';
import 'transfer_ui.dart';

class TransferReceiveView extends GetView<TransferReceiveController> {
  const TransferReceiveView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (controller.pendingOffer.value != null) {
          return const _IncomingRequestPage();
        }
        if (controller.files.isNotEmpty) {
          final item = controller.currentFile;
          final fileProgress = item == null || item.size == 0
              ? (controller.isComplete ? 1.0 : 0.0)
              : item.received.value / item.size;
          return TransferProgressPage(
            title: 'Receiving',
            peerLabel: 'Sender',
            peerName: controller.peerName.value,
            status: controller.statusText.value,
            fileName: item?.name ?? controller.files.last.name,
            fileIndex: controller.currentFileIndex,
            fileCount: controller.files.length,
            overallProgress: controller.overallProgress.value,
            fileProgress: fileProgress,
            speedBytes: controller.transferSpeed.value,
            transferredBytes: controller.receivedBytes,
            totalBytes: controller.totalBytes,
            estimatedTime: controller.estimatedSeconds.value > 0
                ? Duration(seconds: controller.estimatedSeconds.value)
                : null,
            isComplete: controller.isComplete,
            files: controller.files
                .map(
                  (file) => TransferProgressItem(
                    name: file.name,
                    size: file.size,
                    transferred: file.received.value,
                    progress: file.size == 0
                        ? (file.status.value == 'complete' ? 1 : 0)
                        : (file.received.value / file.size).clamp(0, 1),
                    status: _fileStatusLabel(file.status.value),
                  ),
                )
                .toList(growable: false),
            onCancel: () async {
              await controller.cancelTransfer();
              controller.resetReceiveFlow();
            },
            onRetry: controller.hasFailed.value
                ? controller.retryTransfer
                : null,
            onOpenFile: controller.openReceivedFile,
            onOpenFolder: controller.openReceivedFolder,
          );
        }
        return const _WaitingPage();
      }),
    );
  }
}

String _fileStatusLabel(String status) {
  return switch (status) {
    'receiving' => 'Receiving',
    'complete' => 'Complete',
    'retrying' => 'Retrying',
    'failed' => 'Failed',
    'cancelled' => 'Cancelled',
    _ => 'Waiting',
  };
}

class _WaitingPage extends GetView<TransferReceiveController> {
  const _WaitingPage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: TransferHeader(
                  title: 'Receive',
                  subtitle: 'Keep this screen open while waiting.',
                  trailing: IconButton.filledTonal(
                    onPressed: () => _showConnectPanel(context),
                    tooltip: 'Connect with QR or code',
                    icon: const Icon(Icons.qr_code_2_rounded),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final radarSize = (constraints.biggest.shortestSide).clamp(
                      300.0,
                      720.0,
                    );
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        RadarView(
                          dimension: radarSize,
                          color: const Color(0xFF2196F3),
                        ),
                        Obx(
                          () => Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                28,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 460,
                                ),
                                child: Card(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surface.withValues(alpha: 0.94),
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF2196F3,
                                            ).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.wifi_tethering_rounded,
                                            color: Color(0xFF2196F3),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Ready to receive',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleLarge,
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${controller.localDeviceName} • ${controller.statusText.value}',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed:
                                              controller.isSearchingNearby.value
                                              ? null
                                              : controller
                                                    .discoverNearbySenders,
                                          tooltip: 'Search again',
                                          icon:
                                              controller.isSearchingNearby.value
                                              ? const SizedBox.square(
                                                  dimension: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.refresh_rounded,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openScanner(BuildContext context) async {
    await controller.openQrScanner();
    if (!context.mounted || !controller.showScanner.value) return;

    if (MediaQuery.sizeOf(context).width >= 700) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _ScannerContent(
              onClose: () {
                controller.closeQrScanner();
                Navigator.of(dialogContext).pop();
              },
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        enableDrag: false,
        isDismissible: false,
        builder: (sheetContext) => SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: _ScannerContent(
              onClose: () {
                controller.closeQrScanner();
                Navigator.of(sheetContext).pop();
              },
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showConnectPanel(BuildContext context) async {
    Widget content(BuildContext panelContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.viewInsetsOf(panelContext).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Connect to sender',
                  style: Theme.of(panelContext).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: Navigator.of(panelContext).pop,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: controller.supportsScanner
                  ? () {
                      Navigator.of(panelContext).pop();
                      Future<void>.delayed(Duration.zero, () {
                        if (context.mounted) _openScanner(context);
                      });
                    }
                  : null,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan sender QR'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or enter a transfer code',
                  style: Theme.of(panelContext).textTheme.bodySmall,
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.manualCodeController,
            decoration: const InputDecoration(
              hintText: '192.168.x.x:port#code',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(panelContext).pop();
                controller.startFromManualCode();
              },
              child: const Text('Connect'),
            ),
          ),
        ],
      ),
    );

    if (MediaQuery.sizeOf(context).width >= 700) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: content(dialogContext),
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: content,
    );
  }
}

class _ScannerContent extends StatefulWidget {
  const _ScannerContent({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_ScannerContent> createState() => _ScannerContentState();
}

class _ScannerContentState extends State<_ScannerContent> {
  final TransferReceiveController controller =
      Get.find<TransferReceiveController>();
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.qr_code_scanner_rounded),
          title: const Text('Scan the sender QR code'),
          subtitle: const Text('Point the camera at the transfer QR code.'),
          trailing: IconButton(
            onPressed: widget.onClose,
            tooltip: 'Close scanner',
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              if (_handled) return;
              final value = capture.barcodes.firstOrNull?.rawValue;
              if (value == null || value.isEmpty) return;
              _handled = true;
              widget.onClose();
              controller.startFromQr(value, senderName: 'QR sender');
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Camera could not start',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      error.errorDetails?.message ??
                          'Check camera permission and try again.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IncomingRequestPage extends GetView<TransferReceiveController> {
  const _IncomingRequestPage();

  @override
  Widget build(BuildContext context) {
    final offer = controller.pendingOffer.value!;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22B573).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    size: 38,
                    color: Color(0xFF22B573),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${offer.senderName} wants to send files',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  '${offer.fileCount} file(s) • ${formatBytes(offer.totalBytes)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  offer.fileCount > 1
                      ? '${offer.fileName} and ${offer.fileCount - 1} more'
                      : offer.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: controller.declineOffer,
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: controller.acceptOffer,
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
