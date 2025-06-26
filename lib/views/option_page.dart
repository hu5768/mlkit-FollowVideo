import 'package:flutter/material.dart';
import 'package:follow_video/controllers/option_controller.dart';
import 'package:follow_video/controllers/video_crop_controller.dart';
import 'package:follow_video/views/loading_page.dart';
import 'package:get/get.dart';

class OptionPage extends StatelessWidget {
  const OptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final optionController = Get.put(OptionController());
    final videoCropController = Get.put(VideoCropController());
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('옵션'),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 54),
              child: Obx(() => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('화면 비율',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.normal)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          {'label': '3:4', 'w': 3.0, 'h': 4.0},
                          {'label': '4:5', 'w': 4.0, 'h': 5.0},
                          {'label': '9:16', 'w': 9.0, 'h': 16.0},
                        ].map((r) {
                          final label = r['label']! as String;
                          final w = r['w']! as double;
                          final h = r['h']! as double;
                          final selected =
                              optionController.selectedRatio.value == label;

                          const double maxInnerHeight = 80;
                          const innerHeight = maxInnerHeight;
                          final innerWidth = innerHeight * (w / h);

                          return Expanded(
                            child: GestureDetector(
                              onTap: () => optionController.setRatio(label),
                              child: Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: Container(
                                  height: 110,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF5B3BFF)
                                          : Colors.grey.shade300,
                                      width: selected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: innerWidth,
                                        height: innerHeight,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(0xFF5B3BFF)
                                              : Colors.grey.shade300,
                                          borderRadius:
                                              BorderRadius.circular(0),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            color: selected
                                                ? Colors.white
                                                : Colors.black54,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 40),
                      const Text('크롭 사이즈 옵션',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.normal)),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          _radio(optionController, '자동', 'auto',
                              group: optionController.cropOption),
                          Column(
                            children: [
                              _radio(optionController, '사이즈 지정', 'custom',
                                  group: optionController.cropOption),
                              const SizedBox(width: 8),
                              if (optionController.cropOption.value == 'custom')
                                Row(
                                  children: [
                                    Expanded(
                                      child: Slider(
                                        value: optionController.cropSize.value,
                                        min: 10,
                                        max: 90,
                                        divisions: 16, // 5% 단위로
                                        activeColor: const Color.fromARGB(
                                            255, 213, 213, 213),
                                        onChanged: (value) {
                                          optionController.setCropSize(value);
                                        },
                                      ),
                                    ),
                                    SizedBox(
                                      width: 50,
                                      child: Text(
                                        '${optionController.cropSize.value.toStringAsFixed(0)}%',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                )
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('카메라 부드러움',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.normal)),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          _radio(optionController, '낮음', 'low',
                              group: optionController.smoothness),
                          _radio(optionController, '보통', 'medium',
                              group: optionController.smoothness),
                          _radio(optionController, '높음', 'high',
                              group: optionController.smoothness),
                        ],
                      ),
                      const SizedBox(height: 51),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LoadingPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B3BFF),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('생성하기',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )),
            ),
          ),
        ));
  }

  Widget _radio(OptionController controller, String label, String value,
      {required RxString group}) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Radio<String>(
            value: value,
            groupValue: group.value,
            activeColor: const Color(0xFF5B3BFF),
            onChanged: (val) => group.value = val!,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
