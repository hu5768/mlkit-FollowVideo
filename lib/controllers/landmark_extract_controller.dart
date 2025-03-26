import 'package:get/get.dart';

class LandmarkExtractController extends GetxController {
  // RxInt는 반응형 정수입니다.
  var count = 0.obs;

  void increment() {
    count++;
  }
}
