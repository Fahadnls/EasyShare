import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../controllers/transfer_receive_controller.dart';

class TransferReceiveView extends GetView<TransferReceiveController> {
  const TransferReceiveView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const _BackgroundField(),
          SafeArea(
            child: Obx(() {
              final showSetup =
                  !controller.isDownloading.value && controller.files.isEmpty;

              if (showSetup) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    _ScreenHeader(
                      title: 'Receive files',
                      subtitle:
                          'Keep this screen open while the sender connects.',
                    ),
                    const SizedBox(height: 20),
                    const _NearbyVisibilityPanel(),
                    const SizedBox(height: 18),
                    if (controller.showScanner.value) ...[
                      _ScannerPanel(cs: cs),
                      const SizedBox(height: 18),
                    ] else if (controller.supportsScanner) ...[
                      const _QrScanButton(),
                      const SizedBox(height: 18),
                    ],
                    _ManualCodePanel(cs: cs),
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  _ScreenHeader(
                    title: 'Receiving',
                    subtitle: 'Progress stays here until all files are saved.',
                    action: TextButton(
                      onPressed: controller.resetReceiveFlow,
                      child: const Text('New transfer'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ProgressSummary(cs: cs),
                  const SizedBox(height: 18),
                  ...controller.files.map(
                    (f) => _FileProgressCard(cs: cs, item: f),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _NearbyVisibilityPanel extends GetView<TransferReceiveController> {
  const _NearbyVisibilityPanel();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_tethering_rounded,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nearby devices',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${Platform.localHostname} is ready to receive',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Obx(
                  () => IconButton(
                    onPressed: controller.isSearchingNearby.value
                        ? null
                        : controller.discoverNearbySenders,
                    icon: controller.isSearchingNearby.value
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    tooltip: 'Search again',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Obx(() {
              if (controller.nearbySenders.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    controller.isSearchingNearby.value
                        ? 'Searching for nearby senders...'
                        : 'No sender found yet. Start Send on the other device or scan its QR code.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }
              return Column(
                children: [
                  for (final sender in controller.nearbySenders)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Icon(_platformIcon(sender.platform)),
                      ),
                      title: Text(sender.name),
                      subtitle: Text('${sender.platform} • Ready to send'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => controller.receiveFromNearby(sender),
                    ),
                ],
              );
            }),
            const SizedBox(height: 8),
            Obx(
              () => Text(
                controller.statusText.value,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _platformIcon(String platform) {
  if (platform == 'android') return Icons.android_rounded;
  if (platform == 'ios') return Icons.phone_iphone_rounded;
  return Icons.computer_rounded;
}

class _QrScanButton extends GetView<TransferReceiveController> {
  const _QrScanButton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect with QR code',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Use this when the sender does not appear automatically.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: controller.openQrScanner,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan QR code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundField extends StatelessWidget {
  const _BackgroundField();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            cs.primaryContainer.withValues(alpha: 0.35),
            cs.tertiaryContainer.withValues(alpha: 0.5),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 64,
            left: -16,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

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
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    );
  }
}

class _ScannerPanel extends GetView<TransferReceiveController> {
  const _ScannerPanel({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Scan the sender QR', style: textTheme.titleLarge),
              ),
              IconButton(
                onPressed: controller.closeQrScanner,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close scanner',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Point the camera at the code shown on the sending device.',
            style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 340,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Stack(
                children: [
                  MobileScanner(
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;
                      if (barcodes.isEmpty) return;
                      final value = barcodes.first.rawValue;
                      if (value == null || value.isEmpty) return;
                      controller.startFromQr(value);
                    },
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: cs.surface.withValues(alpha: 0.18),
                          width: 20,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ScannerFramePainter(color: cs.secondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            controller.statusText.value,
            style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ManualCodePanel extends GetView<TransferReceiveController> {
  const _ManualCodePanel({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.supportsScanner
                ? 'Prefer typing it?'
                : 'Enter transfer code',
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Paste the sender code here. Expected format: 192.168.x.x:port#token',
            style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.manualCodeController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '192.168.x.x:port#token',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: controller.isDownloading.value
                  ? null
                  : controller.startFromManualCode,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Receive with code'),
            ),
          ),
          const SizedBox(height: 12),
          Text(controller.statusText.value, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ProgressSummary extends GetView<TransferReceiveController> {
  const _ProgressSummary({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.statusText.value,
            style: textTheme.titleLarge?.copyWith(color: cs.onPrimary),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: controller.overallProgress.value > 0
                  ? controller.overallProgress.value
                  : null,
              minHeight: 10,
              backgroundColor: cs.onPrimary.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(cs.secondaryContainer),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Saving to ${controller.saveLocationLabel}',
            style: textTheme.bodyMedium?.copyWith(
              color: cs.onPrimary.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Text(
                '${(controller.overallProgress.value * 100).toStringAsFixed(0)}%',
                style: textTheme.bodySmall?.copyWith(color: cs.onPrimary),
              ),
              Text(
                '${_formatBytes(controller.receivedBytes)} / ${_formatBytes(controller.totalBytes)}',
                style: textTheme.bodySmall?.copyWith(color: cs.onPrimary),
              ),
              Text(
                '${(controller.transferSpeed.value / (1024 * 1024)).toStringAsFixed(2)} MB/s',
                style: textTheme.bodySmall?.copyWith(color: cs.onPrimary),
              ),
              Text(
                controller.estimatedSeconds.value > 0
                    ? '${_formatSeconds(controller.estimatedSeconds.value)} remaining'
                    : '${_formatBytes(controller.remainingBytes)} remaining',
                style: textTheme.bodySmall?.copyWith(color: cs.onPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (controller.isDownloading.value)
                FilledButton.tonalIcon(
                  onPressed: controller.isPaused.value
                      ? controller.resumeTransfer
                      : controller.pauseTransfer,
                  icon: Icon(
                    controller.isPaused.value
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                  label: Text(controller.isPaused.value ? 'Resume' : 'Pause'),
                ),
              if (controller.isDownloading.value)
                OutlinedButton.icon(
                  onPressed: controller.cancelTransfer,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onPrimary,
                  ),
                ),
              if (controller.hasFailed.value)
                FilledButton.tonalIcon(
                  onPressed: controller.retryTransfer,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FileProgressCard extends StatelessWidget {
  const _FileProgressCard({required this.cs, required this.item});

  final ColorScheme cs;
  final ReceiveFileItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(_formatBytes(item.size), style: textTheme.bodySmall),
          const SizedBox(height: 3),
          Obx(
            () => Text(
              item.status.value,
              style: textTheme.bodySmall?.copyWith(
                color: item.status.value == 'failed' ? cs.error : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final progress = item.size == 0
                ? 0.0
                : item.received.value / item.size;
            return ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                valueColor: AlwaysStoppedAnimation<Color>(cs.secondary),
              ),
            );
          }),
        ],
      ),
    );
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

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  return '${unitIndex == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1)} ${units[unitIndex]}';
}

String _formatSeconds(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';
}

class _ScannerFramePainter extends CustomPainter {
  _ScannerFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.64,
      height: size.width * 0.64,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      framePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
