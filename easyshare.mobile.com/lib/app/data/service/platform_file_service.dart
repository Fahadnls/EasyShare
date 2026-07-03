import 'dart:io';

import 'package:flutter/services.dart';

class SharedAppInfo {
  const SharedAppInfo({
    required this.name,
    required this.packageName,
    required this.apkPath,
    required this.size,
    this.icon,
  });

  final String name;
  final String packageName;
  final String apkPath;
  final int size;
  final Uint8List? icon;

  factory SharedAppInfo.fromMap(Map<dynamic, dynamic> map) {
    return SharedAppInfo(
      name: map['name'] as String? ?? 'App',
      packageName: map['packageName'] as String? ?? '',
      apkPath: map['apkPath'] as String? ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
      icon: map['icon'] as Uint8List?,
    );
  }
}

class PickedFolderFile {
  const PickedFolderFile({
    required this.path,
    required this.relativePath,
    required this.size,
  });

  final String path;
  final String relativePath;
  final int size;

  factory PickedFolderFile.fromMap(Map<dynamic, dynamic> map) {
    return PickedFolderFile(
      path: map['path'] as String? ?? '',
      relativePath: map['relativePath'] as String? ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlatformFileService {
  static const MethodChannel _channel = MethodChannel(
    'nextshare/platform_files',
  );

  static Future<List<SharedAppInfo>> installedApps() async {
    if (!Platform.isAndroid) return const [];
    final result = await _channel.invokeMethod<List<dynamic>>('installedApps');
    return (result ?? const [])
        .whereType<Map>()
        .map(SharedAppInfo.fromMap)
        .where((app) => app.apkPath.isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<PickedFolderFile>?> pickAndroidFolder() async {
    if (!Platform.isAndroid) return null;
    final result = await _channel.invokeMethod<List<dynamic>>('pickFolder');
    if (result == null) return null;
    return result
        .whereType<Map>()
        .map(PickedFolderFile.fromMap)
        .where((file) => file.path.isNotEmpty && file.relativePath.isNotEmpty)
        .toList(growable: false);
  }

  static Future<bool> openPath(String path) async {
    if (path.isEmpty) return false;
    if (Platform.isWindows) {
      return (await Process.run('explorer', [path])).exitCode == 0;
    }
    if (Platform.isLinux) {
      return (await Process.run('xdg-open', [path])).exitCode == 0;
    }
    try {
      return await _channel.invokeMethod<bool>('openPath', {'path': path}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> persistFolderAccess(String path) async {
    if (!Platform.isMacOS) return true;
    try {
      return await _channel.invokeMethod<bool>('persistFolderAccess', {
            'path': path,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> restoreFolderAccess() async {
    if (!Platform.isMacOS) return null;
    try {
      return await _channel.invokeMethod<String>('restoreFolderAccess');
    } catch (_) {
      return null;
    }
  }
}
