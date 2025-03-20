import 'package:flutter/material.dart';
import 'package:follow_video/views/camera_pose_detection.dart';
import 'package:follow_video/views/video_pose_detection.dart';

class MenePage extends StatelessWidget {
  const MenePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Row(
              children: [
                Column(
                  children: [
                    const Text("camera"),
                    OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const PoseDetectionScreen()),
                          );
                        },
                        child: const Icon(Icons.camera_alt)),
                  ],
                ),
                Column(
                  children: [
                    const Text("camera"),
                    OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const VideoPoseDetection()),
                          );
                        },
                        child: const Icon(Icons.camera_alt)),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
