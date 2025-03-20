import 'package:flutter/material.dart';
import 'package:follow_video/views/camera_pose_detection.dart';
import 'package:follow_video/views/mene_page.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestCameraPermission() async {
  var status = await Permission.camera.status;
  if (!status.isGranted) {
    await Permission.camera.request();
  }
}

Future<void> _requestPermissions() async {
  await Permission.storage.request();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestCameraPermission(); // 실행 시 권한 요청
  await _requestPermissions(); // 실행 시 권한 요청
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'FollowVideo',
      home: MenePage(),
    );
  }
}
