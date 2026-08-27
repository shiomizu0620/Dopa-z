import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/project.dart';
import '../repositories/feed_repository.dart';
import '../theme.dart';
import '../widgets/feed_top_bar.dart';
import '../widgets/project_card.dart';

/// YouTube Shorts風の縦スワイプフィード。
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final FeedRepository _repository = FeedRepository();
  final PageController _pageController = PageController();

  /// 現在ページの前後何件分のサムネイルを先読みするか。
  static const _precacheAhead = 2;
  static const _precacheBehind = 1;

  late Future<List<Project>> _projectsFuture;

  List<Project> _allProjects = const [];
  List<String> _techs = const [];
  String? _selectedTech;
  int _currentIndex = 0;

  final Set<String> _precached = {};

  /// フィルター適用後の表示対象。
  List<Project> get _projects {
    final tech = _selectedTech;
    if (tech == null) return _allProjects;
    return _allProjects.where((p) => p.techs.contains(tech)).toList();
  }

  @override
  void initState() {
    super.initState();
    _projectsFuture = _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<List<Project>> _load() async {
    final projects = await _repository.fetchProjects();
    _allProjects = projects;
    _techs = _collectTechs(projects);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _precacheAround(0);
    });
    return projects;
  }

  /// 出現回数の多い順に技術タグを集める。
  List<String> _collectTechs(List<Project> projects) {
    final counts = <String, int>{};
    for (final project in projects) {
      for (final tech in project.techs) {
        counts[tech] = (counts[tech] ?? 0) + 1;
      }
    }
    return counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  }

  /// [index] の前後のサムネイルをImageCacheに先読みし、
  /// スワイプした瞬間に表示できるようにする。
  void _precacheAround(int index) {
    final projects = _projects;
    if (projects.isEmpty) return;
    final start = (index - _precacheBehind).clamp(0, projects.length - 1);
    final end = (index + _precacheAhead).clamp(0, projects.length - 1);
    for (var i = start; i <= end; i++) {
      final url = projects[i].thumbnail;
      if (_precached.add(url)) {
        // 先読み失敗は無視(表示時にerrorBuilderで処理される)
        precacheImage(NetworkImage(url), context, onError: (_, __) {});
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _precacheAround(index);
  }

  void _onTechSelected(String? tech) {
    setState(() {
      _selectedTech = tech;
      _currentIndex = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _precacheAround(0);
  }

  Future<void> _openTopaz(Project project) async {
    final uri = Uri.parse(project.topazUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('開けませんでした: ${project.topazUrl}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 背景が白なのでステータスバーの文字は暗い色にする
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: TopazColors.surface,
        body: FutureBuilder<List<Project>>(
          future: _projectsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: TopazColors.cyan),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  '読み込みに失敗しました\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: TopazColors.muted),
                ),
              );
            }
            final projects = _projects;
            return Column(
              children: [
                FeedTopBar(
                  techs: _techs,
                  selectedTech: _selectedTech,
                  onTechSelected: _onTechSelected,
                ),
                Expanded(
                  child: projects.isEmpty
                      ? const Center(
                          child: Text(
                            'プロジェクトがありません',
                            style: TextStyle(color: TopazColors.muted),
                          ),
                        )
                      : PageView.builder(
                          controller: _pageController,
                          scrollDirection: Axis.vertical,
                          allowImplicitScrolling: true,
                          itemCount: projects.length,
                          onPageChanged: _onPageChanged,
                          itemBuilder: (context, index) {
                            final project = projects[index];
                            return ProjectCard(
                              project: project,
                              onOpenTopaz: () => _openTopaz(project),
                            );
                          },
                        ),
                ),
                if (projects.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: _FeedProgressBar(
                      progress: (_currentIndex + 1) / projects.length,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// フィード内の位置を示すシークバー風のインジケーター。
class _FeedProgressBar extends StatelessWidget {
  const _FeedProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return TweenAnimationBuilder<double>(
          tween: Tween(end: progress.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 200),
          builder: (context, value, _) {
            return SizedBox(
              height: 14,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 6,
                    child: Container(height: 2.5, color: TopazColors.border),
                  ),
                  Positioned(
                    left: 0,
                    top: 6,
                    child: Container(
                      width: width * value,
                      height: 2.5,
                      color: TopazColors.cyan,
                    ),
                  ),
                  Positioned(
                    left: (width * value - 5).clamp(0.0, width - 10),
                    top: 2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: TopazColors.cyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
