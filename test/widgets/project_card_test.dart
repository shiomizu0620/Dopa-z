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

  group('サムネイルの展開サイズ', () {
    /// 指定した画面サイズ・画素密度で thumbnailProvider を作る。
    Future<ImageProvider> providerFor(
      WidgetTester tester, {
      required Size size,
      required double pixelRatio,
    }) async {
      late ImageProvider provider;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size, devicePixelRatio: pixelRatio),
          child: Builder(
            builder: (context) {
              provider = thumbnailProvider(
                context,
                'https://example.com/a.png',
              );
              return const SizedBox();
            },
          ),
        ),
      );
      return provider;
    }

    testWidgets('表示幅 x 画素密度で展開する', (WidgetTester tester) async {
      final provider = await providerFor(
        tester,
        size: const Size(390, 844),
        pixelRatio: 3,
      );

      // 実寸のまま展開させない (2000px超の画像が20MB級になるのを防ぐ)
      expect(provider, isA<ResizeImage>());
      expect((provider as ResizeImage).width, 1170);
    });

    testWidgets('大画面でも上限を超えない', (WidgetTester tester) async {
      final provider = await providerFor(
        tester,
        size: const Size(2000, 1200),
        pixelRatio: 2,
      );

      expect((provider as ResizeImage).width, 1440);
    });

    testWidgets('小さすぎる指定にはならない', (WidgetTester tester) async {
      final provider = await providerFor(
        tester,
        size: const Size(200, 400),
        pixelRatio: 1,
      );

      expect((provider as ResizeImage).width, 360);
    });
  });

  testWidgets('topazボタンはプロジェクトページを開く', (WidgetTester tester) async {
    final opened = await pumpCard(tester, _project());

    await tester.tap(find.text('topaz'));
    await tester.pump();

    expect(opened, ['https://topaz.dev/projects/p1']);
  });
}
