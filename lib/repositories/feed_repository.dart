import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/project.dart';

/// フィードに流すプロジェクトの取得元。
abstract class ProjectFeed {
  /// [page] ページ目 (1始まり) を取得する。
  Future<ProjectPage> fetchProjects({int page});
}

/// 取得に失敗したときに投げる例外。
class FeedException implements Exception {
  const FeedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// topaz.dev の公開APIからプロジェクト一覧を取得する。
///
/// GET https://topaz.dev/api/projects?page=N
class FeedRepository implements ProjectFeed {
  FeedRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final Uri _endpoint = Uri.parse('https://topaz.dev/api/projects');

  @override
  Future<ProjectPage> fetchProjects({int page = 1}) async {
    final uri = _endpoint.replace(queryParameters: {'page': '$page'});

    final http.Response response;
    try {
      response = await _client.get(uri);
    } catch (e) {
      throw FeedException('通信に失敗しました: $e');
    }

    if (response.statusCode != 200) {
      throw FeedException('プロジェクトの取得に失敗しました (HTTP ${response.statusCode})');
    }

    try {
      // Content-Type に charset が無くタイトルや作者名が日本語なので、
      // response.body ではなくバイト列をUTF-8として読む。
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return ProjectPage.fromJson(decoded);
    } catch (e) {
      throw FeedException('レスポンスを解釈できませんでした: $e');
    }
  }
}
