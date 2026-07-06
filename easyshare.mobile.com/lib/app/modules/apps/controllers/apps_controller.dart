import 'dart:io';

import 'package:get/get.dart';

import '../../../data/service/platform_file_service.dart';

class AppsController extends GetxController {
  final apps = <SharedAppInfo>[].obs;
  final selectedPackages = <String>{}.obs;
  final isLoading = false.obs;
  final isPreparing = false.obs;
  final errorText = ''.obs;

  bool get isSupported => Platform.isAndroid;

  @override
  void onInit() {
    super.onInit();
    if (isSupported) loadApps();
  }

  Future<void> loadApps() async {
    if (!isSupported || isLoading.value) return;
    isLoading.value = true;
    errorText.value = '';
    try {
      apps.assignAll(await PlatformFileService.installedApps());
      apps.sort(
        (first, second) =>
            first.name.toLowerCase().compareTo(second.name.toLowerCase()),
      );
      if (apps.isEmpty) {
        errorText.value = 'No shareable app packages were found.';
      }
    } catch (_) {
      errorText.value =
          'Installed apps could not be read on this Android device.';
    } finally {
      isLoading.value = false;
    }
  }

  void toggle(SharedAppInfo app) {
    if (!selectedPackages.add(app.packageName)) {
      selectedPackages.remove(app.packageName);
    }
    selectedPackages.refresh();
  }

  Future<void> sendSelected() async {
    final selectedApps = apps
        .where((app) => selectedPackages.contains(app.packageName))
        .toList(growable: false);
    if (selectedApps.isEmpty) {
      Get.snackbar('Choose an app', 'Select at least one app to send.');
      return;
    }
    isPreparing.value = true;
    errorText.value = '';
    try {
      final prepared = await PlatformFileService.prepareApps(
        selectedApps.map((app) => app.packageName),
      );
      if (prepared.isEmpty) {
        errorText.value = 'The selected app packages could not be prepared.';
        Get.snackbar('App export failed', errorText.value);
        return;
      }
      Get.back(result: prepared);
    } catch (error) {
      errorText.value = 'Could not prepare the selected apps: $error';
      Get.snackbar('App export failed', errorText.value);
    } finally {
      isPreparing.value = false;
    }
  }
}
