import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../controllers/pose_paint.dart';

class PoseDetectionScreen extends StatefulWidget {
  const PoseDetectionScreen({super.key});

  @override
  State<PoseDetectionScreen> createState() => _PoseDetectionScreenState();
}

class _PoseDetectionScreenState extends State<PoseDetectionScreen> {
  static List<CameraDescription> _cameras = [];

  CameraController? _cameraController;
  int _cameraIndex = -1;

  final PoseDetector _poseDetector =
      PoseDetector(options: PoseDetectorOptions());
  bool _isDetecting = false;
  List<Pose> _poses = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (_cameras.isEmpty) {
      _cameras = await availableCameras();
    }
    for (var i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == CameraLensDirection.back) {
        _cameraIndex = i;
        break;
      }
    }

    final camera = _cameras[_cameraIndex];
    _cameraController = CameraController(
      camera,
      // Set to ResolutionPreset.high. Do NOT set it to ResolutionPreset.max because for some phones does NOT work.
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    await _cameraController!.initialize();
    if (mounted) {
      setState(() {});
    }
    _startPoseDetection();
  }

  Uint8List convertYUV420ToNV21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = (width ~/ 2) * (height ~/ 2) * 2;

    // 🚨 여기서 전체 크기 확인
    if (image.planes[0].bytes.length < ySize ||
        image.planes[1].bytes.length < uvSize ~/ 2 ||
        image.planes[2].bytes.length < uvSize ~/ 2) {
      print("❌ 오류: YUV 데이터 크기 불일치!");
      return Uint8List(0); // 빈 데이터 반환
    }

    Uint8List nv21 = Uint8List(ySize + uvSize);
    Uint8List yBuffer = image.planes[0].bytes;
    Uint8List uBuffer = image.planes[1].bytes;
    Uint8List vBuffer = image.planes[2].bytes;

    // Y 채널 복사
    nv21.setRange(0, ySize, yBuffer);

    // UV 채널을 NV21 형식으로 변환 (VU 순서)
    int index = ySize;
    for (int i = 0; i < uBuffer.length; i++) {
      if (index + 1 >= nv21.length) break; //
      nv21[index++] = vBuffer[i]; // V 값
      nv21[index++] = uBuffer[i]; // U 값
    }

    return nv21;
  }

  void _startPoseDetection() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isDetecting) return;
      _isDetecting = true;

      try {
        print("📷 이미지 캡처됨, 포즈 분석 시작...");
        final inputImage = _convertCameraImage(image);
        if (inputImage == null) return;
        final poses = await _poseDetector.processImage(inputImage);
        setState(() {
          _poses = poses; // 감지된 포즈 데이터 업데이트
        });
        if (poses.isEmpty) {
          print("❌ 포즈를 감지하지 못했습니다.");
        } else {
          print("✅ 포즈 감지됨: ${poses.length}개");
          //_drawPose(poses);
        }
      } catch (e) {
        print("⚠️ 오류 발생: $e");
      } finally {
        _isDetecting = false;
      }
    });
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _convertCameraImage(CameraImage image) {
    final camera = _cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      // print('rotationCompensation: $rotationCompensation');
    }

    if (rotation == null) return null;
    // print('final rotation: $rotation');

    // get image format
    var format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null) {
      print("Unsupported format: ${image.format}");
      return null;
    }
    Uint8List imageBytes;
    if (Platform.isAndroid && format == InputImageFormat.yuv_420_888) {
      // 🔥 YUV_420_888을 NV21로 변환
      imageBytes = convertYUV420ToNV21(image);
      format = InputImageFormat.nv21;
    } else if (Platform.isAndroid && format == InputImageFormat.nv21) {
      imageBytes = image.planes.first.bytes;
    } else if (Platform.isIOS && format == InputImageFormat.bgra8888) {
      imageBytes = image.planes.first.bytes;
    } else {
      print("Unsupported format: $format");
      return null;
    }

    // since format is constraint to nv21 or bgra8888, both only have one plane
    // if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: imageBytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  void _drawPose(List<Pose> poses) {
    for (var pose in poses) {
      for (var landmark in pose.landmarks.values) {
        final x = landmark.x;
        final y = landmark.y;
        print('Landmark: (${landmark.type}, X: $x, Y: $y)');
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector.close();
    _cameraController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 📌 전면 카메라 좌우 반전 적용
                // Transform(
                //   alignment: Alignment.center,
                //   transform: Matrix4.rotationY(math.pi), // 좌우 반전
                //   child: CameraPreview(_cameraController!),
                // ),
                CameraPreview(
                  _cameraController!,
                  child: CustomPaint(
                    painter: PosePainter(
                        _poses,
                        Size(_cameraController!.value.previewSize!.height,
                            _cameraController!.value.previewSize!.width)),
                    child: Container(),
                  ),
                ),
              ],
            ),
    );
  }
}
