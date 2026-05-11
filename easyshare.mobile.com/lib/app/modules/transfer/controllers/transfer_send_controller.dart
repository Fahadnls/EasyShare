import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../../data/service/desktop_drop_service.dart';

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
  final transferCode = ''.obs;
  final statusText = ''.obs;

  final files = <SendFileItem>[].obs;

  HttpServer? _server;
  String _token = '';
  StreamSubscription<List<String>>? _dropSubscription;

  @override
  void onInit() {
    super.onInit();
    _readArgs();
    _listenForDesktopDrops();
    if (Platform.isMacOS && files.isEmpty) {
      statusText.value = 'Drag files here or choose files to start sharing';
    }
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

  void _listenForDesktopDrops() {
    if (!Platform.isMacOS) return;
    _dropSubscription = DesktopDropService.fileDrops().listen((paths) {
      if (paths.isEmpty) return;
      addFilesFromPaths(paths);
    });
  }

  Future<void> pickFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
      );
      if (res == null || res.files.isEmpty) return;
      final validFiles = res.files.where((file) => file.path != null).toList();
      if (validFiles.isEmpty) {
        statusText.value = 'Selected files are not accessible';
        return;
      }
      _loadFiles(validFiles);
      await startServer();
    } catch (_) {
      statusText.value = 'Failed to pick files';
    }
  }

  Future<void> addFilesFromPaths(List<String> paths) async {
    final loaded = <SendFileItem>[];
    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      final file = File(path);
      if (!await file.exists()) continue;
      final stat = await file.stat();
      loaded.add(
        SendFileItem(
          id: '$i',
          name: path.split(Platform.pathSeparator).last,
          path: path,
          size: stat.size,
        ),
      );
    }
    if (loaded.isEmpty) {
      statusText.value = 'Dropped files are not accessible';
      return;
    }
    files.assignAll(loaded);
    statusText.value = 'Files added';
    await startServer();
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
      transferCode.value = '$ip:${_server!.port}#$_token';
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
      if (ip != null && ip.isNotEmpty) {
        return ip;
      }
    } catch (_) {}

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          if (addr.address.startsWith('169.254.')) continue;
          return addr.address;
        }
      }
    } catch (_) {}

    return null;
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
    transferCode.value = '';
    statusText.value = '';
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }

  @override
  void onClose() {
    _dropSubscription?.cancel();
    stopServer();
    super.onClose();
  }
}
