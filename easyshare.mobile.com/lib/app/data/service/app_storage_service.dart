import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../model/transfer_history_item.dart';

class AppStorageService extends GetxService {
  final history = <TransferHistoryItem>[].obs;
  final defaultSaveLocation = ''.obs;

  late final File _dataFile;

  Future<AppStorageService> init() async {
    final support = await getApplicationSupportDirectory();
    await support.create(recursive: true);
    _dataFile = File(p.join(support.path, 'nextshare_data.json'));
    await _load();
    return this;
  }

  Future<void> _load() async {
    if (!await _dataFile.exists()) return;
    try {
      final data =
          jsonDecode(await _dataFile.readAsString()) as Map<String, dynamic>;
      defaultSaveLocation.value = data['defaultSaveLocation'] as String? ?? '';
      final storedHistory = data['history'] as List? ?? const [];
      history.assignAll(
        storedHistory.whereType<Map>().map(
          (item) =>
              TransferHistoryItem.fromJson(Map<String, dynamic>.from(item)),
        ),
      );
    } catch (_) {
      // A damaged preferences file should not prevent the app from opening.
    }
  }

  Future<void> setDefaultSaveLocation(String path) async {
    defaultSaveLocation.value = path;
    await _save();
  }

  Future<void> clearDefaultSaveLocation() async {
    defaultSaveLocation.value = '';
    await _save();
  }

  Future<void> addHistory(TransferHistoryItem item) async {
    history.removeWhere((existing) => existing.id == item.id);
    history.insert(0, item);
    if (history.length > 250) {
      history.removeRange(250, history.length);
    }
    await _save();
  }

  Future<void> removeHistory(String id) async {
    history.removeWhere((item) => item.id == id);
    await _save();
  }

  Future<void> clearHistory() async {
    history.clear();
    await _save();
  }

  Future<void> _save() async {
    final payload = jsonEncode({
      'defaultSaveLocation': defaultSaveLocation.value,
      'history': history.map((item) => item.toJson()).toList(),
    });
    final temp = File('${_dataFile.path}.tmp');
    await temp.writeAsString(payload, flush: true);
    await temp.rename(_dataFile.path);
  }
}
