import 'package:flutter/material.dart';

import '../../../../core/theme/note_color.dart';
import '../../../../core/theme/weave_theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/weave_icons.dart';

/// 03 `D.COLOR_NAMES`.
String colorName(NoteColor c) => switch (c) {
  NoteColor.yellow => 'Yellow',
  NoteColor.blue => 'Blue',
  NoteColor.green => 'Green',
  NoteColor.pink => 'Pink',
  NoteColor.purple => 'Purple',
  NoteColor.orange => 'Orange',
};

/// `.dot`: the list colour with an ink edge.
class ListDot extends StatelessWidget {
  const ListDot({super.key, required this.color, this.size = 10});

  final NoteColor color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.fill(b),
        shape: BoxShape.circle,
        border: Border.all(color: color.ink(b)),
      ),
    );
  }
}

/// `.swatches`: the phone sheet's six 28 px colours; the current one ticked.
class ColorSwatches extends StatelessWidget {
  const ColorSwatches({
    super.key,
    required this.selected,
    required this.onPick,
  });

  final NoteColor selected;
  final ValueChanged<NoteColor> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final b = Theme.of(context).brightness;
    return Row(
      children: [
        for (final c in NoteColor.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Pressable(
              onTap: () => onPick(c),
              semanticLabel: colorName(c),
              selected: c == selected,
              radius: 22,
              hoverColor: Colors.transparent,
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.fill(b),
                      shape: BoxShape.circle,
                      border: Border.all(color: c.ink(b)),
                    ),
                    child: c == selected
                        ? WeaveIcon(WeaveIcons.tick, color: t.tick)
                        : null,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
