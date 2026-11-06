import 'package:flutter/material.dart';

import '../../../../core/theme/weave_theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/weave_icons.dart';
import 'list_more_menu.dart';

/// `.donebar`: "Done · N" with its chevron and Uncheck all; the rows grow
/// from 0 to full height when open (the playbook's one height animation).
class DoneGroup extends StatelessWidget {
  const DoneGroup({
    super.key,
    required this.count,
    required this.open,
    required this.onToggle,
    required this.onUncheckAll,
    required this.ruleColor,
    required this.children,
  });

  final int count;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onUncheckAll;
  final Color ruleColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final still = MediaQuery.disableAnimationsOf(context);
    final dur = still ? Duration.zero : const Duration(milliseconds: 180);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DoneBar(
          ruleColor: ruleColor,
          left: Pressable(
            onTap: onToggle,
            selected: open,
            hoverColor: Colors.transparent,
            child: SizedBox(
              height: 30,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedRotation(
                    turns: open ? 0.25 : 0,
                    duration: dur,
                    curve: t.easeOut,
                    child: WeaveIcon(WeaveIcons.chevRight, color: t.muted),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Done · $count',
                    style: t.numeric.copyWith(
                      fontSize: t.fsSmall,
                      color: t.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          right: ListTextButton(
            label: 'Uncheck all',
            small: true,
            ghost: true,
            onTap: onUncheckAll,
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: dur,
            curve: t.easeOut,
            alignment: Alignment.topCenter,
            child: open
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }
}

/// `.donebar`: 8 above, a tinted rule, 8 below.
class DoneBar extends StatelessWidget {
  const DoneBar({
    super.key,
    required this.ruleColor,
    required this.left,
    required this.right,
  });

  final Color ruleColor;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ruleColor)),
      ),
      child: Row(children: [left, const Spacer(), right]),
    );
  }
}
