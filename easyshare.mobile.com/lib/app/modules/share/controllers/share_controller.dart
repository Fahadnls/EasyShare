import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:get/get.dart';

class ChatMessage {
  final bool me;
  final String text;
  ChatMessage({required this.me, required this.text});
}

class ShareController extends GetxController {
  BluetoothDevice get device => Get.arguments as BluetoothDevice;

  final connectionState = 'Connecting...'.obs;
  final isConnected = false.obs;

  BluetoothConnection? _conn;
  StreamSubscription<Uint8List>? _sub;

  final messages = <ChatMessage>[].obs;

  // File receive buffer
  final _rxBuffer = BytesBuilder();
  bool _receivingFile = false;
  String _fileName = '';
  int _fileSize = 0;
  int _received = 0;

  @override
  void onInit() {
    super.onInit();
    _connect();
  }

  Future<void> _connect() async {
    try {
      connectionState.value =
          'Connecting to ${device.name ?? device.address}...';
      _conn = await BluetoothConnection.toAddress(device.address);
      isConnected.value = true;
      connectionState.value = 'Connected';

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

  void _onData(Uint8List data) {
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
          final fileBytes = bytesNow.sublist(0, needed);
          _received += needed;

          // remaining bytes might contain next messages
          final remaining = bytesNow.sublist(needed);
          _rxBuffer.clear();
          _rxBuffer.add(remaining);

          _receivingFile = false;

          // For demo: we are not saving to storage to avoid extra permissions.
          // If you want save: use path_provider + write to app directory.
          messages.add(
            ChatMessage(
              me: false,
              text: '✅ File received: $_fileName (not saved, demo mode)',
            ),
          );
        } else {
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
