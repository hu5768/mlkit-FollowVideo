import 'package:flutter/material.dart';
import 'package:follow_video/views/mene_page.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;
// import 'package:app_tracking_transparency/app_tracking_transparency.dart';

Future<void> requestCameraPermission() async {
  var status = await Permission.camera.status;
  if (!status.isGranted) {
    await Permission.camera.request();
  }
}

Future<void> _requestPermissions() async {
  if (Platform.isAndroid) {
    await Permission.storage.request();
  } else if (Platform.isIOS) {
    await Permission.photos.request(); // 또는 mediaLibrary 등
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 광고 초기화
  MobileAds.instance.initialize();

  // iOS에서만 광고 추적 권한 요청
  // if (Platform.isIOS) {
  //   final status = await AppTrackingTransparency.trackingAuthorizationStatus;
  //   if (status == TrackingStatus.notDetermined) {
  //     await AppTrackingTransparency.requestTrackingAuthorization();
  //   }
  // }

  await requestCameraPermission(); // 실행 시 권한 요청
  await _requestPermissions(); // 실행 시 권한 요청

  // MediaStore 초기화 (안드로이드 전용)
  if (Platform.isAndroid) {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'MyPoseVideos';
  }
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
