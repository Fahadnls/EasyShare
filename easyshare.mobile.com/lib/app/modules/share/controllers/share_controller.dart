import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/service/download_service.dart';

class ChatMessage {
  final bool me;
  final String text;
  ChatMessage({required this.me, required this.text});
}

class PendingFile {
  final String name;
  final Uint8List bytes;
  const PendingFile({required this.name, required this.bytes});
}

class ShareController extends GetxController {
  late final BluetoothDevice device;
  PendingFile? _pendingFile;

  final connectionState = 'Connecting...'.obs;
  final isConnected = false.obs;

  BluetoothConnection? _conn;
  StreamSubscription<Uint8List>? _sub;

  final messages = <ChatMessage>[].obs;

  // File receive buffer
  final _rxBuffer = BytesBuilder();
  BytesBuilder _fileBuffer = BytesBuilder();
  bool _receivingFile = false;
  String _fileName = '';
  int _fileSize = 0;
  int _received = 0;

  @override
  void onInit() {
    super.onInit();
    _readArguments();
    _connect();
  }

  void _readArguments() {
    final args = Get.arguments;
    if (args is BluetoothDevice) {
      device = args;
      return;
    }
    if (args is Map) {
      final argDevice = args['device'];
      if (argDevice is BluetoothDevice) {
        device = argDevice;
      }
      final fileName = args['fileName'];
      final fileBytes = args['fileBytes'];
      if (fileName is String && fileBytes is List<int>) {
        _pendingFile = PendingFile(
          name: fileName,
          bytes: Uint8List.fromList(fileBytes),
        );
      }
      if (argDevice is BluetoothDevice) {
        return;
      }
    }
    throw StateError('Missing Bluetooth device argument');
  }

  Future<void> _connect() async {
    try {
      connectionState.value =
          'Connecting to ${device.name ?? device.address}...';
      _conn = await BluetoothConnection.toAddress(device.address);
      isConnected.value = true;
      connectionState.value = 'Connected';

      if (_pendingFile != null) {
        await _sendPendingFile();
      }

      _sub = _conn!.input!.listen(
        _onData,
        onDone: () {
          isConnected.value = false;
          connectionState.value = 'Disconnected';
        },
        onError: (_) {
          isConnected.value = false;
          connectionState.value = 'Disconnected';
        },
      );
    } catch (e) {
      isConnected.value = false;
      connectionState.value = 'Failed to connect';
      Get.snackbar('Connection', 'Could not connect to device');
    }
  }

  Future<void> _onData(Uint8List data) async {
    // Simple protocol:
    // Text line messages end with \n
    // File header: "FILE:<name>:<size>\n" then raw bytes of <size>
    _rxBuffer.add(data);

    while (true) {
      final bytes = _rxBuffer.toBytes();

      if (!_receivingFile) {
        // look for newline for header/text
        final nl = bytes.indexOf(10); // \n
        if (nl == -1) return;

        final lineBytes = bytes.sublist(0, nl);
        final line = utf8.decode(lineBytes, allowMalformed: true).trim();

        // remove processed from buffer
        final remaining = bytes.sublist(nl + 1);
        _rxBuffer.clear();
        _rxBuffer.add(remaining);

        if (line.startsWith('FILE:')) {
          final parts = line.split(':');
          if (parts.length >= 3) {
            _fileName = parts[1];
            _fileSize = int.tryParse(parts[2]) ?? 0;
            _received = 0;
            _receivingFile = true;
            _fileBuffer = BytesBuilder();
            messages.add(
              ChatMessage(
                me: false,
                text: '📥 Receiving file: $_fileName ($_fileSize bytes)',
              ),
            );
          } else {
            messages.add(ChatMessage(me: false, text: line));
          }
        } else {
          messages.add(ChatMessage(me: false, text: line));
        }
      } else {
        // receiving raw bytes
        final bytesNow = _rxBuffer.toBytes();
        if (bytesNow.isEmpty) return;

        final needed = _fileSize - _received;
        if (bytesNow.length >= needed) {
          // got full file
          _fileBuffer.add(bytesNow.sublist(0, needed));
          _received += needed;

          // remaining bytes might contain next messages
          final remaining = bytesNow.sublist(needed);
          _rxBuffer.clear();
          _rxBuffer.add(remaining);

          _receivingFile = false;

          final fileBytes = _fileBuffer.toBytes();
          _fileBuffer = BytesBuilder();

          final savedPath = await _saveReceivedFile(fileBytes, _fileName);
          final savedText = savedPath == null
              ? '❗ Could not save file. Check storage permission.'
              : '✅ File saved to: $savedPath';
          messages.add(
            ChatMessage(
              me: false,
              text: '✅ File received: $_fileName\n$savedText',
            ),
          );
        } else {
          _fileBuffer.add(bytesNow);
          _received += bytesNow.length;
          _rxBuffer.clear();
          messages.add(
            ChatMessage(
              me: false,
              text: '... receiving $_fileName ($_received/$_fileSize)',
            ),
          );
          return;
        }
      }
    }
  }

  Future<String?> _saveReceivedFile(Uint8List bytes, String name) async {
    if (!Platform.isAndroid) return null;
    final tempDir = await getTemporaryDirectory();
    final safeName = _sanitizeName(name);
    final tempFile = File(p.join(tempDir.path, 'bt_$safeName'));
    await tempFile.writeAsBytes(bytes, flush: true);

    final savedPath = await _saveToDownloads(tempFile.path, safeName);
    await tempFile.delete().catchError((_) {});
    return savedPath;
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

  String _sanitizeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return cleaned.isEmpty ? 'file.bin' : cleaned;
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
    Directory target = Directory('/storage/emulated/0/Download');
    if (!await target.exists()) {
      final fallback = await getExternalStorageDirectory();
      if (fallback == null) return null;
      target = Directory(p.join(fallback.path, 'Download'));
    }
    await target.create(recursive: true);
    final safeName = await _dedupeFileName(target, name);
    final file = File(p.join(target.path, safeName));
    await file.writeAsBytes(await File(tempPath).readAsBytes(), flush: true);
    return file.path;
  }

  Future<void> sendText(String text) async {
    if (!isConnected.value || _conn == null) return;
    final msg = text.trim();
    if (msg.isEmpty) return;

    try {
      final data = utf8.encode('$msg\n');
      _conn!.output.add(Uint8List.fromList(data));
      await _conn!.output.allSent;
      messages.add(ChatMessage(me: true, text: msg));
    } catch (_) {
      Get.snackbar('Send', 'Failed to send');
    }
  }

  Future<void> pickAndSendFile() async {
    if (!isConnected.value || _conn == null) return;

    final res = await FilePicker.platform.pickFiles(withData: true);
    if (res == null || res.files.isEmpty) return;

    final file = res.files.first;
    final name = file.name;
    final bytes = file.bytes;
    if (bytes == null) {
      Get.snackbar('File', 'Could not read file bytes');
      return;
    }

    try {
      final header = utf8.encode('FILE:$name:${bytes.length}\n');
      _conn!.output.add(Uint8List.fromList(header));
      _conn!.output.add(Uint8List.fromList(bytes));
      await _conn!.output.allSent;

      messages.add(
        ChatMessage(
          me: true,
          text: '📤 Sent file: $name (${bytes.length} bytes)',
        ),
      );
    } catch (_) {
      Get.snackbar('File', 'Failed to send file');
    }
  }

  Future<void> _sendPendingFile() async {
    if (_pendingFile == null) return;
    if (!isConnected.value || _conn == null) return;

    final file = _pendingFile!;
    _pendingFile = null;
    try {
      final header = utf8.encode('FILE:${file.name}:${file.bytes.length}\n');
      _conn!.output.add(Uint8List.fromList(header));
      _conn!.output.add(Uint8List.fromList(file.bytes));
      await _conn!.output.allSent;

      messages.add(
        ChatMessage(
          me: true,
          text: '📤 Sent file: ${file.name} (${file.bytes.length} bytes)',
        ),
      );
    } catch (_) {
      Get.snackbar('File', 'Failed to send file');
    }
  }

  Future<void> disconnect() async {
    try {
      await _sub?.cancel();
      _sub = null;
      await _conn?.close();
    } catch (_) {}
    _conn = null;
    isConnected.value = false;
    connectionState.value = 'Disconnected';
  }

  @override
  void onClose() {
    disconnect();
    super.onClose();
  }
}
