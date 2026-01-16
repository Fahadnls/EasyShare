import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';

class SendFileItem {
  final String id;
  final String name;
  final String path;
  final int size;

  SendFileItem({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
  });
}

class TransferSendController extends GetxController {
  final isServing = false.obs;
  final serverUrl = ''.obs;
  final statusText = ''.obs;

  final files = <SendFileItem>[].obs;

  HttpServer? _server;
  String _token = '';

  @override
  void onInit() {
    super.onInit();
    _readArgs();
    if (files.isNotEmpty) {
      startServer();
    }
  }

  void _readArgs() {
    final args = Get.arguments;
    if (args is Map) {
      final argFiles = args['files'];
      if (argFiles is List<PlatformFile>) {
        _loadFiles(argFiles);
      }
    }
  }

  void _loadFiles(List<PlatformFile> picked) {
    final loaded = <SendFileItem>[];
    for (var i = 0; i < picked.length; i++) {
      final f = picked[i];
      final path = f.path;
      if (path == null) continue;
      loaded.add(
        SendFileItem(
          id: '$i',
          name: f.name,
          path: path,
          size: f.size,
        ),
      );
    }
    files.assignAll(loaded);
  }

  Future<void> startServer() async {
    if (files.isEmpty) {
      statusText.value = 'No files selected';
      return;
    }
    await stopServer();
    statusText.value = 'Starting server...';

    try {
      _token = _randomToken();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _server!.listen(_handleRequest);

      final ip = await _getWifiIp();
      if (ip == null) {
        statusText.value = 'Wi-Fi IP not found. Connect to Wi-Fi.';
        await stopServer();
        return;
      }

      serverUrl.value = 'http://$ip:${_server!.port}/meta?token=$_token';
      isServing.value = true;
      statusText.value = 'Ready to share';
    } catch (e) {
      statusText.value = 'Failed to start server';
      await stopServer();
    }
  }

  Future<String?> _getWifiIp() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      if (ip == null || ip.isEmpty) return null;
      return ip;
    } catch (_) {
      return null;
    }
  }

  String _randomToken() {
    final rand = Random();
    final part = rand.nextInt(1 << 32).toRadixString(16);
    return '${DateTime.now().millisecondsSinceEpoch}-$part';
  }

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      final token = req.uri.queryParameters['token'];
      if (token != _token) {
        req.response.statusCode = HttpStatus.forbidden;
        await req.response.close();
        return;
      }

      if (req.uri.path == '/meta') {
        req.response.headers.contentType = ContentType.json;
        final meta = {
          'files': files
              .map(
                (f) => {
                  'id': f.id,
                  'name': f.name,
                  'size': f.size,
                },
              )
              .toList(),
        };
        req.response.write(jsonEncode(meta));
        await req.response.close();
        return;
      }

      if (req.uri.pathSegments.length == 2 &&
          req.uri.pathSegments.first == 'file') {
        final id = req.uri.pathSegments[1];
        SendFileItem? file;
        for (final f in files) {
          if (f.id == id) {
            file = f;
            break;
          }
        }
        if (file == null) {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
          return;
        }

        final f = File(file.path);
        if (!await f.exists()) {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
          return;
        }

        req.response.headers.contentType =
            ContentType('application', 'octet-stream');
        req.response.headers.contentLength = file.size;
        await f.openRead().pipe(req.response);
        return;
      }

      req.response.statusCode = HttpStatus.notFound;
      await req.response.close();
    } catch (_) {
      try {
        req.response.statusCode = HttpStatus.internalServerError;
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> stopServer() async {
    isServing.value = false;
    serverUrl.value = '';
    statusText.value = '';
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }

  @override
  void onClose() {
    stopServer();
    super.onClose();
  }
}
