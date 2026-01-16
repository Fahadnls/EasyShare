import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  final statusText = 'Scan QR to receive'.obs;
  final isScanning = true.obs;
  final isDownloading = false.obs;

  final files = <ReceiveFileItem>[].obs;
  final overallProgress = 0.0.obs;

  int _totalBytes = 0;
  int _totalReceived = 0;
  HttpClient? _client;

  Future<void> startFromQr(String data) async {
    if (isDownloading.value) return;
    isScanning.value = false;
    isDownloading.value = true;
    statusText.value = 'Preparing transfer...';

    final uri = Uri.tryParse(data);
    if (uri == null) {
      statusText.value = 'Invalid QR data';
      isDownloading.value = false;
      return;
    }

    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      statusText.value = 'Missing token';
      isDownloading.value = false;
      return;
    }

    final metaUri = uri.path == '/meta' ? uri : uri.replace(path: '/meta');
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

      statusText.value = 'All files saved';
    } catch (e) {
      statusText.value = 'Transfer failed';
    } finally {
      isDownloading.value = false;
    }
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
    final safeName = _sanitizeName(item.name);
    final tempFile = File(p.join(tempDir.path, 'rx_$safeName'));
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
    await tempFile.delete().catchError((_) {});
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
    if (!Platform.isAndroid) return null;
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
    _client?.close(force: true);
    super.onClose();
  }
}
