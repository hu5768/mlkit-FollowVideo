import 'package:flutter/widgets.dart';
import 'package:follow_video/controllers/option_controller.dart';
import 'package:follow_video/controllers/video_crop_controller.dart';
import 'package:get/get.dart';

Widget buildPreviewSection() {
  final videoController = Get.find<VideoCropController>();
  final optionController = Get.find<OptionController>();

  return Obx(() {
    final imageBytes = videoController.rawFrameBytes;
    final ratio = optionController.selectedRatio.value;
    final cropSize = optionController.cropSize;

    if (imageBytes == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('이거 뜨면 버그임ㅋㅋ')),
      );
    }

    final parts = ratio.split(':');
    final ratioW = int.parse(parts[0]);
    final ratioH = int.parse(parts[1]);
    final aspectRatio = ratioW / ratioH;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.maxWidth;
        final cropScale = cropSize / 100.0;
        return Container(
          color: const Color.fromARGB(255, 0, 0, 0),
          child: SizedBox(
            width: width,
            height: width,
            child: Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: Transform.scale(
                      scale: cropScale,
                      alignment: Alignment.center,
                      child: Image.memory(imageBytes),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  });
}
