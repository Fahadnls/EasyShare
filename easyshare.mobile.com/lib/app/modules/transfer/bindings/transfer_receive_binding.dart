import 'package:get/get.dart';

import '../controllers/transfer_receive_controller.dart';

class TransferReceiveBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TransferReceiveController>(() => TransferReceiveController());
  }
}
