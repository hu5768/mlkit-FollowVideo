import 'package:flutter/material.dart';
import 'package:follow_video/controllers/video_crop_controller.dart';
import 'package:follow_video/views/option_page.dart';
import 'package:get/get.dart';

class MenePage extends StatelessWidget {
  const MenePage({super.key});

  @override
  Widget build(BuildContext context) {
    final VideoCropController videoController = Get.put(VideoCropController());
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1FB),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 132),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(),
            Center(
              child: Image.asset(
                'assets/icon/logo_icon.png',
                width: 150,
              ),
            ),
            ElevatedButton(
                onPressed: () async {
                  await videoController.reset();
                  final picked = await videoController.pickVideo();
                  if (picked) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const OptionPage()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B3BFF), // 버튼 보라색
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    '영상 선택',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ))
          ],
        ),
      ),
    );
  }
}
