import 'dart:io';

import 'package:get/get.dart';

import '../../../data/model/transfer_history_item.dart';
import '../../../data/service/app_storage_service.dart';
import '../../../data/service/platform_file_service.dart';
import '../../../routes/app_pages.dart';

class HistoryController extends GetxController {
  final AppStorageService storage = Get.find<AppStorageService>();

  Future<void> deleteItem(TransferHistoryItem item) {
    return storage.removeHistory(item.id);
  }

  Future<void> clearHistory() => storage.clearHistory();

  Future<void> openFile(TransferHistoryItem item) async {
    final opened = await PlatformFileService.openPath(item.location);
    if (!opened) {
      Get.snackbar('Cannot open file', 'The file is unavailable or was moved.');
    }
  }

  Future<void> openFolder(TransferHistoryItem item) async {
    var path = item.location;
    if (!path.startsWith('content://')) {
      path = File(path).parent.path;
    }
    final opened = await PlatformFileService.openPath(path);
    if (!opened) {
      Get.snackbar(
        'Cannot open folder',
        'This platform does not expose that save location.',
      );
    }
  }

  void shareAgain(TransferHistoryItem item) {
    final path = item.sourcePath ?? item.location;
    if (path.startsWith('content://')) {
      Get.snackbar(
        'Select the file again',
        'Android storage access does not expose a reusable file path.',
      );
      return;
    }
    Get.toNamed(
      Routes.TRANSFER_SEND,
      arguments: {
        'paths': [path],
      },
    );
  }
}
