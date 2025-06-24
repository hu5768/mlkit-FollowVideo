import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:follow_video/controllers/pose_crop_controller.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

class VideoPoseCrop extends StatelessWidget {
  VideoPoseCrop({super.key});

  final PoseCropController videoController = Get.put(PoseCropController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('crop test')),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: videoController.pickVideo,
              child: const Text('비디오 선택'),
            ),
            ElevatedButton(
              onPressed: videoController.togglePlayPause,
              child: const Text('영상 실행'),
            ),
            Obx(() => Column(
                  children: [
                    LinearProgressIndicator(
                        value: videoController.progressValue.value),
                    const SizedBox(height: 8),
                    Text(videoController.progressLabel.value),
                  ],
                )),
            Obx(() {
              final player = videoController.controller.value;
              if (player != null && player.value.isInitialized) {
                return SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: AspectRatio(
                    aspectRatio: player.value.aspectRatio,
                    child: VideoPlayer(player),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }
}
