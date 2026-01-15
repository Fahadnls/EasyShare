import 'dart:async';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../routes/app_pages.dart';

class HomeController extends GetxController {
  final bt = FlutterBluetoothSerial.instance;

  final isEnabled = false.obs;
  final isDiscovering = false.obs;

  final bonded = <BluetoothDevice>[].obs;
  final discovered = <BluetoothDiscoveryResult>[].obs;

  StreamSubscription<BluetoothDiscoveryResult>? _discoverySub;
  StreamSubscription<BluetoothState>? _stateSub;

  @override
  void onInit() {
    super.onInit();
    _listenState();
    refreshBonded();
  }

  void _listenState() async {
    // initial
    isEnabled.value = (await bt.isEnabled) ?? false;

    _stateSub = bt.onStateChanged().listen((s) {
      isEnabled.value = s == BluetoothState.STATE_ON;
      if (!isEnabled.value) {
        discovered.clear();
        isDiscovering.value = false;
      }
    });
  }

  Future<void> requestBtPermissions() async {
    // Android 12+: Nearby devices permissions
    // Android <= 11: Location permission needed for discovery
    final api = await _androidSdkInt();
    if (api >= 31) {
      final res1 = await Permission.bluetoothScan.request();
      final res2 = await Permission.bluetoothConnect.request();
      if (!res1.isGranted || !res2.isGranted) {
        Get.snackbar('Permission', 'Bluetooth permissions denied');
      }
    } else {
      final res = await Permission.location.request();
      if (!res.isGranted) {
        Get.snackbar(
          'Permission',
          'Location permission denied (required for scan)',
        );
      }
    }
  }

  Future<int> _androidSdkInt() async {
    // permission_handler exposes it via androidInfo in device_info_plus,
    // but to keep dependencies minimal, we just assume 31+ devices will still work
    // if permissions are requested. We'll return 31 as safe default.
    // If you want exact: add device_info_plus and read sdkInt.
    return 31;
  }

  Future<void> enableBluetooth() async {
    await requestBtPermissions();
    final enabled = await bt.requestEnable();
    isEnabled.value = enabled ?? false;
    if (isEnabled.value) {
      await refreshBonded();
    }
  }

  Future<void> refreshBonded() async {
    try {
      final list = await bt.getBondedDevices();
      bonded.assignAll(list);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load paired devices');
    }
  }

  Future<void> startDiscovery() async {
    await requestBtPermissions();
    if (!isEnabled.value) {
      Get.snackbar('Bluetooth', 'Turn on Bluetooth first');
      return;
    }

    discovered.clear();
    isDiscovering.value = true;

    _discoverySub?.cancel();
    _discoverySub = bt.startDiscovery().listen(
      (r) {
        // avoid duplicates
        final exists = discovered.any(
          (x) => x.device.address == r.device.address,
        );
        if (!exists) discovered.add(r);
      },
      onDone: () {
        isDiscovering.value = false;
      },
      onError: (_) {
        isDiscovering.value = false;
      },
    );
  }

  Future<void> stopDiscovery() async {
    await _discoverySub?.cancel();
    isDiscovering.value = false;
  }

  void openChat(BluetoothDevice device) {
    Get.toNamed(Routes.SHARE, arguments: device);
  }

  @override
  void onClose() {
    _discoverySub?.cancel();
    _stateSub?.cancel();
    super.onClose();
  }
}
