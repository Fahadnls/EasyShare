// ignore_for_file: constant_identifier_names

import 'package:get/get.dart';

import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/apps/bindings/apps_binding.dart';
import '../modules/apps/views/apps_view.dart';
import '../modules/history/bindings/history_binding.dart';
import '../modules/history/views/history_view.dart';
import '../modules/settings/bindings/settings_binding.dart';
import '../modules/settings/views/settings_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/transfer/bindings/transfer_receive_binding.dart';
import '../modules/transfer/bindings/transfer_send_binding.dart';
import '../modules/transfer/views/transfer_receive_view.dart';
import '../modules/transfer/views/transfer_send_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.TRANSFER_SEND,
      page: () => const TransferSendView(),
      binding: TransferSendBinding(),
    ),
    GetPage(
      name: _Paths.TRANSFER_RECEIVE,
      page: () => const TransferReceiveView(),
      binding: TransferReceiveBinding(),
    ),
    GetPage(
      name: _Paths.TRANSFER_HISTORY,
      page: () => const HistoryView(),
      binding: HistoryBinding(),
    ),
    GetPage(
      name: _Paths.SETTINGS,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: _Paths.SEND_APPS,
      page: () => const AppsView(),
      binding: AppsBinding(),
    ),
  ];
}
