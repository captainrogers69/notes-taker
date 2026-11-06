import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../theme/weave_theme.dart';
import 'pressable.dart';

/// The Undo toast (design playbook §9 Undo, F10): 4 s, bottom centre (above
/// the add bar on phones), on the primary colour. One at a time: a new
/// toast replaces the text of a visible one and restarts the 4 s.
abstract final class UndoToast {
  static const visibleFor = Duration(seconds: 4);

  /// Shows [message] with an Undo button that calls [undo] (none when
  /// [undo] is null). Needs an [UndoToastScope] above [context] (the app
  /// shell provides one); without it nothing is shown.
  static void show(
    BuildContext context,
    String message, [
    Future<void> Function()? undo,
  ]) {
    final scope = context
        .getInheritedWidgetOfExactType<UndoToastScope>()
        ?.controller;
    assert(scope != null, 'UndoToast.show needs an UndoToastScope');
    scope?.show(message, undo);
  }
}

class ToastEntry {
  const ToastEntry(this.message, this.undo);

  final String message;
  final Future<void> Function()? undo;
}

/// State of the one toast. Owned by the app shell.
class UndoToastController extends ChangeNotifier {
  UndoToastController({void Function(String message)? log})
    : _log = log ?? ((m) => developer.log(m, name: 'Toast'));

  /// The toast's exit: a 150 ms fade, no drop (motion table, "Toast").
  static const exitDuration = Duration(milliseconds: 150);

  final void Function(String) _log;
  ToastEntry? _entry;
  bool _visible = false;
  int _enters = 0;
  Timer? _hideTimer;
  Timer? _clearTimer;
  bool _disposed = false;

  /// What is on screen (also while it fades out); null when nothing is.
  ToastEntry? get entry => _entry;

  bool get visible => _visible;

  /// Counts entrances from hidden, so a toast replacing a visible one does
  /// not replay the rise.
  int get enters => _enters;

  void show(String message, Future<void> Function()? undo) {
    if (_disposed) return;
    _clearTimer?.cancel();
    if (!_visible) _enters++;
    _entry = ToastEntry(message, undo);
    _visible = true;
    _hideTimer?.cancel();
    _hideTimer = Timer(UndoToast.visibleFor, hide);
    notifyListeners();
  }

  /// Starts the exit fade; the entry is dropped when it ends (a timer, not
  /// the animation's end callback).
  void hide({Duration fade = exitDuration}) {
    _hideTimer?.cancel();
    if (_disposed || !_visible) return;
    _visible = false;
    notifyListeners();
    _clearTimer?.cancel();
    _clearTimer = Timer(fade, () {
      if (_disposed) return;
      _entry = null;
      notifyListeners();
    });
  }

  /// Undo: runs the entry's undo and fades the toast out.
  /// Runs at most once per toast: a second tap, or Enter on the button
  /// while it fades out, does nothing.
  void undo() {
    // hide() clears [visible] first, so this runs once per toast.
    if (_disposed || !_visible) return;
    final run = _entry?.undo;
    hide();
    if (run == null) return;
    unawaited(
      Future.sync(run).catchError((Object e) {
        _log('undo failed: ${e.runtimeType}');
      }),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _hideTimer?.cancel();
    _clearTimer?.cancel();
    super.dispose();
  }
}

/// Provides the shell's [UndoToastController] to [UndoToast.show].
class UndoToastScope extends InheritedWidget {
  const UndoToastScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final UndoToastController controller;

  @override
  bool updateShouldNotify(UndoToastScope old) => old.controller != controller;
}

/// Draws the toast of [controller], centred horizontally at the bottom of
/// the area it is given ([bottom] above it). The shell places it: bottom 24
/// of the window on desktop, just above the add bar on phones.
class UndoToastLayer extends HookWidget {
  const UndoToastLayer({
    super.key,
    required this.controller,
    required this.bottom,
  });

  final UndoToastController controller;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    useListenable(controller);
    final entry = controller.entry;
    if (entry == null) return const SizedBox.shrink();
    final t = context.tokens;
    final still = MediaQuery.disableAnimationsOf(context);
    final text = Theme.of(context).textTheme.bodyMedium;
    final visible = controller.visible;
    final undo = entry.undo;
    final toast = Container(
      height: 44,
      padding: EdgeInsets.only(left: 16, right: undo == null ? 16 : 8),
      decoration: BoxDecoration(
        color: t.primary,
        borderRadius: BorderRadius.circular(t.radiusCard),
        boxShadow: t.floatShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              entry.message,
              style: text?.copyWith(color: t.onPrimary),
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
          if (undo != null) ...[
            const SizedBox(width: 16),
            Pressable(
              onTap: controller.undo,
              hoverColor: Colors.transparent,
              ringColor: t.onPrimary,
              child: SizedBox(
                height: 32,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      'Undo',
                      style: text?.copyWith(
                        color: t.onPrimary,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationColor: t.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom,
      child: Center(
        child: IgnorePointer(
          ignoring: !visible,
          child: Semantics(
            liveRegion: true,
            container: true,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              // Enter: fade with --dur; exit: 150 ms fade.
              duration: still
                  ? Duration.zero
                  : visible
                  ? t.dur
                  : UndoToastController.exitDuration,
              curve: t.easeOut,
              // Enter rises 16 px over 200 ms; a replaced or leaving toast
              // does not move (keyed by entrance).
              child: TweenAnimationBuilder<double>(
                key: ValueKey(controller.enters),
                tween: Tween(begin: still ? 0 : 16, end: 0),
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: t.easeOut,
                builder: (context, dy, child) =>
                    Transform.translate(offset: Offset(0, dy), child: child),
                child: toast,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
