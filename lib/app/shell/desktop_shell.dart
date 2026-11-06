import 'package:flutter/material.dart';

import '../../core/theme/weave_theme.dart';
import '../../core/widgets/undo_toast.dart';
import 'app_shell.dart';
import 'shell_actions.dart';
import 'sidebar.dart';

/// Desktop and tablet (≥ 720): sidebar 256 (224 under 1100) · canvas. The
/// window chrome is the OS's own (macOS traffic lights; Windows title bar
/// with the app icon, which is the Weave mark, and "Weave").
class DesktopShell extends StatelessWidget {
  const DesktopShell({
    super.key,
    required this.location,
    required this.actions,
    required this.toast,
    required this.searchFocus,
    required this.search,
    required this.narrow,
    required this.child,
  });

  final ShellLocation location;
  final ShellActions actions;
  final UndoToastController toast;
  final FocusNode searchFocus;
  final TextEditingController search;
  final bool narrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.ground,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: narrow ? t.sidebarWidthNarrow : t.sidebarWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: t.border)),
                  ),
                  child: Sidebar(
                    location: location,
                    actions: actions,
                    searchFocus: searchFocus,
                    search: search,
                  ),
                ),
              ),
              Expanded(child: child),
            ],
          ),
          UndoToastLayer(controller: toast, bottom: 24),
        ],
      ),
    );
  }
}
