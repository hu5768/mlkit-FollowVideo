import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<PoseLandmark> currentPose;
  final Size imageSize;
  PosePainter(this.currentPose, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0)
      return; // 비디오 크기가 0이면 그리지 않음

    final scaleX = size.width / imageSize.width; // 가로 비율
    final scaleY = size.height / imageSize.height; // 세로 비율

    final paint = Paint()
      ..color = const Color.fromARGB(255, 243, 33, 33) // 점 색상
      ..strokeWidth = 4.0
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.blue // 선 색상
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    Map<PoseLandmarkType, Offset> landmarks = {};
    canvas.drawCircle(const Offset(0, 0), 2, paint);
    canvas.drawCircle(Offset(size.width, size.height), 2, paint);
    // 🎯 랜드마크 좌표 변환하여 저장
    for (var landmark in currentPose) {
      final Offset point = Offset(landmark.x * scaleX, landmark.y * scaleY);
      landmarks[landmark.type] = point;
      canvas.drawCircle(point, 4, paint);
    }

    // 🎯 관절 연결 (선 그리기)
    void drawLine(PoseLandmarkType start, PoseLandmarkType end) {
      if (landmarks.containsKey(start) && landmarks.containsKey(end)) {
        canvas.drawLine(landmarks[start]!, landmarks[end]!, linePaint);
      }
    }

    // 🦾 팔 연결
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);

    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    // 🦵 다리 연결
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);

    drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

    // 🏋️‍♂️ 상체 연결
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
    drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.currentPose != currentPose ||
        oldDelegate.imageSize != imageSize;
  }
}
