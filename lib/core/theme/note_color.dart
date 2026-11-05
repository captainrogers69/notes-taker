import 'package:flutter/material.dart';

/// Note palette (F7), mirroring `--n0`..`--n5` and `--nX-ink` in tokens.css.
/// New lists cycle through the palette in order; the first value is the default.
enum NoteColor {
  yellow(Color(0xFFF5C84C), Color(0xFF876508)), // --n0
  blue(Color(0xFF6AA6F8), Color(0xFF0B65E0)), // --n1
  green(Color(0xFF5DC48A), Color(0xFF2C784D)), // --n2
  pink(Color(0xFFEE7FA8), Color(0xFFCD1B5D)), // --n3
  purple(Color(0xFFA88BEB), Color(0xFF794CE0)), // --n4
  orange(Color(0xFFF29A5B), Color(0xFFAC4F0E)); // --n5

  const NoteColor(this._fill, this._lightInk);

  final Color _fill;
  final Color _lightInk;

  /// Dots, check fill, thread marks, paper. Same in both modes.
  Color fill(Brightness b) => _fill;

  /// Edge / text-safe shade. Light: darker ink. Dark: ink equals fill.
  Color ink(Brightness b) => b == Brightness.light ? _lightInk : _fill;

  String get apiValue => name;

  static NoteColor fromApi(String? v) => NoteColor.values.firstWhere(
    (c) => c.name == v,
    orElse: () => NoteColor.values.first,
  );
}
