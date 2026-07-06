import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

const int discoveryPort = 45873;
const String _discoverMessage = 'NEXTSHARE_DISCOVER_V1';
const String _findSendersMessage = 'NEXTSHARE_FIND_SENDERS_V1';

class NearbyDevice {
  const NearbyDevice({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.platform,
  });

  final String id;
  final String name;
  final InternetAddress address;
  final int port;
  final String platform;
}

class NearbySender {
  const NearbySender({
    required this.id,
    required this.name,
    required this.platform,
    required this.url,
  });

  final String id;
  final String name;
  final String platform;
  final String url;
}

class IncomingTransferOffer {
  const IncomingTransferOffer({
    required this.requestId,
    required this.url,
    required this.senderName,
    required this.fileName,
    required this.fileCount,
    required this.totalBytes,
  });

  final String requestId;
  final String url;
  final String senderName;
  final String fileName;
  final int fileCount;
  final int totalBytes;
}

enum OfferDecision { accepted, declined, timedOut }

class DeviceDiscoveryService {
  DeviceDiscoveryService({String? deviceName})
    : deviceName = deviceName?.trim().isNotEmpty == true
          ? deviceName!.trim()
          : Platform.localHostname;

  final String deviceName;

  static const MethodChannel _networkChannel = MethodChannel(
    'nextshare/network',
  );

  RawDatagramSocket? _receiverSocket;
  StreamSubscription<RawSocketEvent>? _receiverSubscription;
  final Set<String> _handledOfferIds = {};
  bool _multicastLockHeld = false;

  Future<void> startReceiver({
    required Future<bool> Function(IncomingTransferOffer offer) onOffer,
  }) async {
    await stopReceiver();
    await _acquireMulticastLock();
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;
    _receiverSocket = socket;
    _receiverSubscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      final message = utf8.decode(datagram.data, allowMalformed: true);
      if (message == _discoverMessage) {
        final reply = jsonEncode({
          'kind': 'NEXTSHARE_DEVICE_V1',
          'id': '$deviceName-${Platform.operatingSystem}',
          'name': deviceName,
          'platform': Platform.operatingSystem,
        });
        socket.send(utf8.encode(reply), datagram.address, datagram.port);
        return;
      }
      try {
        final payload = jsonDecode(message) as Map<String, dynamic>;
        if (payload['kind'] != 'NEXTSHARE_OFFER_V2') return;
        final requestId = payload['requestId'] as String? ?? '';
        final url = payload['url'] as String? ?? '';
        if (requestId.isEmpty ||
            url.isEmpty ||
            !_handledOfferIds.add(requestId)) {
          return;
        }
        final offer = IncomingTransferOffer(
          requestId: requestId,
          url: url,
          senderName: payload['senderName'] as String? ?? 'Nearby sender',
          fileName: payload['fileName'] as String? ?? 'Files',
          fileCount: (payload['fileCount'] as num?)?.toInt() ?? 0,
          totalBytes: (payload['totalBytes'] as num?)?.toInt() ?? 0,
        );
        unawaited(() async {
          final accepted = await onOffer(offer);
          final reply = jsonEncode({
            'kind': 'NEXTSHARE_OFFER_RESULT_V2',
            'requestId': requestId,
            'accepted': accepted,
          });
          final replyBytes = utf8.encode(reply);
          for (var attempt = 0; attempt < 3; attempt++) {
            socket.send(replyBytes, datagram.address, datagram.port);
            if (attempt < 2) {
              await Future<void>.delayed(const Duration(milliseconds: 150));
            }
          }
        }());
      } catch (_) {}
    });
  }

  Future<void> startSenderAdvertiser(String url) async {
    await stopReceiver();
    await _acquireMulticastLock();
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;
    _receiverSocket = socket;
    _receiverSubscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      final message = utf8.decode(datagram.data, allowMalformed: true);
      if (message != _findSendersMessage) return;
      final reply = jsonEncode({
        'kind': 'NEXTSHARE_SENDER_V1',
        'id': '$deviceName-${Platform.operatingSystem}',
        'name': deviceName,
        'platform': Platform.operatingSystem,
        'url': url,
      });
      socket.send(utf8.encode(reply), datagram.address, datagram.port);
    });
  }

  Future<List<NearbyDevice>> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final devices = <String, NearbyDevice>{};
    final subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      try {
        final payload =
            jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
        if (payload['kind'] != 'NEXTSHARE_DEVICE_V1') return;
        final id = payload['id'] as String? ?? datagram.address.address;
        devices[id] = NearbyDevice(
          id: id,
          name: payload['name'] as String? ?? 'Nearby device',
          address: datagram.address,
          port: datagram.port,
          platform: payload['platform'] as String? ?? 'unknown',
        );
      } catch (_) {}
    });
    final bytes = utf8.encode(_discoverMessage);
    await _sendRepeatedBroadcasts(socket, bytes);
    await Future<void>.delayed(timeout);
    await subscription.cancel();
    socket.close();
    return devices.values.toList(growable: false);
  }

  Future<List<NearbySender>> discoverSenders({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final senders = <String, NearbySender>{};
    final subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      try {
        final payload =
            jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
        if (payload['kind'] != 'NEXTSHARE_SENDER_V1') return;
        final url = payload['url'] as String?;
        if (url == null || url.isEmpty) return;
        final id = payload['id'] as String? ?? datagram.address.address;
        senders[id] = NearbySender(
          id: id,
          name: payload['name'] as String? ?? 'Nearby sender',
          platform: payload['platform'] as String? ?? 'unknown',
          url: url,
        );
      } catch (_) {}
    });
    final bytes = utf8.encode(_findSendersMessage);
    await _sendRepeatedBroadcasts(socket, bytes);
    await Future<void>.delayed(timeout);
    await subscription.cancel();
    socket.close();
    return senders.values.toList(growable: false);
  }

  Future<void> _sendRepeatedBroadcasts(
    RawDatagramSocket socket,
    List<int> bytes,
  ) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      socket.send(bytes, InternetAddress('255.255.255.255'), discoveryPort);
      await _sendSubnetBroadcasts(socket, bytes);
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  }

  Future<void> _sendSubnetBroadcasts(
    RawDatagramSocket socket,
    List<int> bytes,
  ) async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final octets = address.address.split('.');
          if (octets.length != 4) continue;
          socket.send(
            bytes,
            InternetAddress('${octets[0]}.${octets[1]}.${octets[2]}.255'),
            discoveryPort,
          );
        }
      }
    } catch (_) {}
  }

  Future<OfferDecision> sendOffer(
    NearbyDevice device,
    String url, {
    required int fileCount,
    required int totalBytes,
    required String fileName,
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final result = Completer<OfferDecision>();
    final requestId =
        '${DateTime.now().microsecondsSinceEpoch}-${device.id.hashCode}';
    final subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      try {
        final payload =
            jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
        if (payload['kind'] == 'NEXTSHARE_OFFER_RESULT_V2' &&
            payload['requestId'] == requestId &&
            !result.isCompleted) {
          result.complete(
            payload['accepted'] == true
                ? OfferDecision.accepted
                : OfferDecision.declined,
          );
        }
      } catch (_) {}
    });
    final payload = jsonEncode({
      'kind': 'NEXTSHARE_OFFER_V2',
      'requestId': requestId,
      'url': url,
      'senderName': deviceName,
      'fileName': fileName,
      'fileCount': fileCount,
      'totalBytes': totalBytes,
    });
    final payloadBytes = utf8.encode(payload);
    for (var attempt = 0; attempt < 3; attempt++) {
      socket.send(payloadBytes, device.address, device.port);
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    final decision = await result.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => OfferDecision.timedOut,
    );
    await subscription.cancel();
    socket.close();
    return decision;
  }

  Future<void> stopReceiver() async {
    await _receiverSubscription?.cancel();
    _receiverSubscription = null;
    _receiverSocket?.close();
    _receiverSocket = null;
    _handledOfferIds.clear();
    await _releaseMulticastLock();
  }

  Future<void> _acquireMulticastLock() async {
    if (!Platform.isAndroid || _multicastLockHeld) return;
    try {
      _multicastLockHeld =
          await _networkChannel.invokeMethod<bool>('acquireMulticastLock') ??
          false;
    } on MissingPluginException {
      // Nearby discovery can still work on devices that do not filter UDP.
    }
  }

  Future<void> _releaseMulticastLock() async {
    if (!Platform.isAndroid || !_multicastLockHeld) return;
    _multicastLockHeld = false;
    try {
      await _networkChannel.invokeMethod<void>('releaseMulticastLock');
    } on MissingPluginException {
      // The activity may already be shutting down.
    }
  }
}
