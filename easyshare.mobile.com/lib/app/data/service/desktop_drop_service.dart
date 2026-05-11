import 'dart:async';

import 'package:flutter/services.dart';

class DesktopDropService {
  static const EventChannel _eventChannel = EventChannel(
    'easyshare.desktop_drop/events',
  );

  static Stream<List<String>> fileDrops() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is! List) return const <String>[];
      return event.whereType<String>().toList(growable: false);
    });
  }
}
