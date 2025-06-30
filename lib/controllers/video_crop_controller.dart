import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:follow_video/controllers/option_controller.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

class VideoCropController extends GetxController {
  Rx<VideoPlayerController?> controller = Rx<VideoPlayerController?>(null);
  RxList<List<PoseLandmark>> poseHistory = <List<PoseLandmark>>[].obs;
  RxString videoPath = RxString('');
  RxString outputPath = RxString('');

  final optionController = Get.put(OptionController());
  Size? originSize;
  Uint8List? rawFrameBytes;

  final RxString progressLabel = '영상 선택 대기 중...'.obs;
  final RxDouble progressValue = 0.0.obs;
  void updateProgress(String label, double value) {
    progressLabel.value = label;
    progressValue.value = value;
  }

  Future<bool> pickVideo() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.single.path == null) return false;

    videoPath.value = result.files.single.path!;

    // 원본 영상 사이즈 추출
    final tempController = VideoPlayerController.file(File(videoPath.value));
    await tempController.initialize();
    originSize = tempController.value.size;
    await tempController.dispose();

    if (originSize != null) {
      print(
          '📏 원본 해상도: ${originSize!.width.toInt()} x ${originSize!.height.toInt()}');
    } else {
      print('❌ 영상 해상도 추출 실패');
    }

    // 2. FFmpeg로 첫 프레임 추출
    final tempDir = await getTemporaryDirectory();
    final framePath = '${tempDir.path}/preview_raw.png';

    final cmd = '-i "${videoPath.value}" -ss 00:00:01 -vframes 1 "$framePath"';
    await FFmpegKit.execute(cmd);

    final file = File(framePath);
    if (await file.exists()) {
      rawFrameBytes = await file.readAsBytes();
      print('📸 첫 프레임 저장 완료 (${rawFrameBytes!.lengthInBytes} bytes)');
    } else {
      print('❌ 첫 프레임 추출 실패');
    }
    return true;
  }

  Future<void> makeVideo() async {
    final tempDir = await getTemporaryDirectory();
    final frameDir = '${tempDir.path}/frames';
    final croppedDir = '${tempDir.path}/cropped';
    outputPath.value = '$croppedDir/final_output.mp4';

    await _deletePreviousImages();

    updateProgress('프레임 추출 중...', 0.1);
    final frames = await extractFramesOnce(videoPath.value, frameDir);

    updateProgress('무브 분석 중...', 0.3);
    if (frames.isNotEmpty) await runPoseDetectionOnFrames(frames);

    smoothPoseHistory(windowSize: optionController.smoothingWindowSize);

    updateProgress('크롭 및 조립 중...', 0.7);
    await cropAndAssembleFrames(
        frames: frames, croppedDir: croppedDir, outputPath: outputPath.value);

    updateProgress('영상 초기화 중...', 0.9);
    if (controller.value != null) {
      await controller.value!.dispose();
    }
    final newController = VideoPlayerController.file(File(outputPath.value));
    await newController.initialize();
    controller.value = newController;
    updateProgress('완료', 1.0);
  }

  Future<void> _deletePreviousImages() async {
    final dir = await getTemporaryDirectory();
    final files = dir.listSync();
    for (var file in files) {
      if (file is File && file.path.endsWith('.png')) await file.delete();
    }
  }

//비디오 프레임 분할
  Future<List<File>> extractFramesOnce(
      String videoPath, final outputDir) async {
    final outputDirRef = Directory(outputDir);
    if (await outputDirRef.exists()) {
      // 디렉토리가 존재하면 모두 삭제
      await outputDirRef.delete(recursive: true);
    }
    await outputDirRef.create(recursive: true);
    final command =
        '-i "$videoPath" -vf fps=30 -vsync vfr "$outputDir/frame_%05d.png"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      final files = Directory(outputDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      return files;
    }
    return [];
  }

  int getCropX(int frameIndex) => 100 + frameIndex * 2;
  int getCropY(int frameIndex) => 50;

//프레임별 포즈 디텍팅
  Future<void> runPoseDetectionOnFrames(List<File> frames) async {
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
      likelihood: 0.0,
    );
  }

  List<PoseLandmark> createEmptyPose() {
    return PoseLandmarkType.values.map((type) => emptyLandmark(type)).toList();
  }

//프레임별 크롭
  Future<void> cropAndAssembleFrames({
    required List<File> frames,
    required String croppedDir,
    required String outputPath,
  }) async {
    // 1. 디렉토리 준비
    final croppedDirectory = Directory(croppedDir);
    if (await croppedDirectory.exists()) {
      await croppedDirectory.delete(recursive: true);
    }
    await croppedDirectory.create(recursive: true);
// 2. 프레임별 crop
    for (int i = 0; i < frames.length; i++) {
      final inputPath = frames[i].path;
      final outputFrame =
          '$croppedDir/frame_${i.toString().padLeft(5, '0')}.png';

      if (i >= poseHistory.length) {
        print('⚠️ poseHistory 길이 부족: $i / ${poseHistory.length}');
        break;
      }
      final landmarks = poseHistory[i];

      final left = landmarks[PoseLandmarkType.leftHip.index];
      final right = landmarks[PoseLandmarkType.rightHip.index];

      final avgX = (left.x + right.x) / 2;
      final avgY = (left.y + right.y) / 2;

      final originalW = originSize!.width;
      final originalH = originSize!.height;

      final ratioParts = optionController.selectedRatio.value.split(':');
      final ratioW = int.parse(ratioParts[0]);
      final ratioH = int.parse(ratioParts[1]);
      final aspectRatio = ratioW / ratioH;

      double cropH;
      if (optionController.cropOption.value == 'custom') {
        cropH = originalH * (optionController.cropSize.value / 100);
      } else {
        // auto 모드일 때, 이후 구현
        cropH = originalH * 0.7;
      }

      final cropW = cropH * aspectRatio;

      final x = avgX - cropW / 2;
      final y = avgY - cropH / 2;

      final cropCommand =
          '-i "$inputPath" -vf "crop=$cropW:$cropH:$x:$y,pad=$cropW:$cropH:(ow-iw)/2:(oh-ih)/2" "$outputFrame"';
      await FFmpegKit.execute(cropCommand);
    }

    for (int i = 0; i < frames.length; i++) {
      final inputPath = frames[i].path;
      final outputFrame =
          '$croppedDir/frame_${i.toString().padLeft(5, '0')}.png';
      print('➡️ crop: $inputPath → $outputFrame');
    }

    final assembleCommand =
        '-framerate 30 -i "$croppedDir/frame_%05d.png" -c:v mpeg4 -q:v 1 -pix_fmt yuv420p "$outputPath"';

    final session = await FFmpegKit.execute(assembleCommand);
    final logs = await session.getAllLogs();
    for (final log in logs) {
      print('🛠 FFmpeg: ${log.getMessage()}');
    }
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print('✅ 영상 조립 완료: $outputPath');
    } else {
      print('❌ 영상 조립 실패: $returnCode');
    }
  }

  List<double> movingAverage(List<double> values, int windowSize) {
    final smoothed = <double>[];
    for (int i = 0; i < values.length; i++) {
      final start = (i - windowSize + 1).clamp(0, values.length - 1);
      final end = i + 1;
      final window = values.sublist(start, end);
      smoothed.add(window.reduce((a, b) => a + b) / window.length);
    }
    return smoothed;
  }

//포즈 디텍팅 결과 스무딩
  void smoothPoseHistory({int windowSize = 3}) {
    final int frameCount = poseHistory.length;
    if (frameCount == 0) return;
    final int landmarkCount = poseHistory[0].length;

    for (int landmarkIndex = 0;
        landmarkIndex < landmarkCount;
        landmarkIndex++) {
      final xList = <double>[];
      final yList = <double>[];

      for (int frame = 0; frame < frameCount; frame++) {
        xList.add(poseHistory[frame][landmarkIndex].x);
        yList.add(poseHistory[frame][landmarkIndex].y);
      }

      final smoothX = movingAverage(xList, windowSize);
      final smoothY = movingAverage(yList, windowSize);

      for (int frame = 0; frame < frameCount; frame++) {
        final orig = poseHistory[frame][landmarkIndex];
        poseHistory[frame][landmarkIndex] = PoseLandmark(
          type: orig.type,
          x: smoothX[frame],
          y: smoothY[frame],
          z: orig.z,
          likelihood: orig.likelihood,
        );
      }
    }
  }

  Future<void> reset() async {
    controller.value?.dispose();
    controller.value = null;

    poseHistory.clear();
    videoPath.value = '';
    outputPath.value = '';

    progressLabel.value = '영상 선택 대기 중...';
    progressValue.value = 0.0;
  }

  @override
  void onClose() {
    controller.value?.dispose();
    super.onClose();
  }

  void togglePlayPause() {
    final ctrl = controller.value;

    if (ctrl == null || !ctrl.value.isInitialized) return;

    if (ctrl.value.isPlaying) {
      ctrl.pause();
    } else {
      ctrl.play();
    }
  }

  Future<void> saveVideoToGallery(String videoPath) async {
    final status = await Permission.videos.request();
    if (!status.isGranted) {
      print('❌ 저장 권한 거부됨');
      return;
    }

    final file = File(videoPath);
    if (!file.existsSync()) {
      print('❌ 영상 파일이 존재하지 않음');
      return;
    }

    try {
      final store = MediaStore();

      final result = await store.saveFile(
        tempFilePath: videoPath,
        dirType: DirType.video,
        dirName: DirName.movies,
        relativePath: 'MyPoseVideos',
      );

      if (result != null) {
        print('✅ 저장 완료: ${result.uri}');
        Fluttertoast.showToast(
          msg: '✅ 영상이 갤러리에 저장되었습니다!',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        print('❌ 저장 실패: 반환값 null');
      }
    } catch (e) {
      print('❌ 저장 중 예외 발생: $e');
    }
  }
}
