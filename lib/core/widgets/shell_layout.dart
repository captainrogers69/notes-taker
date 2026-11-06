import 'package:flutter/widgets.dart';

/// Layout facts for pages inside the shell.
class ShellLayout extends InheritedWidget {
  const ShellLayout({
    super.key,
    required this.isPhone,
    required this.padding,
    required super.child,
  });

  /// Phone layout (tab bar, add bar, bottom sheets): width < 720.
  final bool isPhone;

  /// Page padding: desktop canvas 32 32 48 (24 24 48 under 1100 px), phone
  /// body 4 16 24 (app.css `.canvas`, `.pbody`). Pages apply it inside
  /// their scroll view.
  final EdgeInsets padding;

  static ShellLayout of(BuildContext context) {
    final l = context.dependOnInheritedWidgetOfExactType<ShellLayout>();
    assert(l != null, 'No ShellLayout above this page');
    return l ??
        const ShellLayout(
          isPhone: false,
          padding: EdgeInsets.zero,
          child: SizedBox.shrink(),
        );
  }

  @override
  bool updateShouldNotify(ShellLayout old) =>
      old.isPhone != isPhone || old.padding != padding;
}
