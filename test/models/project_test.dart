import 'dart:convert';

import 'package:dopaz/models/project.dart';
import 'package:flutter_test/flutter_test.dart';

/// 実APIのレスポンスと同じ形のサンプル。
const _sampleJson = '''
{
  "current_page": 1,
  "last_page": 90,
  "data": [
    {
      "id": "663ca5694b0b35573ff2",
      "title": "らいとせいばー",
      "thumbnail_path": "project/01M10JMRRG3QYMPG7B42GPAW81.png",
      "updated_at": "2026-08-27T03:04:00.000000Z",
      "created_at": "2026-08-27T03:04:00.000000Z",
      "technology_tag_list": [
        {"id": "Go", "icon_path": "technology-tag/gopher000.svg", "type": "language"},
        {"id": "React", "icon_path": "technology-tag/react000.svg", "type": "framework"}
      ],
      "user": {
        "id": "915169bd9a7c1b41a4d1",
        "display_name": "いぶき",
        "avatar_image_path": "https://ptera-publish.topaz.dev/user/01M0CS1.png",
        "user_name": "ibuki",
        "social": {"github_id": "ibuki3268", "twitter_id": "ibuki3268_"}
      },
      "like_count": 42,
      "hackathon": null
    }
  ]
}
''';

void main() {
  test('APIレスポンスをProjectPageに変換できる', () {
    final page = ProjectPage.fromJson(
      jsonDecode(_sampleJson) as Map<String, dynamic>,
    );

    expect(page.currentPage, 1);
    expect(page.lastPage, 90);
    expect(page.hasMore, isTrue);
    expect(page.projects, hasLength(1));

    final project = page.projects.single;
    expect(project.id, '663ca5694b0b35573ff2');
    expect(project.title, 'らいとせいばー');
    expect(project.authorName, 'いぶき');
    expect(project.authorUserName, 'ibuki');
    expect(project.techs, ['Go', 'React']);
    expect(project.likeCount, 42);
  });

  test('サムネイルの相対パスは配信元を補って絶対URLになる', () {
    final page = ProjectPage.fromJson(
      jsonDecode(_sampleJson) as Map<String, dynamic>,
    );

    expect(
      page.projects.single.thumbnailUrl,
      'https://ptera-publish.topaz.dev/project/01M10JMRRG3QYMPG7B42GPAW81.png',
    );
  });

  test('絶対URLのアバターはそのまま使う', () {
    final page = ProjectPage.fromJson(
      jsonDecode(_sampleJson) as Map<String, dynamic>,
    );

    expect(
      page.projects.single.avatarUrl,
      'https://ptera-publish.topaz.dev/user/01M0CS1.png',
    );
  });

  test('プロジェクトページのURLをIDから組み立てる', () {
    final page = ProjectPage.fromJson(
      jsonDecode(_sampleJson) as Map<String, dynamic>,
    );

    expect(
      page.projects.single.topazUrl,
      'https://topaz.dev/projects/663ca5694b0b35573ff2',
    );
  });

  test('SNSのアカウント名からURLを組み立てる', () {
    final page = ProjectPage.fromJson(
      jsonDecode(_sampleJson) as Map<String, dynamic>,
    );

    final project = page.projects.single;
    expect(project.githubUrl, 'https://github.com/ibuki3268');
    expect(project.xUrl, 'https://x.com/ibuki3268_');
  });

  test('SNSのアカウントが空ならURLはnull', () {
    final page = ProjectPage.fromJson({
      'data': [
        {
          'id': 'abc',
          'user': {
            'social': {'github_id': '', 'twitter_id': '  '},
          },
        },
      ],
    });

    final project = page.projects.single;
    expect(project.githubUrl, isNull);
    expect(project.xUrl, isNull);
  });

  test('アカウント名の先頭の @ は落とす', () {
    final page = ProjectPage.fromJson({
      'data': [
        {
          'id': 'abc',
          'user': {
            'social': {'github_id': '@octocat', 'twitter_id': '@jack'},
          },
        },
      ],
    });

    final project = page.projects.single;
    expect(project.githubUrl, 'https://github.com/octocat');
    expect(project.xUrl, 'https://x.com/jack');
  });

  test('欠けているフィールドがあっても落ちない', () {
    final page = ProjectPage.fromJson({
      'data': [
        {'id': 'abc'},
      ],
    });

    final project = page.projects.single;
    expect(project.title, '');
    expect(project.thumbnailUrl, '');
    expect(project.avatarUrl, '');
    expect(project.techs, isEmpty);
    expect(project.likeCount, 0);
    expect(page.hasMore, isFalse);
  });
}
