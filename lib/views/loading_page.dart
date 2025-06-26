import 'package:flutter/material.dart';
import 'package:follow_video/controllers/video_crop_controller.dart';
import 'package:follow_video/views/result_page.dart';
import 'package:get/get.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({super.key});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  final videoCropController = Get.put(VideoCropController());
  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  Future<void> _startProcessing() async {
    await videoCropController.makeVideo();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ResultPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 배경 이미지
          Positioned.fill(
            child: Image.asset(
              'assets/images/loading_background.png',
              fit: BoxFit.cover,
            ),
          ),
          // 메인 콘텐츠
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 로고 텍스트
                Center(
                  child: Image.asset(
                    'assets/icon/logo_icon.png',
                    width: 150,
                  ),
                ),

                const SizedBox(height: 40),
                // 로딩바 (Obx)
                Obx(() => Column(
                      children: [
                        SizedBox(
                          width: 240,
                          child: LinearProgressIndicator(
                            value: videoCropController.progressValue.value,
                            backgroundColor: Colors.grey.shade300,
                            color: const Color(0xFF5B3BFF),
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          videoCropController.progressLabel.value,
                          style: const TextStyle(fontSize: 16),
                        )
                      ],
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
