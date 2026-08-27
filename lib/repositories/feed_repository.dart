import 'dart:convert';

import '../models/project.dart';

/// フィードに流すプロジェクトを取得するリポジトリ。
/// 現状はモックJSONを返す。将来ここを http でのAPI呼び出しに差し替える。
class FeedRepository {
  static const _mockJson = '''
[
  {
    "id": "prj_001",
    "title": "Dopa-z - ドーパミン駆動のプロジェクト発見アプリ",
    "thumbnail": "https://picsum.photos/seed/dopaz1/1280/720",
    "author": "akubi",
    "techs": ["Flutter", "Dart", "Riverpod"],
    "topazUrl": "https://topaz.dev/projects/prj_001",
    "likes": 57000,
    "comments": 270
  },
  {
    "id": "prj_002",
    "title": "リアルタイム共同編集ホワイトボード",
    "thumbnail": "https://picsum.photos/seed/dopaz2/1280/720",
    "author": "hackathon_taro",
    "techs": ["React", "TypeScript", "WebRTC"],
    "topazUrl": "https://topaz.dev/projects/prj_002",
    "likes": 12400,
    "comments": 88
  },
  {
    "id": "prj_003",
    "title": "LLMで議事録を自動要約するSlackボット",
    "thumbnail": "https://picsum.photos/seed/dopaz3/1280/720",
    "author": "ai_hanako",
    "techs": ["Python", "FastAPI", "Claude API"],
    "topazUrl": "https://topaz.dev/projects/prj_003",
    "likes": 8320,
    "comments": 156
  },
  {
    "id": "prj_004",
    "title": "IoT植物栽培キット GreenThumb",
    "thumbnail": "https://picsum.photos/seed/dopaz4/1280/720",
    "author": "maker_ken",
    "techs": ["Raspberry Pi", "Go", "Grafana"],
    "topazUrl": "https://topaz.dev/projects/prj_004",
    "likes": 3450,
    "comments": 42
  },
  {
    "id": "prj_005",
    "title": "位置情報ベースの音楽シェアマップ",
    "thumbnail": "https://picsum.photos/seed/dopaz5/1280/720",
    "author": "sound_walker",
    "techs": ["Swift", "MapKit", "Firebase"],
    "topazUrl": "https://topaz.dev/projects/prj_005",
    "likes": 21800,
    "comments": 331
  }
]
''';

  Future<List<Project>> fetchProjects() async {
    // API通信を模したディレイ
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final decoded = jsonDecode(_mockJson) as List<dynamic>;
    return decoded
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
