import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../controllers/transfer_receive_controller.dart';

class TransferReceiveView extends GetView<TransferReceiveController> {
  const TransferReceiveView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive via QR'),
      ),
      body: Obx(() {
        if (controller.isScanning.value) {
          return Column(
            children: [
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final value = barcodes.first.rawValue;
                    if (value == null || value.isEmpty) return;
                    controller.startFromQr(value);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(controller.statusText.value),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              controller.statusText.value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: controller.overallProgress.value > 0
                  ? controller.overallProgress.value
                  : null,
            ),
            const SizedBox(height: 16),
            ...controller.files.map(
              (f) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Obx(() {
                    final progress = f.size == 0
                        ? 0.0
                        : f.received.value / f.size;
                    return LinearProgressIndicator(value: progress);
                  }),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
