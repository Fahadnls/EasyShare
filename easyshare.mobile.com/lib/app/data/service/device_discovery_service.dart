import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

class DeviceDiscoveryService {
  RawDatagramSocket? _receiverSocket;
  StreamSubscription<RawSocketEvent>? _receiverSubscription;

  Future<void> startReceiver({
    required void Function(String offer) onOffer,
  }) async {
    await stopReceiver();
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
          'id': '${Platform.localHostname}-${Platform.operatingSystem}',
          'name': Platform.localHostname,
          'platform': Platform.operatingSystem,
        });
        socket.send(utf8.encode(reply), datagram.address, datagram.port);
        return;
      }
      try {
        final payload = jsonDecode(message) as Map<String, dynamic>;
        if (payload['kind'] == 'NEXTSHARE_OFFER_V1') {
          final offer = payload['url'] as String?;
          if (offer != null && offer.isNotEmpty) {
            socket.send(
              utf8.encode(jsonEncode({'kind': 'NEXTSHARE_ACK_V1'})),
              datagram.address,
              datagram.port,
            );
            onOffer(offer);
          }
        }
      } catch (_) {}
    });
  }

  Future<void> startSenderAdvertiser(String url) async {
    await stopReceiver();
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
        'id': '${Platform.localHostname}-${Platform.operatingSystem}',
        'name': Platform.localHostname,
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
    socket.send(bytes, InternetAddress('255.255.255.255'), discoveryPort);
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final octets = address.address.split('.');
          if (octets.length != 4) continue;
          final broadcast = InternetAddress(
            '${octets[0]}.${octets[1]}.${octets[2]}.255',
          );
          socket.send(bytes, broadcast, discoveryPort);
        }
      }
    } catch (_) {}
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
    socket.send(bytes, InternetAddress('255.255.255.255'), discoveryPort);
    await _sendSubnetBroadcasts(socket, bytes);
    await Future<void>.delayed(timeout);
    await subscription.cancel();
    socket.close();
    return senders.values.toList(growable: false);
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

  Future<bool> sendOffer(NearbyDevice device, String url) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final acknowledged = Completer<bool>();
    final subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      try {
        final payload =
            jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
        if (payload['kind'] == 'NEXTSHARE_ACK_V1' &&
            !acknowledged.isCompleted) {
          acknowledged.complete(true);
        }
      } catch (_) {}
    });
    final payload = jsonEncode({'kind': 'NEXTSHARE_OFFER_V1', 'url': url});
    socket.send(utf8.encode(payload), device.address, device.port);
    final result = await acknowledged.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => false,
    );
    await subscription.cancel();
    socket.close();
    return result;
  }

  Future<void> stopReceiver() async {
    await _receiverSubscription?.cancel();
    _receiverSubscription = null;
    _receiverSocket?.close();
    _receiverSocket = null;
  }
}
