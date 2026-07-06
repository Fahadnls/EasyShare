import 'dart:io';

import 'package:easyshare/app/data/service/device_discovery_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easyshare/main.dart';
import 'package:easyshare/app/data/service/app_storage_service.dart';
import 'package:easyshare/app/modules/transfer/controllers/transfer_send_controller.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.put<AppStorageService>(AppStorageService(), permanent: true);
  });

  tearDown(() => Get.reset());

  testWidgets('shows file-sharing actions on the home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text('Next Share'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
    expect(find.byTooltip('Transfer history'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.textContaining('Fast local transfer'), findsNothing);
    expect(find.text('DISCOVER'), findsNothing);
  });

  testWidgets('send opens the file type selection step', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.text('What do you want to send?'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Folder'), findsOneWidget);
  });

  testWidgets('send search reacts to QR and nearby device state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    final controller = Get.find<TransferSendController>();
    controller.files.add(
      const SendFileItem(
        id: 'test',
        name: 'photo.jpg',
        path: '/tmp/photo.jpg',
        relativePath: 'photo.jpg',
        size: 1024,
      ),
    );
    await tester.pump();

    controller.serverUrl.value = 'http://192.168.1.2:8080/meta?token=test';
    controller.nearbyDevices.add(
      NearbyDevice(
        id: 'phone',
        name: 'Nearby phone',
        address: InternetAddress.loopbackIPv4,
        port: 45873,
        platform: 'android',
      ),
    );
    await tester.pump();

    final qrButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.qr_code_rounded),
    );
    expect(qrButton.onPressed, isNotNull);
    expect(find.text('Nearby phone'), findsOneWidget);
  });
}
