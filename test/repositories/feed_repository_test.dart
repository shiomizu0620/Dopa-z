import 'dart:convert';

import 'package:dopaz/repositories/feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// http.Response(String) は本文を latin1 として扱うので、
/// 日本語を含むレスポンスはバイト列で組み立てる。
http.Response _response({
  int currentPage = 1,
  int lastPage = 3,
  String title = 'テスト',
}) {
  return http.Response.bytes(
    utf8.encode(
      _body(currentPage: currentPage, lastPage: lastPage, title: title),
    ),
    200,
    headers: {'content-type': 'application/json'},
  );
}

String _body({int currentPage = 1, int lastPage = 3, String title = 'テスト'}) {
  return jsonEncode({
    'current_page': currentPage,
    'last_page': lastPage,
    'data': [
      {
        'id': 'p1',
        'title': title,
        'thumbnail_path': 'project/p1.png',
        'technology_tag_list': [
          {'id': 'Flutter', 'icon_path': 'x.svg', 'type': 'framework'},
        ],
        'user': {
          'id': 'u1',
          'display_name': '作者',
          'avatar_image_path': 'https://ptera-publish.topaz.dev/a.png',
          'user_name': 'author',
          'social': {'github_id': '', 'twitter_id': ''},
        },
        'like_count': 7,
        'hackathon': null,
      },
    ],
  });
}

void main() {
  test('プロジェクト一覧を取得してパースする', () async {
    final repository = FeedRepository(
      client: MockClient((request) async {
        expect(request.url.host, 'topaz.dev');
        expect(request.url.path, '/api/projects');
        return _response();
      }),
    );

    final page = await repository.fetchProjects();

    expect(page.currentPage, 1);
    expect(page.lastPage, 3);
    expect(page.projects.single.likeCount, 7);
  });

  test('ページ番号をクエリで渡す', () async {
    late Uri requested;
    final repository = FeedRepository(
      client: MockClient((request) async {
        requested = request.url;
        return _response(currentPage: 2);
      }),
    );

    final page = await repository.fetchProjects(page: 2);

    expect(requested.queryParameters['page'], '2');
    expect(page.currentPage, 2);
  });

  test('charset指定がなくても日本語が壊れない', () async {
    final repository = FeedRepository(
      // 実APIと同じく Content-Type に charset が付かないケース
      client: MockClient((request) async => _response(title: 'らいとせいばー')),
    );

    final page = await repository.fetchProjects();

    expect(page.projects.single.title, 'らいとせいばー');
  });

  test('エラー応答は FeedException になる', () async {
    final repository = FeedRepository(
      client: MockClient((request) async => http.Response('', 503)),
    );

    expect(
      () => repository.fetchProjects(),
      throwsA(
        isA<FeedException>().having(
          (e) => e.message,
          'message',
          contains('503'),
        ),
      ),
    );
  });

  test('通信エラーは FeedException になる', () async {
    final repository = FeedRepository(
      client: MockClient((request) async {
        throw http.ClientException('failed');
      }),
    );

    expect(
      () => repository.fetchProjects(),
      throwsA(
        isA<FeedException>().having(
          (e) => e.message,
          'message',
          contains('通信に失敗'),
        ),
      ),
    );
  });
}
