import 'package:flutter/material.dart';
import 'package:follow_video/controllers/video_crop_controller.dart';
import 'package:follow_video/views/mene_page.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final videoController = Get.find<VideoCropController>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MenePage()),
                (route) => false, // 스택의 모든 route 제거
              );
            }),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 16),
          // 비디오 뷰
          Obx(() {
            final controller = videoController.controller.value;
            if (controller == null) {
              return const Center(child: Text('영상이 없습니다.'));
            }

            return SizedBox(
              width: MediaQuery.of(context).size.width * 0.4,
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            );
          }),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: videoController.togglePlayPause,
            child: const Text('영상 실행'),
          ),
          // 버튼 영역
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      videoController
                          .saveVideoToGallery(videoController.outputPath.value);
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('앨범에 저장하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B3BFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const MenePage()),
                        (route) => false, // 스택의 모든 route 제거
                      );
                    },
                    icon: const Icon(Icons.open_in_full),
                    label: const Text('새 영상 제작하기'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5B3BFF),
                      side: const BorderSide(color: Color(0xFF5B3BFF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
