import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/project.dart';
import 'feed_repository.dart';

/// assets のサンプルJSONを返す [ProjectFeed]。
///
/// topaz.dev の API は CORS ヘッダーを返さないため、ブラウザからは直接呼べない。
/// Webでの開発プレビューではこちらを使う。JSONは実APIのレスポンスをそのまま保存したもの。
class MockFeedRepository implements ProjectFeed {
  static const assetPath = 'assets/mock_projects.json';

  @override
  Future<ProjectPage> fetchProjects({int page = 1}) async {
    // API通信を模したディレイ
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final raw = await rootBundle.loadString(assetPath);
    return ProjectPage.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
