import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/weave_theme.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/weave_icons.dart';
import '../router.dart';

/// The phone tab bar: Up next · Lists · Search · Settings (app.css
/// `.ptabs`). iOS: surface, 1 px border above, 11 px labels, the current
/// tab's icon drawn heavier (stroke 2). Android (Material): ground, no
/// border, 12 px labels, a `raised` pill behind the current icon. Other
/// platforms in a narrow window: the iOS bar without the heavier icon.
/// The Up next icon carries today's open count.
class PhoneTabBar extends StatelessWidget {
  const PhoneTabBar({
    super.key,
    required this.current,
    required this.upNextCount,
    required this.onSelect,
    this.platform,
  });

  /// [AppRoute.upNext], [AppRoute.lists], [AppRoute.search] or
  /// [AppRoute.settings].
  final AppRoute current;
  final int upNextCount;
  final ValueChanged<AppRoute> onSelect;
  final TargetPlatform? platform;

  static const tabs = [
    (AppRoute.upNext, WeaveIcons.sun, 'Up next'),
    (AppRoute.lists, WeaveIcons.list, 'Lists'),
    (AppRoute.search, WeaveIcons.search, 'Search'),
    (AppRoute.settings, WeaveIcons.gear, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = platform ?? defaultTargetPlatform;
    final material = p == TargetPlatform.android || p == TargetPlatform.fuchsia;
    // The keyboard covers the gesture bar and home indicator.
    final inset = MediaQuery.viewInsetsOf(context).bottom > 0
        ? 0.0
        : MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: material ? t.ground : t.surface,
        border: material ? null : Border(top: BorderSide(color: t.border)),
      ),
      // Android: 80 high with 14 below for the gesture bar; iOS: 49 plus
      // the home indicator. Real insets replace the prototype's.
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: material ? 66 : 49,
        child: Row(
          children: [
            for (final (route, icon, label) in tabs)
              Expanded(
                child: _Tab(
                  icon: icon,
                  label: label,
                  selected: route == current,
                  material: material,
                  heavy: p == TargetPlatform.iOS,
                  badge: route == AppRoute.upNext && upNextCount > 0
                      ? upNextCount
                      : null,
                  onTap: () => onSelect(route),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.material,
    required this.heavy,
    required this.badge,
    required this.onTap,
  });

  final WeaveIcons icon;
  final String label;
  final bool selected;
  final bool material;
  final bool heavy;
  final int? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tt = Theme.of(context).textTheme;
    final color = selected ? t.text : t.muted;
    final n = badge;
    final glyph = WeaveIcon(
      icon,
      size: 24,
      color: color,
      strokeWidth: selected && heavy ? 2 : 1.5,
    );
    // Android: a 64×32 pill (radius 16), `raised` when current.
    final ic = material
        ? Container(
            width: 64,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? t.raised : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: glyph,
          )
        : glyph;
    return Pressable(
      onTap: onTap,
      selected: selected,
      hoverColor: Colors.transparent,
      radius: 0,
      semanticLabel: n == null ? label : '$label, $n',
      child: ExcludeSemantics(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ic,
                if (n != null)
                  Positioned(
                    // `.badge`: iOS top -3 left 15; Android top 0 left 34.
                    top: material ? 0 : -3,
                    left: material ? 34 : 15,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: t.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$n',
                        style: tt.labelSmall
                            ?.merge(t.numeric)
                            .copyWith(fontSize: 10, color: t.onPrimary),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: material ? 4 : 2),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: tt.labelMedium?.copyWith(
                fontSize: material ? 12 : 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
