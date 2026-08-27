import 'package:flutter/material.dart';

import '../models/project.dart';
import '../theme.dart';

/// フィード1ページ分。サムネイルの下に作者情報、右下にアクションを置く。
///
/// いいね・フォローといった書き込み操作は topaz.dev 側の機能なので、
/// このアプリでは件数を表示するだけで実行はできない。
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.onOpenTopaz,
  });

  final Project project;
  final VoidCallback onOpenTopaz;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _Thumbnail(url: project.thumbnail)),
              // Shorts と同じくサムネイル右下に縦並びで置く
              Positioned(
                right: 6,
                bottom: 8,
                child: _ActionRail(project: project, onOpenTopaz: onOpenTopaz),
              ),
            ],
          ),
        ),
        _ProjectInfo(project: project, onOpenTopaz: onOpenTopaz),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(color: TopazColors.cyan),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(Icons.broken_image, color: TopazColors.border, size: 64),
        );
      },
    );
  }
}

/// サムネイル下の作者・タイトル・技術タグ。
class _ProjectInfo extends StatelessWidget {
  const _ProjectInfo({required this.project, required this.onOpenTopaz});

  final Project project;
  final VoidCallback onOpenTopaz;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AuthorAvatar(author: project.author),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '@${project.author}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TopazColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _FollowButton(
                onTap: () => showTopazOnly(context, 'フォロー', onOpenTopaz),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            project.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TopazColors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            project.techs.map((t) => '#${t.replaceAll(' ', '')}').join(' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: TopazColors.cyan,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.author});

  final String author;

  @override
  Widget build(BuildContext context) {
    // 作者名から決まる色を割り当てる(アバター画像は未提供のため)
    final hue = (author.hashCode.abs() % 360).toDouble();
    final color = HSLColor.fromAHSL(1, hue, 0.45, 0.55).toColor();
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        author.characters.first.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: TopazColors.cyan,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'フォロー',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// サムネイル右下に縦に並ぶアクション。
class _ActionRail extends StatelessWidget {
  const _ActionRail({required this.project, required this.onOpenTopaz});

  final Project project;
  final VoidCallback onOpenTopaz;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // いいね数は topaz.dev から取得した値の表示のみ。
        // このアプリからいいねを付けることはできない。
        _RailButton(
          icon: Icons.favorite_border,
          label: _formatCount(project.likes),
          onTap: () => showTopazOnly(context, 'いいね', onOpenTopaz),
        ),
        _RailButton(
          icon: Icons.comment,
          label: _formatCount(project.comments),
          onTap: () => showTopazOnly(context, 'コメント', onOpenTopaz),
        ),
        _RailButton(
          icon: Icons.reply,
          flipHorizontally: true,
          label: '共有',
          onTap: () => _showComingSoon(context, '共有'),
        ),
        _RailButton(
          icon: Icons.open_in_new,
          label: 'topaz',
          onTap: onOpenTopaz,
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label は未実装です'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// topaz.dev 側でしか行えない操作をタップされたときの案内。
void showTopazOnly(BuildContext context, String label, VoidCallback onOpen) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$label は topaz.dev で行えます'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '開く',
          textColor: TopazColors.cyan,
          onPressed: onOpen,
        ),
      ),
    );
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.flipHorizontally = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool flipHorizontally;

  @override
  Widget build(BuildContext context) {
    // サムネイルの上にも白い余白の上にも乗るので、白い縁取りで浮かせる
    Widget iconWidget = Icon(
      icon,
      color: TopazColors.onSurface,
      size: 28,
      shadows: topazGlowShadows,
    );
    if (flipHorizontally) {
      iconWidget = Transform.scale(scaleX: -1, child: iconWidget);
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Column(
          children: [
            iconWidget,
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: TopazColors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                shadows: topazGlowShadows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5.7万 のような日本語表記に丸める。
String _formatCount(int count) {
  if (count >= 100000000) {
    final oku = count / 100000000;
    return '${oku.toStringAsFixed(oku >= 10 ? 0 : 1)}億';
  }
  if (count >= 10000) {
    final man = count / 10000;
    return '${man.toStringAsFixed(man >= 10 ? 0 : 1)}万';
  }
  return '$count';
}
