import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class PoseCropController extends GetxController {
  Rx<VideoPlayerController?> controller = Rx<VideoPlayerController?>(null);
  RxList<List<PoseLandmark>> poseHistory = <List<PoseLandmark>>[].obs;
  RxInt currentFrameIndex = 0.obs;
  RxString? videoPath = RxString('');
  Timer? _poseTimer;
  final int _elapsedMs = 0;

  Future<void> pickVideo() async {
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.single.path == null) return;

    videoPath!.value = result.files.single.path!;
    final inputPath = result.files.single.path!;

    final tempDir = await getTemporaryDirectory();
    final frameDir = '${tempDir.path}/frames';
    final croppedDir = '${tempDir.path}/cropped';
    final outputPath = '$croppedDir/final_output.mp4';

    await _deletePreviousImages(); //디렉토리에 남아있는 jpg 제거
    final frames = await extractFramesOnce(videoPath!.value, frameDir); //프레임 분할
    print("프레임 추출 : ${frames.length}");
    if (frames.isNotEmpty) await runPoseDetectionOnFrames(frames);
    print('✅ 총 프레임 수: ${frames.length}');
    print('✅ 저장된 pose 수: ${poseHistory.length}');

    for (int i = 0; i < poseHistory.length; i++) {
      final landmarks = poseHistory[i];
      print('🦴 프레임 $i: landmark 개수 = ${landmarks.length}');
    }
    await cropAndAssembleFrames(
        frames: frames, croppedDir: croppedDir, outputPath: outputPath);

    print("크롭");
    if (controller.value != null) {
      await controller.value!.dispose();
    }
    print("컨트롤러 교체");
    // 6. 새로운 컨트롤러로 교체 + 초기화
    final newController = VideoPlayerController.file(File(outputPath));
    await newController.initialize();
    controller.value = newController;
  }

  Future<void> _deletePreviousImages() async {
    final dir = await getTemporaryDirectory();
    final files = dir.listSync();
    for (var file in files) {
      if (file is File && file.path.endsWith('.jpg')) await file.delete();
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

  Future<List<File>> extractFramesOnce(
      String videoPath, final outputDir) async {
    final outputDirRef = Directory(outputDir);

    // 디렉토리가 존재하면 모두 삭제
    if (await outputDirRef.exists()) {
      await outputDirRef.delete(recursive: true);
    }
    // 새로 생성
    await outputDirRef.create(recursive: true);
    final command =
        '-i "$videoPath" -vf fps=30 -vsync vfr "$outputDir/frame_%05d.jpg"';

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

  int getCropX(int frameIndex) => 100 + frameIndex * 2; // 오른쪽으로 이동
  int getCropY(int frameIndex) => 50; // 고정

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
          '$croppedDir/frame_${i.toString().padLeft(5, '0')}.jpg';

      if (i >= poseHistory.length) {
        print('⚠️ poseHistory 길이 부족: $i / ${poseHistory.length}');
        break;
      }
      final landmarks = poseHistory[i];

      final left = landmarks[PoseLandmarkType.leftShoulder.index];
      final right = landmarks[PoseLandmarkType.rightShoulder.index];

      final avgX = (left.x + right.x) / 2;
      final avgY = (left.y + right.y) / 2;

      final x = avgX - 270; // 프레임마다 x 이동 (예시)
      final y = avgY - 200;
      const w = 540;
      const h = 960;

      final cropCommand =
          '-i "$inputPath" -vf "crop=$w:$h:$x:$y,pad=$w:$h:(ow-iw)/2:(oh-ih)/2" "$outputFrame"';
      await FFmpegKit.execute(cropCommand);
    }

    for (int i = 0; i < frames.length; i++) {
      final inputPath = frames[i].path;
      final outputFrame =
          '$croppedDir/frame_${i.toString().padLeft(5, '0')}.jpg';

      // 디버그용 로그 추가
      print('➡️ crop: $inputPath → $outputFrame');
    }

    // 3. crop된 프레임 영상으로 조립
    // final assembleCommand =
    //     '-framerate 30 -i "$croppedDir/frame_%05d.jpg" -c:v libx264 -pix_fmt yuv420p "$outputPath"';
    final assembleCommand =
        '-framerate 30 -i "$croppedDir/frame_%05d.jpg" -c:v mpeg4 -pix_fmt yuv420p "$outputPath"';
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

  void togglePlayPause() {
    final ctrl = controller.value;

    if (ctrl == null || !ctrl.value.isInitialized) return;

    if (ctrl.value.isPlaying) {
      ctrl.pause();
    } else {
      ctrl.play();
    }
  }

  @override
  void onClose() {
    controller.value?.dispose();
    super.onClose();
  }
}
