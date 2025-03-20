import 'dart:io';

import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';

class VideoPoseDetection extends StatefulWidget {
  const VideoPoseDetection({super.key});

  @override
  State<VideoPoseDetection> createState() => _VideoPoseDetectionState();
}

class _VideoPoseDetectionState extends State<VideoPoseDetection> {
  VideoPlayerController? _controller;
  String? _videoPath;
  final List<List<PoseLandmark>> _poseHistory = [];

  int _currentFrameIndex = 0;
  String? imagePath;
  void _updatePoseHistory() {
    final currentFrame =
        (_controller!.value.position.inMilliseconds / 1000).round();
    print("프레임 : $currentFrame");
    if (_poseHistory.isNotEmpty) {
      print("포즈배열 크기: ${_poseHistory.length}");

      if (currentFrame < _poseHistory.length) {
        _currentFrameIndex = currentFrame;
      }

      setState(() {});
    }
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );
    if (_controller != null) {
      _controller!.removeListener(_updatePoseHistory); // 기존 리스너 제거 (중복 방지)
    }
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _videoPath = result.files.single.path!;
        _controller = VideoPlayerController.file(File(_videoPath!))
          ..initialize().then((_) {
            _controller!.setLooping(true);
            _controller!.play();
            _controller!.addListener(_updatePoseHistory);
            setState(() {});
          });
      });

      await _deletePreviousImages();
      _processVideo();
    }
  }

  Future<void> _deletePreviousImages() async {
    final directory = await getTemporaryDirectory();
    final List<FileSystemEntity> files = directory.listSync();

    for (var file in files) {
      if (file is File && file.path.endsWith('.jpg')) {
        await file.delete();
      }
    }
    print("✅ 이전 이미지 파일 삭제 완료");
  }

  Future<String> _copyVideoToDocuments(String videoPath) async {
    final directory = await getApplicationDocumentsDirectory(); // 📂 영구 저장 디렉토리
    final newPath = '${directory.path}/${videoPath.split('/').last}'; // 새 파일 경로
    final newFile = File(newPath);

    // 🎯 이미 존재하면 복사 안 함
    if (!await newFile.exists()) {
      await File(videoPath).copy(newPath);
      print("✅ 비디오 파일 복사 완료: $newPath");
    } else {
      print("📂 비디오 파일이 이미 존재함: $newPath");
    }

    return newPath; // 복사된 새 비디오 경로 반환
  }

  Future<void> _processVideo() async {
    final poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );

    int videoDuration = _controller!.value.duration.inMilliseconds;
    // 비디오 프레임별 포즈 감지 (프레임을 이미지로 변환해야 함)
    for (int i = 0; i < 2000; i += 100) {
      // 10프레임 간격으로 처리
      final frameImage = await _getFrameAt(i);
      if (frameImage == null) continue;

      print('프레임 $i 처리');
      final inputImage = InputImage.fromFile(frameImage);
      final poses = await poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        _poseHistory.add(poses.first.landmarks.values.toList());
        //print("코의 좌표: ${poses.first.landmarks[PoseLandmarkType.nose]?.x}");

        setState(() {});
      }
    }

    await poseDetector.close();
  }

  Future<File?> _getFrameAt(int milliseconds) async {
    try {
      // 앱의 임시 디렉토리 가져오기
      final directory = await getTemporaryDirectory();
      final outputPath = '${directory.path}/frame_$milliseconds.jpg';

      print(_videoPath);
      // FFmpeg 명령어 실행 (비디오에서 특정 시간의 프레임 추출)
      String command =
          '-i "$_videoPath" -ss ${milliseconds / 1000} -vframes 1 "$outputPath"';

      await FFmpegKit.execute(command).then((session) async {
        final returnCode = await session.getReturnCode();
        // ✅ 널 체크 후 정적 메서드 사용
        if (returnCode != null && ReturnCode.isSuccess(returnCode)) {
          print("✅ 프레임 추출 성공: $outputPath");
        } else {
          print("❌ FFmpeg 실행 실패, 코드: $returnCode");
        }
      });
      setState(() {
        imagePath = outputPath;
      });
      return File(outputPath); // 추출된 프레임 파일 반환
    } catch (e) {
      print("⚠️ 프레임 추출 오류: $e");
      return null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비디오 선택 & 재생')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickVideo,
            child: const Text('비디오 선택'),
          ),
          if (_controller != null && _controller!.value.isInitialized)
            Stack(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                ),
                if (_controller != null && _controller!.value.isInitialized)
                  CustomPaint(
                    painter: PosePainter(
                        _poseHistory.isEmpty
                            ? []
                            : _poseHistory[_currentFrameIndex],
                        _controller!.value.size),
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                    ),
                  ),
                //if (imagePath != null) Image.file(File(imagePath!))
              ],
            ),
        ],
      ),
    );
  }
}

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
