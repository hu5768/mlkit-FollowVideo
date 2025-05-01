import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class VideoPoseController extends GetxController {
  Rx<VideoPlayerController?> controller = Rx<VideoPlayerController?>(null);
  RxList<List<PoseLandmark>> poseHistory = <List<PoseLandmark>>[].obs;
  RxInt currentFrameIndex = 0.obs;
  RxString? videoPath = RxString('');
  Timer? _poseTimer;
  int _elapsedMs = 0;

  Future<void> pickVideo() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.video);

    if (result != null && result.files.isNotEmpty) {
      videoPath!.value = result.files.single.path!;
      final file = File(videoPath!.value);

      controller.value?.removeListener(updatePoseHistory);
      controller.value = VideoPlayerController.file(file);
      await controller.value!.initialize();
      controller.value!
        ..setLooping(true)
        ..play();
      controller.refresh();

      _startPoseTimer();
      await _deletePreviousImages();
      final frames = await extractFramesOnce(videoPath!.value);
      if (frames.isNotEmpty) runPoseDetectionOnFrames(frames);
    }
  }

  void updatePoseHistory() {
    _elapsedMs += 33;
    int totalMs = controller.value?.value.duration.inMilliseconds ?? 1;
    int currentFrame = ((poseHistory.length * _elapsedMs) / totalMs).floor();

    if (currentFrame < poseHistory.length) {
      currentFrameIndex.value = currentFrame;
    } else {
      _elapsedMs = 0;
    }
  }

  void _startPoseTimer() {
    _poseTimer?.cancel();
    _poseTimer = Timer.periodic(
        const Duration(milliseconds: 32), (_) => updatePoseHistory());
  }

  void _stopPoseTimer() {
    _poseTimer?.cancel();
  }

  Future<void> _deletePreviousImages() async {
    final dir = await getTemporaryDirectory();
    final files = dir.listSync();
    for (var file in files) {
      if (file is File && file.path.endsWith('.jpg')) await file.delete();
    }
  }

  Future<List<File>> extractFramesOnce(String videoPath) async {
    final tempDir = await getTemporaryDirectory();
    final outputDir = '${tempDir.path}/frames';
    await Directory(outputDir).create(recursive: true);
    final command = '-i "$videoPath" -vf fps=30 "$outputDir/frame_%05d.jpg"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      final files = Directory(outputDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.jpg'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      return files;
    }
    return [];
  }

  void runPoseDetectionOnFrames(List<File> frames) async {
    final poseDetector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
    for (final frame in frames) {
      final inputImage = InputImage.fromFile(frame);
      final poses = await poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        poseHistory.add(poses.first.landmarks.values.toList());
      } else if (poseHistory.isNotEmpty) {
        poseHistory.add(poseHistory.last);
      } else {
        poseHistory.add(createEmptyPose());
      }
      await Future.delayed(const Duration(milliseconds: 5));
    }
    await poseDetector.close();
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

  @override
  void onClose() {
    _stopPoseTimer();
    controller.value?.dispose();
    super.onClose();
  }
}
