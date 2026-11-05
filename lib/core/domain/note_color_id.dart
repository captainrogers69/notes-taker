/// Note palette identity (F7). Pure Dart so the domain layer can use it.
/// Colour values live in `lib/core/theme/note_color.dart` as an extension.
/// New lists cycle through the palette in order; the first value is the default.
enum NoteColor {
  yellow, // --n0
  blue, // --n1
  green, // --n2
  pink, // --n3
  purple, // --n4
  orange; // --n5

  String get apiValue => name;

  static NoteColor fromApi(String? v) => NoteColor.values.firstWhere(
    (c) => c.name == v,
    orElse: () => NoteColor.values.first,
  );
}
