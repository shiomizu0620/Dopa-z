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
  const FeedPage({
    super.key,
    required this.repository,
    this.usingMockData = false,
  });

  final ProjectFeed repository;

  /// サンプルデータを表示していることをヘッダーに出すか。
  final bool usingMockData;

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final PageController _pageController = PageController();

  /// 現在ページの前後何件分のサムネイルを先読みするか。
  static const _precacheAhead = 2;
  static const _precacheBehind = 1;

  /// 残りがこの件数以下になったら次のページを取りに行く。
  static const _loadMoreThreshold = 3;

  /// フィルターチップに出す技術タグの最大数。
  static const _maxTechChips = 12;

  bool _initialLoading = true;
  String? _error;

  List<Project> _allProjects = const [];
  List<String> _techs = const [];
  String? _selectedTech;
  int _currentIndex = 0;

  int _loadedPage = 0;
  int _lastPage = 1;
  bool _loadingMore = false;

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
    _loadInitial();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.fetchProjects(page: 1);
      if (!mounted) return;
      setState(() {
        _allProjects = page.projects;
        _loadedPage = page.currentPage;
        _lastPage = page.lastPage;
        _techs = _collectTechs(page.projects);
        _initialLoading = false;
      });
      _precacheAround(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is FeedException ? e.message : '$e';
        _initialLoading = false;
      });
    }
  }

  /// 次のページを追加で読み込む。失敗しても画面は止めない。
  Future<void> _loadMore() async {
    if (_loadingMore || _loadedPage >= _lastPage) return;
    _loadingMore = true;
    try {
      final page = await widget.repository.fetchProjects(page: _loadedPage + 1);
      if (!mounted) return;
      setState(() {
        _allProjects = [..._allProjects, ...page.projects];
        _loadedPage = page.currentPage;
        _lastPage = page.lastPage;
        _techs = _collectTechs(_allProjects);
      });
    } catch (_) {
      // 追加読み込みの失敗は次のスワイプで再試行されるので黙って諦める
    } finally {
      _loadingMore = false;
    }
  }

  /// 出現回数の多い順に技術タグを集める。
  List<String> _collectTechs(List<Project> projects) {
    final counts = <String, int>{};
    for (final project in projects) {
      for (final tech in project.techs) {
        counts[tech] = (counts[tech] ?? 0) + 1;
      }
    }
    final techs = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return techs.take(_maxTechChips).toList();
  }

  /// [index] の前後のサムネイルをImageCacheに先読みし、
  /// スワイプした瞬間に表示できるようにする。
  void _precacheAround(int index) {
    final projects = _projects;
    if (projects.isEmpty) return;
    final start = (index - _precacheBehind).clamp(0, projects.length - 1);
    final end = (index + _precacheAhead).clamp(0, projects.length - 1);
    for (var i = start; i <= end; i++) {
      final url = projects[i].thumbnailUrl;
      if (url.isEmpty) continue;
      if (_precached.add(url)) {
        // 先読み失敗は無視(表示時にerrorBuilderで処理される)
        precacheImage(NetworkImage(url), context, onError: (_, __) {});
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _precacheAround(index);
    if (index >= _projects.length - _loadMoreThreshold) {
      _loadMore();
    }
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
        body: Column(
          children: [
            // 上部のセーフエリアは FeedTopBar が確保する
            FeedTopBar(
              techs: _techs,
              selectedTech: _selectedTech,
              onTechSelected: _onTechSelected,
              showMockBadge: widget.usingMockData,
            ),
            Expanded(child: _buildBody()),
            if (!_initialLoading && _error == null && _projects.isNotEmpty)
              SafeArea(
                top: false,
                child: _FeedProgressBar(
                  progress: (_currentIndex + 1) / _projects.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: TopazColors.cyan),
      );
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _loadInitial);
    }
    final projects = _projects;
    if (projects.isEmpty) {
      return const Center(
        child: Text('プロジェクトがありません', style: TextStyle(color: TopazColors.muted)),
      );
    }
    return PageView.builder(
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
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: TopazColors.border, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: TopazColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: TopazColors.cyan),
              child: const Text('再読み込み'),
            ),
          ],
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
