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
    "thumbnail": "https://picsum.photos/seed/dopaz1/720/1280",
    "author": "akubi",
    "techs": ["Flutter", "Dart", "Riverpod"],
    "topazUrl": "https://topaz.dev/projects/prj_001"
  },
  {
    "id": "prj_002",
    "title": "リアルタイム共同編集ホワイトボード",
    "thumbnail": "https://picsum.photos/seed/dopaz2/720/1280",
    "author": "hackathon_taro",
    "techs": ["React", "TypeScript", "WebRTC"],
    "topazUrl": "https://topaz.dev/projects/prj_002"
  },
  {
    "id": "prj_003",
    "title": "LLMで議事録を自動要約するSlackボット",
    "thumbnail": "https://picsum.photos/seed/dopaz3/720/1280",
    "author": "ai_hanako",
    "techs": ["Python", "FastAPI", "Claude API"],
    "topazUrl": "https://topaz.dev/projects/prj_003"
  },
  {
    "id": "prj_004",
    "title": "IoT植物栽培キット GreenThumb",
    "thumbnail": "https://picsum.photos/seed/dopaz4/720/1280",
    "author": "maker_ken",
    "techs": ["Raspberry Pi", "Go", "Grafana"],
    "topazUrl": "https://topaz.dev/projects/prj_004"
  },
  {
    "id": "prj_005",
    "title": "位置情報ベースの音楽シェアマップ",
    "thumbnail": "https://picsum.photos/seed/dopaz5/720/1280",
    "author": "sound_walker",
    "techs": ["Swift", "MapKit", "Firebase"],
    "topazUrl": "https://topaz.dev/projects/prj_005"
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
