import 'package:get/get.dart';

class OptionController extends GetxController {
  var selectedRatio = '9:16'.obs;
  var cropOption = 'custom'.obs; // 'auto' 또는 'custom'
  var cropSize = 70.0.obs;
  var smoothness = 'medium'.obs; // 'low', 'medium', 'high'

  void setRatio(String ratio) => selectedRatio.value = ratio;
  void setCropOption(String option) => cropOption.value = option;
  void setCropSize(double value) => cropSize.value = value;
  void setSmoothness(String value) => smoothness.value = value;

  int get smoothingWindowSize {
    switch (smoothness.value) {
      case 'low':
        return 3;
      case 'medium':
        return 5;
      case 'high':
        return 10;
      default:
        return 5;
    }
  }
}
