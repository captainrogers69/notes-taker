import 'package:flutter/material.dart';
import 'package:weave/core/domain/note_color_id.dart';

export 'package:weave/core/domain/note_color_id.dart';

/// Colour values mirroring `--n0`..`--n5` and `--nX-ink` in tokens.css.
extension NoteColorPalette on NoteColor {
  Color get _fill => switch (this) {
    NoteColor.yellow => const Color(0xFFF5C84C),
    NoteColor.blue => const Color(0xFF6AA6F8),
    NoteColor.green => const Color(0xFF5DC48A),
    NoteColor.pink => const Color(0xFFEE7FA8),
    NoteColor.purple => const Color(0xFFA88BEB),
    NoteColor.orange => const Color(0xFFF29A5B),
  };

  Color get _lightInk => switch (this) {
    NoteColor.yellow => const Color(0xFF876508),
    NoteColor.blue => const Color(0xFF0B65E0),
    NoteColor.green => const Color(0xFF2C784D),
    NoteColor.pink => const Color(0xFFCD1B5D),
    NoteColor.purple => const Color(0xFF794CE0),
    NoteColor.orange => const Color(0xFFAC4F0E),
  };

  /// Dots, check fill, thread marks, paper. Same in both modes.
  Color fill(Brightness b) => _fill;

  /// Edge / text-safe shade. Light: darker ink. Dark: ink equals fill.
  Color ink(Brightness b) => b == Brightness.light ? _lightInk : _fill;
}
