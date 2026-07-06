import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/model/transfer_history_item.dart';
import '../../../data/service/app_storage_service.dart';
import '../../../data/service/chunked_transfer_service.dart';
import '../../../data/service/device_discovery_service.dart';
import '../../../data/service/download_service.dart';
import '../../../data/service/platform_file_service.dart';

class ReceiveFileItem {
  ReceiveFileItem({
    required this.id,
    required this.name,
    required this.relativePath,
    required this.size,
  });

  final String id;
  final String name;
  final String relativePath;
  final int size;
  final RxInt received = 0.obs;
  final RxString status = 'queued'.obs;
  String? savedPath;

  String get type {
    final extension = p.extension(name).replaceFirst('.', '').toLowerCase();
    return extension.isEmpty ? 'file' : extension;
  }
}

class TransferCancelled implements Exception {
  const TransferCancelled();
}

class TransferReceiveController extends GetxController {
  TransferReceiveController()
    : supportsScanner =
          Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  final bool supportsScanner;
  final manualCodeController = TextEditingController();
  final AppStorageService storage = Get.find<AppStorageService>();

  final statusText = ''.obs;
  final isScanning = false.obs;
  final showScanner = false.obs;
  final isDownloading = false.obs;
  final isPaused = false.obs;
  final hasFailed = false.obs;
  final hasCameraAccess = false.obs;
  final cameraPermissionChecked = false.obs;
  final transferSpeed = 0.0.obs;
  final estimatedSeconds = 0.obs;
  final files = <ReceiveFileItem>[].obs;
  final nearbySenders = <NearbySender>[].obs;
  final isSearchingNearby = false.obs;
  final overallProgress = 0.0.obs;
  final pendingOffer = Rxn<IncomingTransferOffer>();
  final peerName = 'Nearby sender'.obs;

  late final DeviceDiscoveryService _discovery;
  HttpClient? _client;
  StreamSubscription<List<int>>? _activeSubscription;
  Completer<void>? _activeCompleter;
  IOSink? _activeSink;
  Timer? _speedTimer;
  Uri? _lastUri;
  String? _lastToken;
  String? _transferId;
  int _totalBytes = 0;
  int _totalReceived = 0;
  int _lastReceived = 0;
  int _generation = 0;
  Completer<bool>? _offerDecision;

  int get totalBytes => _totalBytes;
  String get localDeviceName => storage.deviceName.value;
  int get receivedBytes => _totalReceived;
  int get remainingBytes => max(0, _totalBytes - _totalReceived);
  bool get isComplete =>
      files.isNotEmpty &&
      files.every((file) => file.status.value == 'complete');
  ReceiveFileItem? get currentFile {
    return files.firstWhereOrNull((file) => file.status.value == 'receiving') ??
        files.firstWhereOrNull((file) => file.status.value != 'complete');
  }

  int get currentFileIndex {
    final item = currentFile;
    if (item == null) return isComplete ? files.length : 0;
    return files.indexOf(item) + 1;
  }

  String get saveLocationLabel => storage.defaultSaveLocation.value.isEmpty
      ? (Platform.isIOS ? 'App Documents' : 'Downloads')
      : storage.defaultSaveLocation.value;

  @override
  void onInit() {
    super.onInit();
    _discovery = DeviceDiscoveryService(deviceName: localDeviceName);
    resetReceiveFlow(clearCode: false);
    unawaited(_prepareScannerPermission());
    unawaited(
      _discovery.startReceiver(onOffer: _handleIncomingOffer).catchError((_) {
        statusText.value =
            'Nearby discovery unavailable. QR and transfer code still work.';
      }),
    );
    unawaited(discoverNearbySenders());
  }

  Future<void> discoverNearbySenders() async {
    if (isSearchingNearby.value || isDownloading.value) return;
    isSearchingNearby.value = true;
    try {
      nearbySenders.assignAll(await _discovery.discoverSenders());
    } finally {
      isSearchingNearby.value = false;
    }
  }

  Future<void> receiveFromNearby(NearbySender sender) {
    return startFromQr(sender.url, senderName: sender.name);
  }

  Future<bool> _handleIncomingOffer(IncomingTransferOffer offer) {
    if (isDownloading.value ||
        files.isNotEmpty ||
        pendingOffer.value != null ||
        _offerDecision != null) {
      return Future.value(false);
    }
    pendingOffer.value = offer;
    peerName.value = offer.senderName;
    statusText.value = '${offer.senderName} wants to send files.';
    _offerDecision = Completer<bool>();
    developer.log(
      'Transfer request received from ${offer.senderName}',
      name: 'nextshare.transfer',
    );
    return _offerDecision!.future;
  }

  Future<void> acceptOffer() async {
    final offer = pendingOffer.value;
    final decision = _offerDecision;
    if (offer == null || decision == null || decision.isCompleted) return;
    pendingOffer.value = null;
    _offerDecision = null;
    decision.complete(true);
    developer.log('Transfer accepted', name: 'nextshare.transfer');
    await startFromQr(offer.url, senderName: offer.senderName);
  }

  void declineOffer() {
    final decision = _offerDecision;
    pendingOffer.value = null;
    _offerDecision = null;
    if (decision != null && !decision.isCompleted) decision.complete(false);
    statusText.value = 'Ready to receive';
    developer.log('Transfer declined', name: 'nextshare.transfer');
  }

  Future<void> startFromQr(String data, {String? senderName}) async {
    if (isDownloading.value) return;
    final uri = _parseTransferInput(data);
    if (uri == null) {
      statusText.value = 'Invalid transfer code';
      return;
    }
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      statusText.value = 'Missing transfer token';
      return;
    }
    if (_lastToken == token && files.isNotEmpty && !hasFailed.value) return;

    final generation = ++_generation;
    _lastUri = uri;
    _lastToken = token;
    peerName.value = senderName ?? 'Nearby sender';
    isScanning.value = false;
    showScanner.value = false;
    isDownloading.value = true;
    isPaused.value = false;
    hasFailed.value = false;
    statusText.value = 'Connecting to sender...';
    developer.log('Transfer start', name: 'nextshare.transfer');

    try {
      final metaUri = uri.path == '/meta' ? uri : uri.replace(path: '/meta');
      final meta = await _fetchMeta(metaUri);
      final senderDeviceName = meta['senderName'] as String?;
      if (senderDeviceName != null && senderDeviceName.trim().isNotEmpty) {
        peerName.value = senderDeviceName.trim();
      }
      _transferId = meta['transferId'] as String? ?? token;
      final rawFiles = meta['files'];
      if (rawFiles is! List || rawFiles.isEmpty) {
        throw StateError('No files in transfer');
      }
      final receivedFiles = rawFiles.map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        final name = _sanitizeSegment(item['name'] as String? ?? 'file.bin');
        return ReceiveFileItem(
          id: item['id'] as String,
          name: name,
          relativePath: _sanitizeRelativePath(
            item['relativePath'] as String? ?? name,
          ),
          size: (item['size'] as num).toInt(),
        );
      }).toList();
      files.assignAll(receivedFiles);
      _totalBytes = receivedFiles.fold(0, (sum, file) => sum + file.size);
      final availableBytes = await DownloadService.getAvailableBytes();
      if (availableBytes != null && _totalBytes > availableBytes) {
        throw StateError('Not enough storage');
      }
      _totalReceived = 0;
      overallProgress.value = 0;
      _startSpeedTimer();
      await _downloadAll(uri, token, generation);
      if (generation != _generation) return;
      statusText.value = 'Transfer complete';
      overallProgress.value = 1;
      developer.log(
        'Transfer complete: $_totalReceived bytes',
        name: 'nextshare.transfer',
      );
    } on TransferCancelled {
      statusText.value = 'Transfer cancelled';
    } catch (error, stack) {
      if (generation != _generation) return;
      hasFailed.value = true;
      statusText.value = 'Transfer failed: ${_userErrorMessage(error)}';
      for (final item in files.where(
        (file) => file.status.value == 'receiving',
      )) {
        item.status.value = 'failed';
      }
      await _recordIncomplete(TransferHistoryStatus.failed);
      developer.log(
        'Transfer failed',
        name: 'nextshare.transfer',
        error: error,
        stackTrace: stack,
      );
    } finally {
      if (generation == _generation) {
        isDownloading.value = false;
        isPaused.value = false;
        _speedTimer?.cancel();
        transferSpeed.value = 0;
      }
    }
  }

  Future<void> _downloadAll(Uri uri, String token, int generation) async {
    for (final item in files) {
      if (generation != _generation) throw const TransferCancelled();
      if (item.status.value == 'complete') continue;
      await _downloadFileWithRetry(uri, token, item, generation);
    }
  }

  Future<void> _downloadFileWithRetry(
    Uri uri,
    String token,
    ReceiveFileItem item,
    int generation,
  ) async {
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await _downloadFile(uri, token, item, generation);
        return;
      } catch (error, stack) {
        if (error is TransferCancelled || generation != _generation) rethrow;
        lastError = error;
        lastStack = stack;
        item.status.value = 'retrying';
        statusText.value = 'Connection interrupted. Retrying ($attempt/3)…';
        developer.log(
          'Transfer retry $attempt for ${item.name}',
          name: 'nextshare.transfer',
          error: error,
        );
        await _activeSubscription?.cancel();
        _activeSubscription = null;
        _activeCompleter = null;
        try {
          await _activeSink?.close();
        } catch (_) {}
        _activeSink = null;
        _client?.close(force: true);
        _client = null;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack!);
  }

  Future<bool> startFromManualCode() async {
    final code = manualCodeController.text.trim();
    if (code.isEmpty) {
      statusText.value = supportsScanner
          ? 'Scan QR or paste a transfer code'
          : 'Paste a transfer code from the sender';
      return false;
    }
    await startFromQr(code);
    return true;
  }

  Future<void> openQrScanner() async {
    if (!supportsScanner) return;
    if (Platform.isIOS && !hasCameraAccess.value) {
      await requestCameraAccess();
    }
    if (!hasCameraAccess.value) return;
    showScanner.value = true;
    isScanning.value = true;
    statusText.value = 'Point the camera at the sender QR code.';
  }

  void closeQrScanner() {
    showScanner.value = false;
    isScanning.value = false;
    statusText.value =
        'This device is visible to nearby senders on the same Wi-Fi.';
  }

  void pauseTransfer() {
    if (!isDownloading.value || isPaused.value) return;
    _activeSubscription?.pause();
    isPaused.value = true;
    statusText.value = 'Transfer paused';
    developer.log('Transfer paused', name: 'nextshare.transfer');
  }

  void resumeTransfer() {
    if (!isPaused.value) return;
    _activeSubscription?.resume();
    isPaused.value = false;
    statusText.value = 'Receiving files...';
    developer.log('Transfer resumed', name: 'nextshare.transfer');
  }

  Future<void> cancelTransfer() async {
    if (!isDownloading.value && !isPaused.value) return;
    _generation++;
    await _activeSubscription?.cancel();
    _activeSubscription = null;
    await _activeSink?.close();
    _activeSink = null;
    if (_activeCompleter?.isCompleted == false) {
      _activeCompleter?.completeError(const TransferCancelled());
    }
    _client?.close(force: true);
    _client = null;
    isDownloading.value = false;
    isPaused.value = false;
    hasFailed.value = false;
    statusText.value = 'Transfer cancelled';
    _speedTimer?.cancel();
    for (final item in files.where((file) => file.status.value != 'complete')) {
      item.status.value = 'cancelled';
    }
    await _recordIncomplete(TransferHistoryStatus.cancelled);
    developer.log('Transfer cancelled', name: 'nextshare.transfer');
  }

  Future<void> retryTransfer() async {
    final uri = _lastUri;
    if (uri == null) return;
    for (final item in files) {
      if (item.status.value == 'failed' || item.status.value == 'cancelled') {
        item.status.value = 'queued';
      }
    }
    hasFailed.value = false;
    developer.log('Transfer retry', name: 'nextshare.transfer');
    await _resumeKnownTransfer(uri);
  }

  Future<void> _resumeKnownTransfer(Uri uri) async {
    final token = _lastToken;
    if (token == null || isDownloading.value) return;
    final generation = ++_generation;
    isDownloading.value = true;
    isPaused.value = false;
    statusText.value = 'Resuming transfer...';
    _client = HttpClient();
    _startSpeedTimer();
    try {
      await _downloadAll(uri, token, generation);
      if (generation != _generation) return;
      statusText.value = 'Transfer complete';
      overallProgress.value = 1;
    } on TransferCancelled {
      statusText.value = 'Transfer cancelled';
    } catch (error, stack) {
      if (generation != _generation) return;
      hasFailed.value = true;
      statusText.value = 'Transfer failed: ${_userErrorMessage(error)}';
      for (final item in files.where(
        (file) => file.status.value == 'receiving',
      )) {
        item.status.value = 'failed';
      }
      await _recordIncomplete(TransferHistoryStatus.failed);
      developer.log(
        'Transfer retry failed',
        name: 'nextshare.transfer',
        error: error,
        stackTrace: stack,
      );
    } finally {
      if (generation == _generation) {
        isDownloading.value = false;
        isPaused.value = false;
        _speedTimer?.cancel();
        transferSpeed.value = 0;
      }
    }
  }

  void resetReceiveFlow({bool clearCode = true}) {
    unawaited(cancelTransfer());
    declineOffer();
    if (clearCode) manualCodeController.clear();
    files.clear();
    overallProgress.value = 0;
    transferSpeed.value = 0;
    estimatedSeconds.value = 0;
    _totalBytes = 0;
    _totalReceived = 0;
    _lastReceived = 0;
    _lastUri = null;
    _lastToken = null;
    _transferId = null;
    isDownloading.value = false;
    isPaused.value = false;
    hasFailed.value = false;
    isScanning.value = supportsScanner;
    showScanner.value = false;
    statusText.value = supportsScanner
        ? 'Waiting for sender nearby…'
        : 'Paste the transfer code from the sender';
  }

  Future<void> openReceivedFile() async {
    final path = files
        .firstWhereOrNull((file) => file.savedPath?.isNotEmpty == true)
        ?.savedPath;
    if (path != null) await PlatformFileService.openPath(path);
  }

  Future<void> openReceivedFolder() async {
    final path = files
        .firstWhereOrNull((file) => file.savedPath?.isNotEmpty == true)
        ?.savedPath;
    if (path != null) {
      await PlatformFileService.openPath(File(path).parent.path);
    }
  }

  Future<void> _prepareScannerPermission() async {
    if (!supportsScanner || (!Platform.isIOS && !Platform.isMacOS)) {
      hasCameraAccess.value = supportsScanner;
      cameraPermissionChecked.value = true;
      return;
    }
    if (Platform.isMacOS) {
      // mobile_scanner owns the native macOS camera authorization flow.
      hasCameraAccess.value = true;
      cameraPermissionChecked.value = true;
      return;
    }
    try {
      final status = await Permission.camera.status;
      hasCameraAccess.value = status.isGranted;
      cameraPermissionChecked.value = true;
      if (!status.isGranted) {
        statusText.value =
            'Camera access is off. Nearby discovery and transfer codes still work.';
      }
    } on MissingPluginException {
      hasCameraAccess.value = true;
      cameraPermissionChecked.value = true;
    }
  }

  Future<void> requestCameraAccess() async {
    if (!Platform.isIOS && !Platform.isMacOS) return;
    if (Platform.isMacOS) {
      hasCameraAccess.value = true;
      cameraPermissionChecked.value = true;
      return;
    }
    try {
      final status = await Permission.camera.request();
      hasCameraAccess.value = status.isGranted;
      cameraPermissionChecked.value = true;
      statusText.value = status.isGranted
          ? 'Scan QR or paste a transfer code'
          : 'Camera access is off. Use nearby discovery or a transfer code.';
    } on MissingPluginException {
      hasCameraAccess.value = true;
      cameraPermissionChecked.value = true;
    }
  }

  Future<void> openSettingsForCamera() async {
    try {
      await openAppSettings();
    } on MissingPluginException {
      statusText.value = 'Open System Settings to allow camera access.';
    }
  }

  Future<Map<String, dynamic>> _fetchMeta(Uri uri) async {
    _client ??= HttpClient();
    _client!.connectionTimeout = const Duration(seconds: 12);
    final request = await _client!.getUrl(uri);
    request.headers.set('X-NextShare-Device', localDeviceName);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('Meta request failed');
    }
    final body = await utf8.decoder.bind(response).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<void> _downloadFile(
    Uri baseUri,
    String token,
    ReceiveFileItem item,
    int generation,
  ) async {
    final tempFile = await _temporaryFile(item);
    var offset = await tempFile.exists() ? await tempFile.length() : 0;
    if (offset > item.size) {
      await tempFile.delete();
      offset = 0;
    }
    item.received.value = offset;
    _recalculateReceived();
    if (offset == item.size) {
      await _finishFile(tempFile, item);
      return;
    }

    item.status.value = 'receiving';
    statusText.value = 'Receiving ${item.name}...';
    final fileUri = baseUri.replace(
      path: '/file/${item.id}',
      queryParameters: {'token': token},
    );
    _client ??= HttpClient();
    final request = await _client!.getUrl(fileUri);
    if (offset > 0) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
    }
    final response = await request.close();
    final validStatus =
        response.statusCode == HttpStatus.ok ||
        response.statusCode == HttpStatus.partialContent;
    if (!validStatus) throw StateError('File download failed');
    if (offset > 0 && response.statusCode == HttpStatus.ok) {
      await tempFile.delete();
      offset = 0;
      item.received.value = 0;
      _recalculateReceived();
    }
    final sink = tempFile.openWrite(
      mode: offset > 0 ? FileMode.append : FileMode.write,
    );
    _activeSink = sink;
    try {
      await ChunkedTransferService.receiveFile(
        source: response,
        sink: sink,
        isCancelled: () => generation != _generation,
        onChunk: (chunkBytes) {
          item.received.value += chunkBytes;
          _totalReceived += chunkBytes;
          overallProgress.value = _totalBytes == 0
              ? 0
              : (_totalReceived / _totalBytes).clamp(0, 1);
        },
      );
      await sink.close();
      _activeSink = null;
    } on ChunkedTransferCancelled {
      try {
        await sink.close();
      } catch (_) {}
      _activeSink = null;
      throw const TransferCancelled();
    } catch (_) {
      item.status.value = 'failed';
      try {
        await sink.close();
      } catch (_) {}
      _activeSink = null;
      rethrow;
    }
    if (generation != _generation) throw const TransferCancelled();
    if (await tempFile.length() != item.size) {
      item.status.value = 'failed';
      throw StateError('File download incomplete');
    }
    await _finishFile(tempFile, item);
  }

  Future<File> _temporaryFile(ReceiveFileItem item) async {
    final temp = await getTemporaryDirectory();
    final transfer = _sanitizeSegment(_transferId ?? _lastToken ?? 'transfer');
    final directory = Directory(p.join(temp.path, 'nextshare', transfer));
    await directory.create(recursive: true);
    return File(p.join(directory.path, '${item.id}.part'));
  }

  Future<void> _finishFile(File tempFile, ReceiveFileItem item) async {
    final savedPath = await _saveReceivedFile(tempFile, item.relativePath);
    if (savedPath == null) {
      item.status.value = 'failed';
      throw StateError('Failed to save file');
    }
    item.savedPath = savedPath;
    item.status.value = 'complete';
    item.received.value = item.size;
    _recalculateReceived();
    await _storageAddHistory(item, savedPath);
    try {
      await tempFile.delete();
    } catch (_) {}
  }

  Future<void> _storageAddHistory(
    ReceiveFileItem item,
    String savedPath,
  ) async {
    await storage.addHistory(
      TransferHistoryItem(
        id: 'received-${_transferId ?? _lastToken}-${item.id}',
        name: item.relativePath,
        type: item.type,
        size: item.size,
        date: DateTime.now(),
        direction: TransferDirection.received,
        status: TransferHistoryStatus.completed,
        location: savedPath,
      ),
    );
  }

  Future<void> _recordIncomplete(TransferHistoryStatus historyStatus) async {
    final matchingStatus = historyStatus == TransferHistoryStatus.failed
        ? 'failed'
        : 'cancelled';
    for (final item in files.where(
      (file) => file.status.value == matchingStatus,
    )) {
      await storage.addHistory(
        TransferHistoryItem(
          id: 'received-${_transferId ?? _lastToken}-${item.id}',
          name: item.relativePath,
          type: item.type,
          size: item.size,
          date: DateTime.now(),
          direction: TransferDirection.received,
          status: historyStatus,
          location: saveLocationLabel,
        ),
      );
    }
  }

  void _recalculateReceived() {
    _totalReceived = files.fold(0, (sum, item) => sum + item.received.value);
    overallProgress.value = _totalBytes == 0
        ? 0
        : (_totalReceived / _totalBytes).clamp(0, 1);
  }

  void _startSpeedTimer() {
    _speedTimer?.cancel();
    _lastReceived = _totalReceived;
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = _totalReceived;
      final bytesPerSecond = max(0, current - _lastReceived);
      transferSpeed.value = bytesPerSecond.toDouble();
      _lastReceived = current;
      estimatedSeconds.value = bytesPerSecond <= 0
          ? 0
          : (remainingBytes / bytesPerSecond).ceil();
      developer.log(
        'Transfer progress: ${(overallProgress.value * 100).toStringAsFixed(1)}%',
        name: 'nextshare.transfer',
      );
    });
  }

  Future<String?> _saveReceivedFile(File tempFile, String relativePath) async {
    final configured = storage.defaultSaveLocation.value;
    var destinationPath = configured;
    if (Platform.isMacOS && destinationPath.isNotEmpty) {
      destinationPath =
          await PlatformFileService.restoreFolderAccess() ?? destinationPath;
    }
    if (destinationPath.isNotEmpty) {
      final root = Directory(destinationPath);
      if (await root.exists()) {
        return _copyToDirectory(tempFile, root, relativePath);
      }
      storage.defaultSaveLocation.value = '';
    }
    if (Platform.isAndroid) {
      final sdk = await DownloadService.getSdkInt();
      if (sdk >= 29) {
        return DownloadService.saveToDownloads(
          tempFile.path,
          p.basename(relativePath),
          relativeDirectory: p.dirname(relativePath),
        );
      }
      final storagePermission = await Permission.storage.request();
      if (!storagePermission.isGranted) return null;
      final downloads = Directory('/storage/emulated/0/Download');
      await downloads.create(recursive: true);
      return _copyToDirectory(tempFile, downloads, relativePath);
    }
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      final downloads = await getDownloadsDirectory();
      if (downloads == null) return null;
      await downloads.create(recursive: true);
      return _copyToDirectory(tempFile, downloads, relativePath);
    }
    final documents = await getApplicationDocumentsDirectory();
    await documents.create(recursive: true);
    return _copyToDirectory(tempFile, documents, relativePath);
  }

  Future<String> _copyToDirectory(
    File source,
    Directory root,
    String relativePath,
  ) async {
    var destination = File(p.join(root.path, relativePath));
    await destination.parent.create(recursive: true);
    destination = await _dedupeFile(destination);
    final sink = destination.openWrite();
    await source.openRead().pipe(sink);
    return destination.path;
  }

  Future<File> _dedupeFile(File file) async {
    if (!await file.exists()) return file;
    final directory = file.parent;
    final base = p.basenameWithoutExtension(file.path);
    final extension = p.extension(file.path);
    var index = 1;
    while (true) {
      final candidate = File(
        p.join(directory.path, '$base ($index)$extension'),
      );
      if (!await candidate.exists()) return candidate;
      index++;
    }
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
    final hashIndex = value.lastIndexOf('#');
    if (hashIndex <= 0) return null;
    final hostAndPort = value.substring(0, hashIndex);
    final separator = hostAndPort.lastIndexOf(':');
    if (separator <= 0) return null;
    final host = hostAndPort.substring(0, separator).trim();
    final port = int.tryParse(hostAndPort.substring(separator + 1).trim());
    final token = value.substring(hashIndex + 1).trim();
    if (host.isEmpty || port == null || token.isEmpty) return null;
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: '/meta',
      queryParameters: {'token': token},
    );
  }

  String _sanitizeRelativePath(String raw) {
    final normalized = raw.replaceAll('\\', '/');
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty && segment != '..')
        .map(_sanitizeSegment)
        .where((segment) => segment.isNotEmpty)
        .toList();
    return segments.isEmpty ? 'file.bin' : p.joinAll(segments);
  }

  String _sanitizeSegment(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
  }

  String _userErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('Meta request failed')) return 'sender is unreachable';
    if (text.contains('No files')) return 'sender offered no files';
    if (text.contains('Not enough storage')) {
      return 'there is not enough available storage';
    }
    if (text.contains('save')) return 'the destination is not writable or full';
    if (text.contains('incomplete')) {
      return 'connection ended before completion';
    }
    if (error is SocketException) return 'connection to sender was lost';
    return 'check Wi-Fi, file access, and available storage';
  }

  @override
  void onClose() {
    _generation++;
    final decision = _offerDecision;
    if (decision != null && !decision.isCompleted) decision.complete(false);
    manualCodeController.dispose();
    _speedTimer?.cancel();
    _activeSubscription?.cancel();
    _client?.close(force: true);
    unawaited(_discovery.stopReceiver());
    super.onClose();
  }
}
