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

  final maxSecond = 10;
  int _currentFrameIndex = 0;
  String? imagePath;
  void _updatePoseHistory() {
    //print("프레임 : $currentFrame");
    if (_poseHistory.isNotEmpty) {
      //print("포즈배열 크기: ${_poseHistory.length}");
      final totalMs = _controller!.value.duration.inMilliseconds;
      final currentFrame =
          ((_controller!.value.position.inMilliseconds / totalMs) *
                  _poseHistory.length)
              .round();
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
      final frames = await extractFramesOnce(_videoPath!);
      if (frames.isNotEmpty) {
        runPoseDetectionOnFrames(frames);
      }
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

  void runPoseDetectionOnFrames(List<File> frames) async {
    final poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );

    for (final frame in frames) {
      final inputImage = InputImage.fromFile(frame);
      final poses = await poseDetector.processImage(inputImage);

      if (poses.isNotEmpty) {
        _poseHistory.add(poses.first.landmarks.values.toList());
        //print("코의 좌표: ${poses.first.landmarks[PoseLandmarkType.nose]?.x}");
      } else if (_poseHistory.isNotEmpty) {
        _poseHistory.add(_poseHistory.last);
      } else {
        _poseHistory.add(createEmptyPose());
      }

      await Future.delayed(const Duration(milliseconds: 10)); // 속도 조절
    }

    await poseDetector.close();
  }

  Future<List<File>> extractFramesOnce(String videoPath) async {
    final tempDir = await getTemporaryDirectory();
    final outputDir = '${tempDir.path}/frames';
    await Directory(outputDir).create(recursive: true);

    // 프레임 추출 명령어 (fps: 초당 프레임 수)
    final command = '-i "$videoPath" -vf fps=5 "$outputDir/frame_%03d.jpg"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print("✅ 프레임 추출 완료");

      // 추출된 프레임 파일 목록 리턴
      final files = Directory(outputDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jpg'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)); // 이름순 정렬
      return files;
    } else {
      print("❌ 프레임 추출 실패");
      return [];
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
          Text("currentFrame $_currentFrameIndex / ${_poseHistory.length}"),
          if (_controller != null && _controller!.value.isInitialized)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  children: [
                    VideoPlayer(_controller!),

                    if (_controller != null && _controller!.value.isInitialized)
                      CustomPaint(
                        painter: PosePainter(
                            _poseHistory.isEmpty
                                ? []
                                : _poseHistory[_currentFrameIndex],
                            _controller!.value.size),
                        child: Container(),
                      ),
                    //if (imagePath != null) Image.file(File(imagePath!))
                  ],
                ),
              ),
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

PoseLandmark emptyLandmark(PoseLandmarkType type) {
  return PoseLandmark(
    type: type,
    x: 0.0,
    y: 0.0,
    z: 0.0,
    likelihood: 0.0, // 확률도 0으로
  );
}

List<PoseLandmark> createEmptyPose() {
  return PoseLandmarkType.values.map((type) => emptyLandmark(type)).toList();
}
