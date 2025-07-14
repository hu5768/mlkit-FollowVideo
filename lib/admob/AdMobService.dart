import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  //앱 개발시 테스트광고 ID로 입력

  //전면 광고
  static String? get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return kReleaseMode
          ? 'ca-app-pub-3443570983692474/1967011102' // 릴리즈용
          : 'ca-app-pub-3940256099942544/1033173712'; // 디버그용 (테스트 ID)
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return null;
  }
}
