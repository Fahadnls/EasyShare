import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/service/app_storage_service.dart';
import '../../../data/service/platform_file_service.dart';

class SettingsController extends GetxController {
  final AppStorageService storage = Get.find<AppStorageService>();
  final isPicking = false.obs;
  final statusText = ''.obs;

  Future<void> changeThemeMode(String mode) async {
    await storage.setThemeMode(mode);
    Get.changeThemeMode(switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    });
  }

  Future<void> chooseSaveLocation() async {
    if (isPicking.value) return;
    isPicking.value = true;
    statusText.value = '';
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose default save location',
      );
      if (path == null) return;
      final directory = Directory(path);
      if (!await directory.exists()) {
        statusText.value = 'The selected folder is not accessible.';
        return;
      }
      final accessSaved = await PlatformFileService.persistFolderAccess(path);
      if (!accessSaved) {
        statusText.value =
            'This folder is available now, but access may need to be renewed later.';
      }
      await storage.setDefaultSaveLocation(path);
      if (accessSaved) statusText.value = 'Default save location updated.';
    } catch (_) {
      statusText.value = Platform.isIOS
          ? 'iOS limits persistent access to folders outside the app.'
          : 'This folder could not be selected. Check file access permission.';
    } finally {
      isPicking.value = false;
    }
  }

  Future<void> useSystemDefault() async {
    await storage.clearDefaultSaveLocation();
    statusText.value = 'System default restored.';
  }
}
