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
          _ReceiveBackground(cs: cs),
          SafeArea(
            child: Obx(() {
              final showSetup =
                  !controller.isDownloading.value && controller.files.isEmpty;
              if (showSetup) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    _TopBar(title: 'Receive'),
                    if (controller.supportsScanner) ...[
                      const SizedBox(height: 12),
                      _ScannerCard(cs: cs),
                    ],
                    const SizedBox(height: 16),
                    _ManualCodeCard(cs: cs),
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  _TopBar(
                    title: 'Receiving',
                    action: TextButton(
                      onPressed: controller.resetReceiveFlow,
                      child: const Text('New transfer'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProgressSummary(cs: cs),
                  const SizedBox(height: 16),
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

class _ReceiveBackground extends StatelessWidget {
  const _ReceiveBackground({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surface,
            cs.tertiaryContainer.withValues(alpha: 0.45),
            cs.surface,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: Get.back,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Image.asset(
            'assets/logo.png',
            width: 22,
            height: 22,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _ScannerCard extends GetView<TransferReceiveController> {
  const _ScannerCard({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 360,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
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
                  child: CustomPaint(
                    painter: _ScannerFramePainter(color: cs.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          controller.statusText.value,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ManualCodeCard extends GetView<TransferReceiveController> {
  const _ManualCodeCard({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: cs.tertiary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.supportsScanner
                ? 'Manual transfer code'
                : 'Transfer code',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan the QR or paste the sender code here. Supported format: 192.168.x.x:port#token',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller.manualCodeController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '192.168.x.x:port#token',
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 10),
          Text(
            controller.statusText.value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: cs.tertiary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.statusText.value,

            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: controller.overallProgress.value > 0
                ? controller.overallProgress.value
                : null,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 8),
          Text(
            'Saving to Downloads',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          Obx(() {
            final progress = item.size == 0
                ? 0.0
                : item.received.value / item.size;
            return LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
            );
          }),
        ],
      ),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  _ScannerFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.62,
      height: size.width * 0.62,
    );
    final radius = Radius.circular(18);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
