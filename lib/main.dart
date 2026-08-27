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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: TopazColors.cyan,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: TopazColors.surface,
        useMaterial3: true,
      ),
      // topaz.dev の API は CORS ヘッダーを返さないため、ブラウザからは直接呼べない。
      // Webでの開発プレビューではサンプルデータを表示する。
      home: kIsWeb
          ? FeedPage(repository: MockFeedRepository(), usingMockData: true)
          : FeedPage(repository: FeedRepository()),
    );
  }
}
