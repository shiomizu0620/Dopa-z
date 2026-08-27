import 'package:flutter/material.dart';

import '../theme.dart';
import 'dopaz_logo.dart';

/// フィード上部のヘッダー。タイトル行と技術タグのフィルターチップ行。
class FeedTopBar extends StatelessWidget {
  const FeedTopBar({
    super.key,
    required this.techs,
    required this.selectedTech,
    required this.onTechSelected,
    this.showMockBadge = false,
  });

  /// フィルターに出す技術タグ(先頭の「すべて」を除く)。
  final List<String> techs;

  /// 選択中の技術タグ。null は「すべて」。
  final String? selectedTech;

  final ValueChanged<String?> onTechSelected;

  /// 実APIではなくサンプルデータを表示していることを示すバッジを出すか。
  final bool showMockBadge;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TopazColors.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(
                children: [
                  const DopazLogo(),
                  if (showMockBadge) ...[
                    const SizedBox(width: 8),
                    const _MockBadge(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: techs.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _FilterChip(
                      label: 'すべて',
                      selected: selectedTech == null,
                      onTap: () => onTechSelected(null),
                    );
                  }
                  final tech = techs[index - 1];
                  return _FilterChip(
                    label: tech,
                    selected: selectedTech == tech,
                    onTap: () => onTechSelected(tech),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 1, color: TopazColors.border),
          ],
        ),
      ),
    );
  }
}

/// 実APIに接続できない環境でサンプルデータを出していることを示すバッジ。
class _MockBadge extends StatelessWidget {
  const _MockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: TopazColors.cyanSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'SAMPLE',
        style: TextStyle(
          color: TopazColors.deep,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? TopazColors.cyan : TopazColors.cyanSurface,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : TopazColors.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
