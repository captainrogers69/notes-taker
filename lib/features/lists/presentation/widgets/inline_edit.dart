import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// A field's link to its stored text. Typing is saved after a short pause,
/// and at once when the app goes to the background or quits. While the field
/// has nothing unsaved it follows the store, so a change from another device
/// shows at once and is never written back over.
class InlineEdit {
  InlineEdit(this.controller, this.baseline, this._stored);

  static const pause = Duration(milliseconds: 500);

  final TextEditingController controller;
  final String Function(String) _stored;
  late Future<void> Function(String) write;

  /// The text this field and the store last agreed on.
  String baseline;
  final _own = <String>{};
  String? _lastSent;
  Timer? _timer;

  bool get dirty => controller.text != baseline;

  /// Writes what was typed, unless it is blank: what blank means is up to
  /// the field, when it is left.
  Future<void> save() async {
    _timer?.cancel();
    final text = controller.text;
    if (!dirty || text.trim().isEmpty) return;
    baseline = text;
    _lastSent = _stored(text);
    _own.add(_lastSent!);
    await write(text);
  }

  /// Puts [text] in the field, as if the store had always said so.
  void reset(String text) {
    _timer?.cancel();
    baseline = text;
    controller.text = text;
  }

  /// The store now says [text].
  void arrived(String text) {
    if (_own.contains(text)) {
      // The echo of a save. Older echoes must not undo newer typing.
      if (text == _lastSent) _own.clear();
      return;
    }
    _own.clear();
    settle(text);
  }

  /// Follows the store if nothing here is unsaved or still on its way.
  void settle(String text) {
    if (dirty || _own.isNotEmpty || controller.text == text) return;
    baseline = text;
    final caret = controller.selection.baseOffset;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: caret < 0 || caret > text.length ? text.length : caret,
      ),
    );
  }

  void _typed() {
    _timer?.cancel();
    if (dirty) _timer = Timer(pause, () => unawaited(save()));
  }
}

/// [stored] is what [write] keeps of a text, when that is not all of it.
InlineEdit useInlineEdit({
  required String text,
  required TextEditingController controller,
  required Future<void> Function(String) write,
  String Function(String)? stored,
}) {
  final edit = useMemoized(
    () => InlineEdit(controller, text, stored ?? (s) => s),
  );
  edit.write = write;
  useEffect(() {
    edit.arrived(text);
    return null;
  }, [text]);
  useEffect(() {
    controller.addListener(edit._typed);
    final life = AppLifecycleListener(
      onStateChange: (s) {
        if (s != AppLifecycleState.resumed) unawaited(edit.save());
      },
      onExitRequested: () async {
        await edit.save();
        return AppExitResponse.exit;
      },
    );
    return () {
      life.dispose();
      controller.removeListener(edit._typed);
      edit._timer?.cancel();
    };
  }, [edit]);
  return edit;
}

/// False while the app is in the background: focus leaving a field then is
/// not the person leaving it, and it comes back on return.
bool get appActive {
  final s = WidgetsBinding.instance.lifecycleState;
  return s == null || s == AppLifecycleState.resumed;
}
