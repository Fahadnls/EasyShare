import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../controllers/transfer_send_controller.dart';

class TransferSendView extends GetView<TransferSendController> {
  const TransferSendView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          _SendBackground(cs: cs),
          SafeArea(
            child: Obx(() {
              final url = controller.serverUrl.value;
              final isMacSetup = Platform.isMacOS && controller.files.isEmpty;
              if (isMacSetup) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    _TopBar(
                      title: 'Send',
                      action: IconButton(
                        onPressed: controller.pickFiles,
                        icon: const Icon(Icons.folder_open_rounded),
                        tooltip: 'Choose files',
                      ),
                    ),
                    const SizedBox(height: 20),
                    _StatusBanner(
                      cs: cs,
                      status: controller.statusText.value,
                      count: controller.files.length,
                    ),
                    const SizedBox(height: 18),
                    _MacDropZone(
                      cs: cs,
                      expanded: true,
                    ),
                  ],
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  _TopBar(
                    title: 'Send',
                    action: IconButton(
                      onPressed: controller.startServer,
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Restart',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _StatusBanner(
                    cs: cs,
                    status: controller.statusText.value,
                    count: controller.files.length,
                  ),
                  const SizedBox(height: 16),
                  if (Platform.isMacOS) ...[
                    _MacDropZone(cs: cs),
                    const SizedBox(height: 16),
                  ],
                  _QrCard(
                    cs: cs,
                    url: url,
                    statusText: controller.statusText.value,
                  ),
                  const SizedBox(height: 16),
                  _TransferCodePanel(cs: cs, url: url),
                  const SizedBox(height: 16),
                  _FileList(cs: cs),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SendBackground extends StatelessWidget {
  const _SendBackground({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.surface,
            cs.primaryContainer.withValues(alpha: 0.5),
            cs.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.action});

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: Get.back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 8),
        Image.asset(
          'assets/logo.png',
          width: 22,
          height: 22,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        action,
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.cs,
    required this.status,
    required this.count,
  });

  final ColorScheme cs;
  final String status;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code_rounded, color: cs.onPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status.isEmpty ? 'Preparing transfer...' : status,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onPrimary,
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.onPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count files',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.cs,
    required this.url,
    required this.statusText,
  });

  final ColorScheme cs;
  final String url;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final canShare = url.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            canShare
                ? 'Scan this QR on the receiver device'
                : 'Add files to start sharing',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          if (url.isEmpty)
            Container(
              width: 240,
              height: 240,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText.isEmpty ? 'Drop files or choose files to begin.' : statusText,
                textAlign: TextAlign.center,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: url,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
          const SizedBox(height: 12),
          if (url.isNotEmpty)
            Text(
              url,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
        ],
      ),
    );
  }
}

class _MacDropZone extends GetView<TransferSendController> {
  const _MacDropZone({required this.cs, this.expanded = false});

  final ColorScheme cs;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(expanded ? 28 : 18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.file_upload_outlined,
            size: expanded ? 56 : 42,
            color: cs.primary,
          ),
          SizedBox(height: expanded ? 16 : 10),
          Text(
            'Drag files here on Mac',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: expanded ? 24 : null,
            ),
          ),
          SizedBox(height: expanded ? 10 : 6),
          Text(
            'Drop one or many files into this window, or choose them manually.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: expanded ? 20 : 14),
          FilledButton.icon(
            onPressed: controller.pickFiles,
            icon: const Icon(Icons.folder_open_rounded),
            label: const Text('Choose files'),
          ),
          if (expanded) ...[
            const SizedBox(height: 14),
            Text(
              'After adding files, EasyShare will generate a QR and connection code automatically.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _TransferCodePanel extends GetView<TransferSendController> {
  const _TransferCodePanel({required this.cs, required this.url});

  final ColorScheme cs;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transfer code',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            url.isEmpty
                ? 'This code will appear when the sender is ready.'
                : 'Scan the QR or enter this code on Android or Mac.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          SelectableText(
            url.isEmpty
                ? 'Preparing transfer code...'
                : controller.transferCode.value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
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
  const _FileList({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected files',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          if (controller.files.isEmpty)
            Text(
              'No files selected.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            )
          else
            ...controller.files.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.insert_drive_file_outlined,
                        size: 18,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${f.size} bytes',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
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
}
