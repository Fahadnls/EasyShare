import 'dart:async';

import 'package:get/get.dart';

import '../../../routes/app_pages.dart';

class SplashController extends GetxController {
  Timer? _timer;

  @override
  void onReady() {
    super.onReady();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      Get.offAllNamed(Routes.HOME);
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
