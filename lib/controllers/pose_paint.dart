import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;

  PosePainter(this.poses, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint pointPaint = Paint()
      ..color = Colors.red // 포인트 색상
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;

    final Paint linePaint = Paint()
      ..color = Colors.blue // 선 색상
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var pose in poses) {
      final double scaleX = size.width / imageSize.width;
      final double scaleY = size.height / imageSize.height;

      // 랜드마크 가져오기
      Map<PoseLandmarkType, PoseLandmark> landmarks = pose.landmarks;

      // 특정 포인트 가져오기
      Offset? getLandmarkPosition(PoseLandmarkType type) {
        if (landmarks.containsKey(type)) {
          final landmark = landmarks[type]!;
          return Offset(landmark.x * scaleX, landmark.y * scaleY);
        }
        return null;
      }

// 랜드마크 위치 가져오기
      final wristLeft = getLandmarkPosition(PoseLandmarkType.leftWrist);
      final elbowLeft = getLandmarkPosition(PoseLandmarkType.leftElbow);
      final shoulderLeft = getLandmarkPosition(PoseLandmarkType.leftShoulder);
      final hipLeft = getLandmarkPosition(PoseLandmarkType.leftHip);
      final kneeLeft = getLandmarkPosition(PoseLandmarkType.leftKnee);
      final ankleLeft = getLandmarkPosition(PoseLandmarkType.leftAnkle);

      final wristRight = getLandmarkPosition(PoseLandmarkType.rightWrist);
      final elbowRight = getLandmarkPosition(PoseLandmarkType.rightElbow);
      final shoulderRight = getLandmarkPosition(PoseLandmarkType.rightShoulder);
      final hipRight = getLandmarkPosition(PoseLandmarkType.rightHip);
      final kneeRight = getLandmarkPosition(PoseLandmarkType.rightKnee);
      final ankleRight = getLandmarkPosition(PoseLandmarkType.rightAnkle);

      // 랜드마크 연결 (팔)
      drawLine(canvas, linePaint, wristLeft, elbowLeft);
      drawLine(canvas, linePaint, elbowLeft, shoulderLeft);

      drawLine(canvas, linePaint, wristRight, elbowRight);
      drawLine(canvas, linePaint, elbowRight, shoulderRight);

      // 어깨 연결
      drawLine(canvas, linePaint, shoulderLeft, shoulderRight);

      // 상체 & 하체 연결
      drawLine(canvas, linePaint, shoulderLeft, hipLeft);
      drawLine(canvas, linePaint, shoulderRight, hipRight);

      // 하체 연결
      drawLine(canvas, linePaint, hipLeft, kneeLeft);
      drawLine(canvas, linePaint, kneeLeft, ankleLeft);

      drawLine(canvas, linePaint, hipRight, kneeRight);
      drawLine(canvas, linePaint, kneeRight, ankleRight);

      // 랜드마크 점 그리기
      for (var landmark in landmarks.values) {
        final x = landmark.x * scaleX;
        final y = landmark.y * scaleY;
        canvas.drawCircle(Offset(x, y), 5, pointPaint);
      }
    }
  }

  // 선을 그리는 함수 (두 점이 모두 존재할 때만)
  void drawLine(Canvas canvas, Paint paint, Offset? p1, Offset? p2) {
    if (p1 != null && p2 != null) {
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) => true;
}
