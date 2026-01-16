import 'package:get/get.dart';

import '../controllers/transfer_send_controller.dart';

class TransferSendBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TransferSendController>(() => TransferSendController());
  }
}
