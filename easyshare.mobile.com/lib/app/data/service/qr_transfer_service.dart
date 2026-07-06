import 'dart:developer' as developer;

import 'package:flutter/services.dart';

class QrTransferService {
  static bool isValidPayload(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        uri.queryParameters['token']?.isNotEmpty == true;
  }

  static void logGenerated(String value) {
    if (!isValidPayload(value)) return;
    developer.log('QR generated', name: 'nextshare.transfer');
  }

  static Future<void> copyLink(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    developer.log('Transfer link copied', name: 'nextshare.transfer');
  }
}
