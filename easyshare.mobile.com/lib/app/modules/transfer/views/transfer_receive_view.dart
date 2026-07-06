import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/ui_constants.dart';
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
                    path: file.savedPath,
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => _showManualCodePanel(context),
                        tooltip: 'Enter transfer code',
                        icon: const Icon(Icons.link_rounded),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: controller.supportsScanner
                            ? () => _openScanner(context)
                            : null,
                        tooltip: 'Scan sender QR',
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                      ),
                    ],
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
                                              kBorderRadius,
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

  Future<void> _showManualCodePanel(BuildContext context) async {
    String? validationError;

    Widget content(BuildContext panelContext) => StatefulBuilder(
      builder: (panelContext, setState) => Padding(
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
                    'Enter transfer code',
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
            Text(
              'Paste the code or link shared by the sender.',
              style: Theme.of(panelContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller.manualCodeController,
              onChanged: (_) {
                if (validationError == null) return;
                setState(() => validationError = null);
              },
              decoration: InputDecoration(
                hintText: '192.168.x.x:port#code',
                errorText: validationError,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final code = controller.manualCodeController.text.trim();
                  if (code.isEmpty) {
                    setState(
                      () =>
                          validationError = 'Enter the transfer code or link.',
                    );
                    return;
                  }
                  Navigator.of(panelContext).pop();
                  await controller.startFromManualCode();
                },
                child: const Text('Connect'),
              ),
            ),
          ],
        ),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scanSize = constraints.maxWidth < 420
                  ? constraints.maxWidth * 0.7
                  : 280.0;
              return Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
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
                  IgnorePointer(
                    child: Center(child: _ScannerOverlay(scanSize: scanSize)),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.scanSize});

  final double scanSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: scanSize,
      height: scanSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kBorderRadius + 12),
        border: Border.all(
          color: colors.surface.withValues(alpha: 0.88),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.scrim.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Stack(
        children: [
          _ScannerCorner(alignment: Alignment.topLeft, color: colors.primary),
          _ScannerCorner(alignment: Alignment.topRight, color: colors.primary),
          _ScannerCorner(
            alignment: Alignment.bottomLeft,
            color: colors.primary,
          ),
          _ScannerCorner(
            alignment: Alignment.bottomRight,
            color: colors.primary,
          ),
        ],
      ),
    );
  }
}

class _ScannerCorner extends StatelessWidget {
  const _ScannerCorner({required this.alignment, required this.color});

  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;
    return Align(
      alignment: alignment,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isTop && isLeft ? kBorderRadius : 0),
            topRight: Radius.circular(isTop && !isLeft ? kBorderRadius : 0),
            bottomLeft: Radius.circular(!isTop && isLeft ? kBorderRadius : 0),
            bottomRight: Radius.circular(!isTop && !isLeft ? kBorderRadius : 0),
          ),
          border: Border(
            top: isTop ? BorderSide(color: color, width: 4) : BorderSide.none,
            bottom: !isTop
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
            left: isLeft ? BorderSide(color: color, width: 4) : BorderSide.none,
            right: !isLeft
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
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
                    borderRadius: BorderRadius.circular(kBorderRadius + 8),
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
