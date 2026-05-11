import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/service/download_service.dart';

class ReceiveFileItem {
  final String id;
  final String name;
  final int size;
  final RxInt received = 0.obs;

  ReceiveFileItem({
    required this.id,
    required this.name,
    required this.size,
  });
}

class TransferReceiveController extends GetxController {
  TransferReceiveController()
    : supportsScanner = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  final bool supportsScanner;
  final manualCodeController = TextEditingController();

  final statusText = ''.obs;
  final isScanning = false.obs;
  final isDownloading = false.obs;

  final files = <ReceiveFileItem>[].obs;
  final overallProgress = 0.0.obs;

  int _totalBytes = 0;
  int _totalReceived = 0;
  HttpClient? _client;

  @override
  void onInit() {
    super.onInit();
    resetReceiveFlow(clearCode: false);
  }

  Future<void> startFromQr(String data) async {
    if (isDownloading.value) return;

    final uri = _parseTransferInput(data);
    if (uri == null) {
      statusText.value = 'Invalid transfer code';
      return;
    }

    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      statusText.value = 'Missing token';
      return;
    }

    final metaUri = uri.path == '/meta' ? uri : uri.replace(path: '/meta');
    isScanning.value = false;
    isDownloading.value = true;
    statusText.value = 'Preparing transfer...';

    try {
      final meta = await _fetchMeta(metaUri);
      final list = (meta['files'] as List)
          .map(
            (e) => ReceiveFileItem(
              id: e['id'] as String,
              name: e['name'] as String,
              size: (e['size'] as num).toInt(),
            ),
          )
          .toList();

      files.assignAll(list);
      _totalBytes = list.fold(0, (sum, f) => sum + f.size);
      _totalReceived = 0;

      statusText.value = 'Downloading...';
      for (final f in list) {
        await _downloadFile(uri, token, f);
      }

      statusText.value = 'All files saved to Downloads';
    } catch (e) {
      statusText.value = 'Transfer failed: ${_userErrorMessage(e)}';
      if (files.isEmpty) {
        isScanning.value = supportsScanner;
      }
    } finally {
      isDownloading.value = false;
    }
  }

  Future<void> startFromManualCode() async {
    final code = manualCodeController.text.trim();
    if (code.isEmpty) {
      statusText.value = supportsScanner
          ? 'Scan QR or paste a transfer code'
          : 'Paste a transfer code from the sender';
      return;
    }
    await startFromQr(code);
  }

  void resetReceiveFlow({bool clearCode = true}) {
    if (clearCode) {
      manualCodeController.clear();
    }
    files.clear();
    overallProgress.value = 0;
    _totalBytes = 0;
    _totalReceived = 0;
    isDownloading.value = false;
    isScanning.value = supportsScanner;
    statusText.value = supportsScanner
        ? 'Scan QR or paste a transfer code'
        : 'Paste the transfer code from the sender';
  }

  Future<Map<String, dynamic>> _fetchMeta(Uri uri) async {
    _client ??= HttpClient();
    final req = await _client!.getUrl(uri);
    final res = await req.close();
    if (res.statusCode != 200) {
      throw StateError('Meta request failed');
    }
    final body = await utf8.decoder.bind(res).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Uri? _parseTransferInput(String raw) {
    final value = raw.trim();
    final uri = Uri.tryParse(value);
    if (uri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        uri.queryParameters['token']?.isNotEmpty == true) {
      return uri;
    }

    final parts = value.split('#');
    if (parts.length != 2) return null;
    final hostParts = parts.first.split(':');
    if (hostParts.length != 2) return null;

    final host = hostParts.first.trim();
    final port = int.tryParse(hostParts[1].trim());
    final token = parts[1].trim();
    if (host.isEmpty || port == null || token.isEmpty) {
      return null;
    }

    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: '/meta',
      queryParameters: {'token': token},
    );
  }

  String _userErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('Failed to save to Downloads')) {
      return 'cannot save to Downloads on this device';
    }
    if (text.contains('Meta request failed')) {
      return 'sender is unreachable';
    }
    if (text.contains('File download failed')) {
      return 'file download did not complete';
    }
    return 'check the code, Wi-Fi, and file permissions';
  }

  Future<void> _downloadFile(
    Uri baseUri,
    String token,
    ReceiveFileItem item,
  ) async {
    final fileUri = baseUri.replace(
      path: '/file/${item.id}',
      queryParameters: {'token': token},
    );
    _client ??= HttpClient();

    final tempDir = await getTemporaryDirectory();
    await tempDir.create(recursive: true);
    final safeName = _sanitizeName(item.name);
    final tempFile = File(p.join(tempDir.path, 'rx_$safeName'));
    await tempFile.parent.create(recursive: true);
    if (!await tempFile.exists()) {
      await tempFile.create(recursive: true);
    }
    final sink = tempFile.openWrite();

    final req = await _client!.getUrl(fileUri);
    final res = await req.close();
    if (res.statusCode != 200) {
      await sink.close();
      throw StateError('File download failed');
    }

    await for (final chunk in res) {
      sink.add(chunk);
      item.received.value += chunk.length;
      _totalReceived += chunk.length;
      if (_totalBytes > 0) {
        overallProgress.value = _totalReceived / _totalBytes;
      }
    }
    await sink.flush();
    await sink.close();

    final savedPath = await _saveToDownloads(tempFile.path, safeName);
    if (savedPath == null) {
      throw StateError('Failed to save to Downloads');
    }
    try {
      await tempFile.delete();
    } catch (_) {}
  }

  Future<Directory?> _getDownloadDirectory() async {
    if (!Platform.isAndroid) return null;
    Directory target = Directory('/storage/emulated/0/Download');
    if (!await target.exists()) {
      final fallback = await getExternalStorageDirectory();
      if (fallback == null) return null;
      target = Directory(p.join(fallback.path, 'Download'));
    }
    await target.create(recursive: true);
    return target;
  }

  String _sanitizeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return cleaned.isEmpty ? 'file.bin' : cleaned;
  }

  Future<String> _dedupeFileName(Directory dir, String name) async {
    final base = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    var candidate = name;
    var index = 1;
    while (await File(p.join(dir.path, candidate)).exists()) {
      candidate = '${base}_$index$ext';
      index++;
    }
    return candidate;
  }

  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final sdk = await DownloadService.getSdkInt();
    if (sdk >= 29) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  Future<String?> _saveToDownloads(String tempPath, String name) async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      final targetDir = await getDownloadsDirectory();
      if (targetDir == null) return null;
      await targetDir.create(recursive: true);
      final safeName = await _dedupeFileName(targetDir, name);
      final outFile = File(p.join(targetDir.path, safeName));
      await outFile.writeAsBytes(await File(tempPath).readAsBytes(), flush: true);
      return outFile.path;
    }
    if (!Platform.isAndroid) {
      final fallbackDir = await getApplicationDocumentsDirectory();
      await fallbackDir.create(recursive: true);
      final safeName = await _dedupeFileName(fallbackDir, name);
      final outFile = File(p.join(fallbackDir.path, safeName));
      await outFile.writeAsBytes(await File(tempPath).readAsBytes(), flush: true);
      return outFile.path;
    }
    final sdk = await DownloadService.getSdkInt();
    if (sdk >= 29) {
      return DownloadService.saveToDownloads(tempPath, name);
    }
    final permitted = await _ensureStoragePermission();
    if (!permitted) return null;
    final targetDir = await _getDownloadDirectory();
    if (targetDir == null) return null;
    final safeName = await _dedupeFileName(targetDir, name);
    final outFile = File(p.join(targetDir.path, safeName));
    await outFile.writeAsBytes(await File(tempPath).readAsBytes(), flush: true);
    return outFile.path;
  }

  @override
  void onClose() {
    manualCodeController.dispose();
    _client?.close(force: true);
    super.onClose();
  }
}
