import 'package:dopaz/models/project.dart';
import 'package:dopaz/widgets/project_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Project _project({String githubId = '', String twitterId = ''}) {
  return Project(
    id: 'p1',
    title: 'テストプロジェクト',
    thumbnailUrl: 'https://example.com/thumb.png',
    authorName: '作者',
    authorUserName: 'author',
    avatarUrl: 'https://example.com/avatar.png',
    techs: const ['Flutter'],
    likeCount: 3,
    githubId: githubId,
    twitterId: twitterId,
  );
}

void main() {
  /// 開こうとしたURLを集めながらカードを描画する。
  Future<List<String>> pumpCard(WidgetTester tester, Project project) async {
    final opened = <String>[];
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectCard(project: project, onOpenUrl: opened.add),
        ),
      ),
    );
    return opened;
  }

  testWidgets('GitHubアイコンをタップすると本人のGitHubを開く', (WidgetTester tester) async {
    final opened = await pumpCard(tester, _project(githubId: 'octocat'));

    await tester.tap(find.byTooltip('@octocat のGitHub'));
    await tester.pump();

    expect(opened, ['https://github.com/octocat']);
  });

  testWidgets('Xアイコンをタップすると本人のXを開く', (WidgetTester tester) async {
    final opened = await pumpCard(tester, _project(twitterId: 'jack'));

    await tester.tap(find.byTooltip('@jack のX'));
    await tester.pump();

    expect(opened, ['https://x.com/jack']);
  });

  testWidgets('アカウントが未設定ならアイコンを出さない', (WidgetTester tester) async {
    await pumpCard(tester, _project());

    expect(find.byTooltip('@ のGitHub'), findsNothing);
    expect(find.byTooltip('@ のX'), findsNothing);
  });

  testWidgets('片方だけ設定されていればその片方だけ出す', (WidgetTester tester) async {
    await pumpCard(tester, _project(githubId: 'octocat'));

    expect(find.byTooltip('@octocat のGitHub'), findsOneWidget);
    expect(find.byTooltip('@jack のX'), findsNothing);
  });

  testWidgets('topazボタンはプロジェクトページを開く', (WidgetTester tester) async {
    final opened = await pumpCard(tester, _project());

    await tester.tap(find.text('topaz'));
    await tester.pump();

    expect(opened, ['https://topaz.dev/projects/p1']);
  });
}
