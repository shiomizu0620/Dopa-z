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
  });

  /// フィルターに出す技術タグ(先頭の「すべて」を除く)。
  final List<String> techs;

  /// 選択中の技術タグ。null は「すべて」。
  final String? selectedTech;

  final ValueChanged<String?> onTechSelected;

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
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
              child: Row(
                children: [
                  const DopazLogo(),
                  const Spacer(),
                  const _HeaderIcon(Icons.search),
                  const _HeaderIcon(Icons.more_vert),
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

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(icon, color: TopazColors.onSurface, size: 26),
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
