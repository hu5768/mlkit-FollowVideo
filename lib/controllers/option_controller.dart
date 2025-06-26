import 'package:get/get.dart';

class OptionController extends GetxController {
  var selectedRatio = '9:16'.obs;
  var cropOption = 'auto'.obs; // 'auto' 또는 'custom'
  var cropSize = 70.0.obs;
  var smoothness = 'low'.obs; // 'low', 'medium', 'high'

  void setRatio(String ratio) => selectedRatio.value = ratio;
  void setCropOption(String option) => cropOption.value = option;
  void setCropSize(double value) => cropSize.value = value;
  void setSmoothness(String value) => smoothness.value = value;
}
