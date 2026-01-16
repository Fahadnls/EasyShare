import 'dart:io';

import 'package:flutter/services.dart';

class DownloadService {
  static const MethodChannel _channel = MethodChannel('easyshare/downloads');

  static Future<int> getSdkInt() async {
    if (!Platform.isAndroid) return 0;
    final sdk = await _channel.invokeMethod<int>('getSdkInt');
    return sdk ?? 0;
  }

  static Future<String?> saveToDownloads(
    String sourcePath,
    String fileName,
  ) async {
    if (!Platform.isAndroid) return null;
    final res = await _channel.invokeMethod<String>(
      'saveToDownloads',
      {
        'path': sourcePath,
        'name': fileName,
      },
    );
    return res;
  }
}
