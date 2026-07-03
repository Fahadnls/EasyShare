import 'dart:io';

import 'package:flutter/services.dart';

class DownloadService {
  static const MethodChannel _channel = MethodChannel('nextshare/downloads');

  static Future<int> getSdkInt() async {
    if (!Platform.isAndroid) return 0;
    final sdk = await _channel.invokeMethod<int>('getSdkInt');
    return sdk ?? 0;
  }

  static Future<int?> getAvailableBytes() async {
    if (!Platform.isAndroid) return null;
    return _channel.invokeMethod<int>('getAvailableBytes');
  }

  static Future<String?> saveToDownloads(
    String sourcePath,
    String fileName, {
    String? relativeDirectory,
  }) async {
    if (!Platform.isAndroid) return null;
    final res = await _channel.invokeMethod<String>('saveToDownloads', {
      'path': sourcePath,
      'name': fileName,
      'relativeDirectory': relativeDirectory,
    });
    return res;
  }
}
