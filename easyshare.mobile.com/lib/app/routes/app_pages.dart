import 'package:get/get.dart';

import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/share/bindings/share_binding.dart';
import '../modules/share/views/share_view.dart';
import '../modules/transfer/bindings/transfer_receive_binding.dart';
import '../modules/transfer/bindings/transfer_send_binding.dart';
import '../modules/transfer/views/transfer_receive_view.dart';
import '../modules/transfer/views/transfer_send_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.HOME;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.SHARE,
      page: () => const ChatView(),
      binding: ShareBinding(),
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
  ];
}
