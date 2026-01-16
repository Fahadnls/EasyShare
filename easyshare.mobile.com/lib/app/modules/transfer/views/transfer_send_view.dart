import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../controllers/transfer_send_controller.dart';

class TransferSendView extends GetView<TransferSendController> {
  const TransferSendView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send via QR'),
        actions: [
          IconButton(
            onPressed: controller.startServer,
            icon: const Icon(Icons.refresh),
            tooltip: 'Restart',
          ),
        ],
      ),
      body: Obx(() {
        final url = controller.serverUrl.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Files (${controller.files.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (controller.files.isEmpty)
              const Text('No files selected.')
            else
              ...controller.files.map(
                (f) => ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${f.size} bytes'),
                ),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Scan this QR on the receiver device',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (url.isEmpty)
                    Column(
                      children: [
                        const SizedBox(height: 80),
                        Text(
                          controller.statusText.value.isEmpty
                              ? 'Preparing...'
                              : controller.statusText.value,
                        ),
                        const SizedBox(height: 80),
                      ],
                    )
                  else
                    QrImageView(
                      data: url,
                      size: 240,
                      backgroundColor: Colors.white,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    url.isEmpty ? '' : url,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
