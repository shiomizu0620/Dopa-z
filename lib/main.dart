import 'dart:ui';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'pages/feed_page.dart';
import 'repositories/feed_repository.dart';
import 'repositories/mock_feed_repository.dart';
import 'theme.dart';

/// マウス・トラックパッドのドラッグでもスワイプできるようにする
/// (Web/デスクトップでのプレビュー用。デフォルトはタッチのみ)。
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

void main() {
  runApp(
    DevicePreview(
      // リリースビルドでは無効化
      enabled: !kReleaseMode,
      builder: (context) => const DopazApp(),
    ),
  );
}

class DopazApp extends StatelessWidget {
  const DopazApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dopaz',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      // 端末のダークモード設定に追従する
      theme: TopazColors.light.toThemeData(Brightness.light),
      darkTheme: TopazColors.dark.toThemeData(Brightness.dark),
      themeMode: ThemeMode.system,
      // 本番Webは vercel.json の rewrite で同一オリジン経由になるので実APIを叩ける。
      // ローカルの `flutter run -d chrome` にはその中継が無く直接呼ぶとCORSで
      // 弾かれるため、デバッグビルドのWebだけサンプルデータを表示する。
      home: kIsWeb && !kReleaseMode
          ? FeedPage(repository: MockFeedRepository(), usingMockData: true)
          : FeedPage(repository: FeedRepository()),
    );
  }
}
