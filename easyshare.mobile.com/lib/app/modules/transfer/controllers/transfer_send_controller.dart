import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;

import '../../../data/model/transfer_history_item.dart';
import '../../../data/service/app_storage_service.dart';
import '../../../data/service/desktop_drop_service.dart';
import '../../../data/service/device_discovery_service.dart';
import '../../../data/service/platform_file_service.dart';
import '../../../routes/app_pages.dart';

class SendFileItem {
  const SendFileItem({
    required this.id,
    required this.name,
    required this.path,
    required this.relativePath,
    required this.size,
  });

  final String id;
  final String name;
  final String path;
  final String relativePath;
  final int size;

  String get type {
    final extension = p.extension(name).replaceFirst('.', '').toLowerCase();
    return extension.isEmpty ? 'file' : extension;
  }
}

class TransferSendController extends GetxController {
  final isServing = false.obs;
  final isDiscovering = false.obs;
  final serverUrl = ''.obs;
  final transferCode = ''.obs;
  final statusText = ''.obs;
  final connectionStatus = 'searching'.obs;
  final hasTransferStarted = false.obs;
  final sentBytes = 0.obs;
  final transferSpeed = 0.0.obs;

  final files = <SendFileItem>[].obs;
  final nearbyDevices = <NearbyDevice>[].obs;
  final selectedDevice = Rxn<NearbyDevice>();

  final DeviceDiscoveryService _discovery = DeviceDiscoveryService();
  final AppStorageService _storage = Get.find<AppStorageService>();
  final Set<String> _completedIds = {};

  HttpServer? _server;
  String _token = '';
  StreamSubscription<List<String>>? _dropSubscription;
  Timer? _speedTimer;
  int _lastSentBytes = 0;
  String? _initialAction;

  int get totalBytes => files.fold(0, (sum, file) => sum + file.size);
  int get remainingBytes => max(0, totalBytes - sentBytes.value);
  double get progress =>
      totalBytes == 0 ? 0 : (sentBytes.value / totalBytes).clamp(0, 1);
  Duration? get estimatedTime {
    if (transferSpeed.value <= 0 || remainingBytes == 0) return null;
    return Duration(seconds: (remainingBytes / transferSpeed.value).ceil());
  }

  @override
  void onInit() {
    super.onInit();
    _readArgs();
    _listenForDesktopDrops();
    if (files.isEmpty) {
      statusText.value = Platform.isMacOS
          ? 'Drag files here or choose files to start sharing'
          : 'Choose files, a folder, or apps to start sharing';
    } else {
      unawaited(startServer());
    }
  }

  @override
  void onReady() {
    super.onReady();
    final action = _initialAction;
    _initialAction = null;
    if (action == null) return;
    switch (action) {
      case 'photos':
        unawaited(pickPhotos());
        return;
      case 'videos':
        unawaited(pickVideos());
        return;
      case 'documents':
        unawaited(pickDocuments());
        return;
      case 'folder':
        unawaited(pickFolder());
        return;
      case 'apps':
        openApps();
        return;
    }
  }

  void _readArgs() {
    final args = Get.arguments;
    if (args is! Map) return;
    _initialAction = args['initialAction'] as String?;
    final apps = args['apps'];
    if (apps is List<SharedAppInfo>) {
      final appFiles = apps.map((app) {
        final safeName = app.name
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
            .trim();
        final name = '${safeName.isEmpty ? app.packageName : safeName}.apk';
        return _itemFor(app.apkPath, name, name, app.size);
      });
      _assignUnique(appFiles);
      return;
    }
    final argFiles = args['files'];
    if (argFiles is List<PlatformFile>) {
      _loadPlatformFiles(argFiles);
      return;
    }
    final paths = args['paths'];
    if (paths is List) {
      unawaited(
        addFilesFromPaths(paths.whereType<String>().toList(growable: false)),
      );
    }
  }

  void _loadPlatformFiles(List<PlatformFile> picked) {
    final loaded = <SendFileItem>[];
    for (final file in picked) {
      final path = file.path;
      if (path == null) continue;
      loaded.add(_itemFor(path, file.name, file.name, file.size));
    }
    _assignUnique(loaded);
  }

  SendFileItem _itemFor(
    String path,
    String name,
    String relativePath,
    int size,
  ) {
    final id = '${DateTime.now().microsecondsSinceEpoch}-${path.hashCode}';
    return SendFileItem(
      id: id,
      name: name,
      path: path,
      relativePath: relativePath,
      size: size,
    );
  }

  void _assignUnique(Iterable<SendFileItem> incoming) {
    final byPath = <String, SendFileItem>{
      for (final item in files) p.normalize(item.path): item,
    };
    for (final item in incoming) {
      byPath.putIfAbsent(p.normalize(item.path), () => item);
    }
    files.assignAll(byPath.values);
  }

  void _listenForDesktopDrops() {
    if (!Platform.isMacOS) return;
    _dropSubscription = DesktopDropService.fileDrops().listen((paths) {
      if (paths.isNotEmpty) unawaited(addFilesFromPaths(paths));
    });
  }

  Future<void> pickFiles() async {
    await _pickTypedFiles();
  }

  Future<void> pickPhotos() async {
    await _pickTypedFiles(type: FileType.image);
  }

  Future<void> pickVideos() async {
    await _pickTypedFiles(type: FileType.video);
  }

  Future<void> pickDocuments() async {
    await _pickTypedFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'txt',
        'rtf',
        'csv',
        'zip',
        'rar',
        '7z',
        'apk',
      ],
    );
  }

  void openApps() {
    if (!Platform.isAndroid) {
      statusText.value = 'Installed app sharing is only available on Android.';
      return;
    }
    Get.toNamed(Routes.SEND_APPS);
  }

  Future<void> _pickTypedFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
        type: type,
        allowedExtensions: allowedExtensions,
      );
      if (result == null || result.files.isEmpty) return;
      final valid = result.files.where((file) => file.path != null).toList();
      if (valid.isEmpty) {
        statusText.value = 'Selected files are not accessible';
        return;
      }
      _loadPlatformFiles(valid);
      await startServer();
    } catch (error, stack) {
      developer.log(
        'File selection failed',
        name: 'nextshare.transfer',
        error: error,
        stackTrace: stack,
      );
      statusText.value = 'Failed to pick files. Check file permission.';
    }
  }

  Future<void> pickFolder() async {
    try {
      if (Platform.isAndroid) {
        statusText.value = 'Opening Android folder picker...';
        final selected = await PlatformFileService.pickAndroidFolder();
        if (selected == null) {
          statusText.value = files.isEmpty
              ? 'Choose files, a folder, or apps to start sharing'
              : 'Folder selection cancelled';
          return;
        }
        final loaded = selected.map(
          (file) => _itemFor(
            file.path,
            p.basename(file.relativePath),
            file.relativePath,
            file.size,
          ),
        );
        _assignUnique(loaded);
        if (selected.isEmpty) {
          statusText.value = 'The selected folder contains no readable files.';
          return;
        }
        await startServer();
        return;
      }
      final directoryPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose a folder to send',
      );
      if (directoryPath == null) return;
      await addFolder(directoryPath);
    } catch (error, stack) {
      developer.log(
        'Folder selection failed',
        name: 'nextshare.transfer',
        error: error,
        stackTrace: stack,
      );
      statusText.value = Platform.isIOS
          ? 'Folder sharing is limited by the iOS Files provider.'
          : 'The selected folder could not be opened.';
    }
  }

  Future<void> addFolder(String directoryPath) async {
    final root = Directory(directoryPath);
    if (!await root.exists()) {
      statusText.value = 'The selected folder no longer exists.';
      return;
    }
    final loaded = <SendFileItem>[];
    final rootName = p.basename(root.path);
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      final relative = p.join(
        rootName,
        p.relative(entity.path, from: root.path),
      );
      loaded.add(
        _itemFor(entity.path, p.basename(entity.path), relative, stat.size),
      );
    }
    if (loaded.isEmpty) {
      statusText.value = 'The selected folder contains no accessible files.';
      return;
    }
    _assignUnique(loaded);
    await startServer();
  }

  Future<void> addFilesFromPaths(List<String> paths) async {
    final loaded = <SendFileItem>[];
    for (final path in paths) {
      final type = await FileSystemEntity.type(path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await addFolder(path);
        continue;
      }
      if (type != FileSystemEntityType.file) continue;
      final file = File(path);
      final stat = await file.stat();
      loaded.add(_itemFor(path, p.basename(path), p.basename(path), stat.size));
    }
    _assignUnique(loaded);
    if (loaded.isNotEmpty) await startServer();
  }

  Future<void> startServer() async {
    if (files.isEmpty) {
      statusText.value = 'No files selected';
      return;
    }
    final invalid = <SendFileItem>[];
    for (final item in files) {
      if (!await File(item.path).exists()) invalid.add(item);
    }
    if (invalid.isNotEmpty) {
      files.removeWhere(invalid.contains);
      statusText.value = '${invalid.length} missing file(s) were removed.';
      if (files.isEmpty) return;
    }

    await stopServer(clearStatus: false);
    statusText.value = 'Starting secure local transfer...';
    connectionStatus.value = 'searching';
    hasTransferStarted.value = false;
    sentBytes.value = 0;
    _completedIds.clear();

    try {
      _token = _randomToken();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _server!.listen(_handleRequest);
      final ip = await _getWifiIp();
      if (ip == null) {
        statusText.value = 'Wi-Fi IP not found. Connect both devices to Wi-Fi.';
        await stopServer(clearStatus: false);
        return;
      }
      serverUrl.value = 'http://$ip:${_server!.port}/meta?token=$_token';
      transferCode.value = '$ip:${_server!.port}#$_token';
      isServing.value = true;
      statusText.value = 'Ready. Choose a nearby receiver or share the code.';
      await _discovery.startSenderAdvertiser(serverUrl.value);
      _startSpeedTimer();
      developer.log(
        'Transfer ready: ${files.length} files, $totalBytes bytes',
        name: 'nextshare.transfer',
      );
      unawaited(discoverDevices());
    } catch (error, stack) {
      developer.log(
        'Failed to start transfer server',
        name: 'nextshare.transfer',
        error: error,
        stackTrace: stack,
      );
      statusText.value = 'Failed to start transfer server.';
      connectionStatus.value = 'failed';
      await stopServer(clearStatus: false);
    }
  }

  Future<void> discoverDevices() async {
    if (isDiscovering.value) return;
    isDiscovering.value = true;
    connectionStatus.value = 'searching';
    try {
      nearbyDevices.assignAll(await _discovery.discover());
      if (nearbyDevices.isEmpty) {
        statusText.value =
            'No receivers found. Open Receive nearby or use the QR code.';
      }
    } catch (_) {
      connectionStatus.value = 'failed';
      statusText.value =
          'Nearby search failed. QR and transfer code still work.';
    } finally {
      isDiscovering.value = false;
    }
  }

  Future<void> chooseDevice(NearbyDevice device) async {
    if (serverUrl.value.isEmpty) return;
    selectedDevice.value = device;
    connectionStatus.value = 'connecting';
    statusText.value = 'Connecting to ${device.name}...';
    try {
      final connected = await _discovery.sendOffer(device, serverUrl.value);
      if (!connected) {
        connectionStatus.value = 'failed';
        statusText.value =
            '${device.name} did not respond. Keep Receive open and retry.';
        return;
      }
      connectionStatus.value = 'connected';
      statusText.value = 'Connected to ${device.name}. Waiting for download...';
    } catch (_) {
      connectionStatus.value = 'failed';
      statusText.value = 'Could not connect to ${device.name}.';
    }
  }

  Future<String?> _getWifiIp() async {
    try {
      final ip = await NetworkInfo().getWifiIP();
      if (ip != null && ip.isNotEmpty) return ip;
    } catch (_) {}
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && !address.address.startsWith('169.254.')) {
            return address.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  String _randomToken() {
    final random = Random.secure();
    return '${DateTime.now().millisecondsSinceEpoch}-'
        '${random.nextInt(1 << 32).toRadixString(16)}';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.uri.queryParameters['token'] != _token) {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
        return;
      }
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      if (request.uri.path == '/meta') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'version': 2,
            'transferId': _token,
            'files': files
                .map(
                  (file) => {
                    'id': file.id,
                    'name': file.name,
                    'relativePath': file.relativePath,
                    'size': file.size,
                  },
                )
                .toList(),
          }),
        );
        await request.response.close();
        return;
      }
      if (request.uri.pathSegments.length != 2 ||
          request.uri.pathSegments.first != 'file') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final id = request.uri.pathSegments[1];
      final item = files.firstWhereOrNull((file) => file.id == id);
      if (item == null || !await File(item.path).exists()) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      var start = 0;
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (range != null) {
        final match = RegExp(r'^bytes=(\d+)-$').firstMatch(range);
        start = int.tryParse(match?.group(1) ?? '') ?? 0;
        if (start < 0 || start >= item.size) start = 0;
      }
      final responseLength = item.size - start;
      request.response.headers.contentType = ContentType(
        'application',
        'octet-stream',
      );
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.headers.contentLength = responseLength;
      if (start > 0) {
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-${item.size - 1}/${item.size}',
        );
      }
      statusText.value = 'Sending ${item.name}...';
      hasTransferStarted.value = true;
      await for (final chunk in File(item.path).openRead(start)) {
        request.response.add(chunk);
        sentBytes.value = min(totalBytes, sentBytes.value + chunk.length);
      }
      await request.response.close();
      _completedIds.add(item.id);
      await _storage.addHistory(
        TransferHistoryItem(
          id: 'sent-$_token-${item.id}',
          name: item.relativePath,
          type: item.type,
          size: item.size,
          date: DateTime.now(),
          direction: TransferDirection.sent,
          status: TransferHistoryStatus.completed,
          location: item.path,
          sourcePath: item.path,
        ),
      );
      if (_completedIds.length == files.length) {
        sentBytes.value = totalBytes;
        statusText.value = 'Transfer complete';
        connectionStatus.value = 'connected';
        developer.log(
          'Transfer complete: $totalBytes bytes',
          name: 'nextshare.transfer',
        );
      }
    } catch (error, stack) {
      developer.log(
        'Transfer request failed',
        name: 'nextshare.transfer',
        error: error,
        stackTrace: stack,
      );
      statusText.value =
          'Connection interrupted. Receiver can retry or resume.';
      connectionStatus.value = 'failed';
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  void _startSpeedTimer() {
    _speedTimer?.cancel();
    _lastSentBytes = sentBytes.value;
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = sentBytes.value;
      transferSpeed.value = max(0, current - _lastSentBytes).toDouble();
      _lastSentBytes = current;
      if (current >= totalBytes) transferSpeed.value = 0;
    });
  }

  Future<void> stopServer({bool clearStatus = true}) async {
    isServing.value = false;
    serverUrl.value = '';
    transferCode.value = '';
    if (clearStatus) statusText.value = '';
    _speedTimer?.cancel();
    _speedTimer = null;
    await _discovery.stopReceiver();
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
  }

  @override
  void onClose() {
    _dropSubscription?.cancel();
    unawaited(stopServer());
    super.onClose();
  }
}
