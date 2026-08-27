import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/project.dart';
import '../repositories/feed_repository.dart';

/// YouTube Shorts風の縦スワイプフィード。
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final FeedRepository _repository = FeedRepository();
  final PageController _pageController = PageController();

  late Future<List<Project>> _projectsFuture;

  /// 現在ページの前後何件分のサムネイルを先読みするか。
  static const _precacheAhead = 2;
  static const _precacheBehind = 1;

  List<Project> _projects = const [];
  final Set<String> _precached = {};

  @override
  void initState() {
    super.initState();
    _projectsFuture = _repository.fetchProjects();
  }

  /// [index] の前後のサムネイルをImageCacheに先読みし、
  /// スワイプした瞬間に表示できるようにする。
  void _precacheAround(int index) {
    if (_projects.isEmpty) return;
    final start = (index - _precacheBehind).clamp(0, _projects.length - 1);
    final end = (index + _precacheAhead).clamp(0, _projects.length - 1);
    for (var i = start; i <= end; i++) {
      final url = _projects[i].thumbnail;
      if (_precached.add(url)) {
        // 先読み失敗は無視(表示時にerrorBuilderで処理される)
        precacheImage(NetworkImage(url), context, onError: (_, __) {});
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Project>>(
        future: _projectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                '読み込みに失敗しました\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          final projects = snapshot.data ?? [];
          if (projects.isEmpty) {
            return const Center(
              child: Text(
                'プロジェクトがありません',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          if (_projects.isEmpty) {
            _projects = projects;
            // 初回表示時に先頭とその先を先読み
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _precacheAround(0);
            });
          }
          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            allowImplicitScrolling: true,
            itemCount: projects.length,
            onPageChanged: _precacheAround,
            itemBuilder: (context, index) {
              return _ProjectCard(project: projects[index]);
            },
          );
        },
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final Project project;

  Future<void> _openTopaz(BuildContext context) async {
    final uri = Uri.parse(project.topazUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('開けませんでした: ${project.topazUrl}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // サムネイル(全画面)
        Image.network(
          project.thumbnail,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white24),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const ColoredBox(
              color: Colors.black,
              child: Center(
                child: Icon(Icons.broken_image, color: Colors.white24, size: 64),
              ),
            );
          },
        ),
        // 下部を読みやすくするグラデーション
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.transparent, Colors.black87],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
        ),
        // プロジェクト情報
        SafeArea(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@${project.author}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tech in project.techs)
                        Chip(
                          label: Text(tech),
                          labelStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          backgroundColor: Colors.white24,
                          side: BorderSide.none,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _openTopaz(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('topaz.dev で見る'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
