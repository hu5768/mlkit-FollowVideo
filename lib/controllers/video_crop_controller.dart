import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class VideoCropController extends GetxController {
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

      final x = i * 2; // 프레임마다 x 이동 (예시)
      const y = 0;
      const w = 720;
      const h = 896;

      final cropCommand =
          '-i "$inputPath" -vf "crop=$w:$h:$x:$y" "$outputFrame"';
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
