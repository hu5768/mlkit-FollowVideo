import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:follow_video/controllers/video_pose_controller.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';

import '../controllers/landmark.paint.dart';

class VideoPoseDetection extends StatelessWidget {
  VideoPoseDetection({super.key});

  final VideoPoseController videoController = Get.put(VideoPoseController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pose Detection test')),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: videoController.pickVideo,
              child: const Text('비디오 선택'),
            ),
            Obx(() => Text(
                "Frame: ${videoController.currentFrameIndex.value} / ${videoController.poseHistory.length}")),
            Obx(() {
              final player = videoController.controller.value;
              print("🎥 controller: $player");
              if (player != null && player.value.isInitialized) {
                return SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: AspectRatio(
                    aspectRatio: player.value.aspectRatio,
                    child: Stack(
                      children: [
                        VideoPlayer(player),
                        CustomPaint(
                          painter: PosePainter(
                            videoController.poseHistory.isEmpty
                                ? []
                                : videoController.poseHistory[
                                    videoController.currentFrameIndex.value],
                            player.value.size,
                          ),
                          child: Container(),
                        ),
                      ],
                    ),
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
