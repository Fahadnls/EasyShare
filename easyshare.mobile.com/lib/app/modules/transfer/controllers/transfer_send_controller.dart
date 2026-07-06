import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path/path.dart' as p;

import '../../../data/model/transfer_history_item.dart';
import '../../../data/service/app_storage_service.dart';
import '../../../data/service/chunked_transfer_service.dart';
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
  final currentFileId = ''.obs;
  final currentFileBytes = 0.obs;
  final selectedCategory = 'files'.obs;
  final isPreparingFiles = false.obs;
  final preparationText = 'Preparing files…'.obs;

  final files = <SendFileItem>[].obs;
  final nearbyDevices = <NearbyDevice>[].obs;
  final selectedDevice = Rxn<NearbyDevice>();
  final qrReceiverName = ''.obs;

  final AppStorageService _storage = Get.find<AppStorageService>();
  late final DeviceDiscoveryService _discovery;
  final Set<String> _completedIds = {};
  final Set<String> _activeFileRequests = {};
  final Map<String, int> _sentByFile = {};

  HttpServer? _server;
  String _token = '';
  StreamSubscription<List<String>>? _dropSubscription;
  Timer? _speedTimer;
  Timer? _discoveryTimer;
  int _lastSentBytes = 0;
  String? _initialAction;

  int get totalBytes => files.fold(0, (sum, file) => sum + file.size);
  String get localDeviceName => _storage.deviceName.value;
  int get remainingBytes => max(0, totalBytes - sentBytes.value);
  double get progress =>
      totalBytes == 0 ? 0 : (sentBytes.value / totalBytes).clamp(0, 1);
  Duration? get estimatedTime {
    if (transferSpeed.value <= 0 || remainingBytes == 0) return null;
    return Duration(seconds: (remainingBytes / transferSpeed.value).ceil());
  }

  bool get isComplete =>
      files.isNotEmpty && _completedIds.length == files.length;
  int get currentFileIndex {
    final index = files.indexWhere((file) => file.id == currentFileId.value);
    return index < 0 ? 0 : index + 1;
  }

  SendFileItem? get currentFile =>
      files.firstWhereOrNull((file) => file.id == currentFileId.value);
  double get currentFileProgress {
    final file = currentFile;
    if (file == null || file.size == 0) return 0;
    return (currentFileBytes.value / file.size).clamp(0, 1);
  }

  int sentBytesFor(SendFileItem file) =>
      (_sentByFile[file.id] ?? 0).clamp(0, file.size);

  double progressFor(SendFileItem file) {
    if (file.size == 0) return _completedIds.contains(file.id) ? 1 : 0;
    return (sentBytesFor(file) / file.size).clamp(0, 1);
  }

  String statusFor(SendFileItem file) {
    if (_completedIds.contains(file.id)) return 'Complete';
    if (_activeFileRequests.contains(file.id)) return 'Sending';
    if (connectionStatus.value == 'failed' && currentFileId.value == file.id) {
      return 'Failed';
    }
    return 'Waiting';
  }

  @override
  void onInit() {
    super.onInit();
    _discovery = DeviceDiscoveryService(deviceName: localDeviceName);
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
        unawaited(openApps());
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
    developer.log(
      'Selected files: ${files.length}, $totalBytes bytes',
      name: 'nextshare.transfer',
    );
  }

  void _listenForDesktopDrops() {
    if (!Platform.isMacOS) return;
    _dropSubscription = DesktopDropService.fileDrops().listen((paths) {
      if (paths.isNotEmpty) unawaited(addFilesFromPaths(paths));
    });
  }

  Future<void> pickFiles() async {
    selectedCategory.value = 'files';
    await _pickTypedFiles(category: 'files');
  }

  Future<void> pickPhotos() async {
    selectedCategory.value = 'photos';
    await _pickTypedFiles(type: FileType.image, category: 'photos');
  }

  Future<void> pickVideos() async {
    selectedCategory.value = 'videos';
    await _pickTypedFiles(type: FileType.video, category: 'videos');
  }

  Future<void> pickDocuments() async {
    selectedCategory.value = 'documents';
    await _pickTypedFiles(
      type: FileType.custom,
      category: 'documents',
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
        'odt',
        'ods',
        'odp',
      ],
    );
  }

  Future<void> openApps() async {
    if (!Platform.isAndroid) {
      statusText.value = 'Installed app sharing is only available on Android.';
      Get.snackbar(
        'App sharing unavailable',
        'iOS does not allow installed apps to be shared.',
      );
      return;
    }
    final result = await Get.toNamed(Routes.SEND_APPS);
    if (result is! List<SharedAppInfo> || result.isEmpty) return;
    selectedCategory.value = 'apps';
    final appFiles = result.map((app) {
      final safeName = app.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final name = '${safeName.isEmpty ? app.packageName : safeName}.apk';
      return _itemFor(app.apkPath, name, name, app.size);
    });
    _assignUnique(appFiles);
    await startServer();
  }

  Future<void> _pickTypedFiles({
    FileType type = FileType.any,
    required String category,
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
      final accessible = result.files
          .where((file) => file.path != null)
          .toList();
      final valid = accessible
          .where((file) => _matchesCategory(file.name, category))
          .toList();
      if (valid.isEmpty) {
        statusText.value = accessible.isEmpty
            ? 'Selected files are not accessible.'
            : 'No $category matched this selection.';
        return;
      }
      final rejectedCount = accessible.length - valid.length;
      _loadPlatformFiles(valid);
      if (rejectedCount > 0) {
        statusText.value =
            '$rejectedCount item(s) were skipped because they are not $category.';
      }
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
      selectedCategory.value = 'folder';
      if (Platform.isAndroid) {
        isPreparingFiles.value = true;
        preparationText.value = 'Reading folder contents…';
        statusText.value =
            'Choose a folder. Large folders may take a moment to prepare.';
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
      if (Platform.isIOS) {
        statusText.value =
            'Folder sharing is limited by the iOS Files provider.';
      } else if (error is PlatformException && error.message != null) {
        statusText.value = error.message!;
      } else {
        statusText.value =
            'The selected folder could not be opened. Choose another folder.';
      }
    } finally {
      isPreparingFiles.value = false;
    }
  }

  Future<void> pickMore() async {
    switch (selectedCategory.value) {
      case 'photos':
        await pickPhotos();
      case 'videos':
        await pickVideos();
      case 'documents':
        await pickDocuments();
      case 'folder':
        await pickFolder();
      case 'apps':
        await openApps();
      default:
        await pickFiles();
    }
  }

  bool _matchesCategory(String name, String category) {
    if (category == 'files') return true;
    final extension = p.extension(name).replaceFirst('.', '').toLowerCase();
    const photoExtensions = {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'heic',
      'heif',
      'avif',
      'tif',
      'tiff',
    };
    const videoExtensions = {
      'mp4',
      'm4v',
      'mov',
      'mkv',
      'avi',
      'webm',
      '3gp',
      '3g2',
      'mpeg',
      'mpg',
      'ts',
      'm2ts',
    };
    const documentExtensions = {
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
      'odt',
      'ods',
      'odp',
    };
    return switch (category) {
      'photos' => photoExtensions.contains(extension),
      'videos' => videoExtensions.contains(extension),
      'documents' => documentExtensions.contains(extension),
      _ => true,
    };
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

    final shouldShowPreparation =
        totalBytes >= 50 * 1024 * 1024 ||
        selectedCategory.value == 'folder' ||
        selectedCategory.value == 'apps';
    if (shouldShowPreparation) {
      isPreparingFiles.value = true;
      preparationText.value = selectedCategory.value == 'apps'
          ? 'Preparing app package and QR code…'
          : selectedCategory.value == 'folder'
          ? 'Preparing folder and QR code…'
          : 'Preparing ${files.length} large file(s)…';
      // Give Flutter one frame to display the preparation state before
      // network setup and file validation continue.
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    await stopServer(clearStatus: false);
    statusText.value = 'Starting secure local transfer...';
    connectionStatus.value = 'searching';
    hasTransferStarted.value = false;
    sentBytes.value = 0;
    currentFileId.value = '';
    currentFileBytes.value = 0;
    qrReceiverName.value = '';
    _completedIds.clear();
    _activeFileRequests.clear();
    _sentByFile.clear();

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
      _discoveryTimer?.cancel();
      _discoveryTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (selectedDevice.value == null &&
            connectionStatus.value == 'searching') {
          unawaited(discoverDevices());
        }
      });
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
    } finally {
      if (shouldShowPreparation) isPreparingFiles.value = false;
    }
  }

  Future<void> discoverDevices() async {
    if (isDiscovering.value) return;
    isDiscovering.value = true;
    connectionStatus.value = 'searching';
    developer.log('Discovery started', name: 'nextshare.transfer');
    try {
      nearbyDevices.assignAll(await _discovery.discover());
      if (nearbyDevices.isEmpty) {
        statusText.value =
            'No receivers found. Open Receive nearby or use the QR code.';
      } else {
        developer.log(
          'Discovery found ${nearbyDevices.length} receiver(s)',
          name: 'nextshare.transfer',
        );
      }
    } catch (error, stack) {
      connectionStatus.value = 'failed';
      statusText.value =
          'Nearby search failed. QR and transfer code still work.';
      developer.log(
        'Discovery failed',
        name: 'nextshare.transfer',
        error: error,
        stackTrace: stack,
      );
    } finally {
      isDiscovering.value = false;
    }
  }

  Future<void> chooseDevice(NearbyDevice device) async {
    if (serverUrl.value.isEmpty) return;
    selectedDevice.value = device;
    connectionStatus.value = 'connecting';
    statusText.value = 'Waiting for receiver to accept…';
    developer.log(
      'Transfer request sent to ${device.name}',
      name: 'nextshare.transfer',
    );
    try {
      final decision = await _discovery.sendOffer(
        device,
        serverUrl.value,
        fileCount: files.length,
        totalBytes: totalBytes,
        fileName: files.first.name,
      );
      switch (decision) {
        case OfferDecision.accepted:
          connectionStatus.value = 'connected';
          statusText.value = '${device.name} accepted. Starting transfer…';
          developer.log(
            'Transfer accepted by ${device.name}',
            name: 'nextshare.transfer',
          );
        case OfferDecision.declined:
          connectionStatus.value = 'declined';
          statusText.value = '${device.name} declined the transfer.';
          developer.log(
            'Transfer declined by ${device.name}',
            name: 'nextshare.transfer',
          );
        case OfferDecision.timedOut:
          connectionStatus.value = 'failed';
          statusText.value =
              '${device.name} did not respond. Keep Receive open and retry.';
      }
    } catch (error, stack) {
      connectionStatus.value = 'failed';
      statusText.value = 'Could not connect to ${device.name}.';
      developer.log(
        'Transfer request failed',
        name: 'nextshare.transfer',
        error: error,
        stackTrace: stack,
      );
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
        final receiverName = request.headers.value('X-NextShare-Device');
        if (receiverName != null && receiverName.trim().isNotEmpty) {
          qrReceiverName.value = receiverName.trim();
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'version': 2,
            'transferId': _token,
            'senderName': localDeviceName,
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
      if (!_activeFileRequests.add(id)) {
        request.response.statusCode = HttpStatus.conflict;
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
      currentFileId.value = item.id;
      currentFileBytes.value = start;
      _sentByFile[item.id] = max(_sentByFile[item.id] ?? 0, start);
      await ChunkedTransferService.sendFile(
        file: File(item.path),
        start: start,
        response: request.response,
        onProgress: (filePosition) {
          currentFileBytes.value = filePosition;
          _sentByFile[item.id] = max(_sentByFile[item.id] ?? 0, filePosition);
          sentBytes.value = min(
            totalBytes,
            _sentByFile.values.fold(0, (sum, bytes) => sum + bytes),
          );
        },
      );
      await request.response.close();
      _activeFileRequests.remove(id);
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
      final id = request.uri.pathSegments.length == 2
          ? request.uri.pathSegments[1]
          : null;
      if (id != null) _activeFileRequests.remove(id);
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

  Future<void> cancelTransfer() async {
    connectionStatus.value = 'cancelled';
    statusText.value = 'Transfer cancelled';
    developer.log('Transfer cancelled', name: 'nextshare.transfer');
    await stopServer(clearStatus: false);
  }

  Future<void> openTransferredFile() async {
    if (files.isEmpty) return;
    await PlatformFileService.openPath(files.first.path);
  }

  Future<void> openTransferredFolder() async {
    if (files.isEmpty) return;
    await PlatformFileService.openPath(File(files.first.path).parent.path);
  }

  void _startSpeedTimer() {
    _speedTimer?.cancel();
    _lastSentBytes = sentBytes.value;
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = sentBytes.value;
      transferSpeed.value = max(0, current - _lastSentBytes).toDouble();
      _lastSentBytes = current;
      if (current > 0 && current < totalBytes) {
        developer.log(
          'Transfer progress: ${(progress * 100).toStringAsFixed(1)}%',
          name: 'nextshare.transfer',
        );
      }
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
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
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
