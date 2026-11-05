import 'dart:convert';

/// One losing concurrent text edit: its text, the name of the device that
/// wrote it, and its packed HLC (`''` when unknown, e.g. legacy rows).
typedef ConflictLoser = ({String text, String from, String hlc});

/// Reads the local-only `conflict_text` / `conflict_from` columns.
/// `conflict_text` is a JSON array of loser texts; `conflict_from` is
/// `{"from": [names], "hlc": [hlcs]}`, parallel to it. Older forms still
/// read: `conflict_from` as an array of names, or as one plain name for every
/// loser. A `conflict_text` that is not a JSON array of strings is one legacy
/// loser. (A legacy plain string that happens to look like a JSON array of
/// strings is read as that array; no such rows were ever written.) Short
/// lists pad with `''`.
List<ConflictLoser> decodeLosers(String? text, String? from) {
  if (text == null) return const [];
  final texts = _stringList(_decode(text));
  if (texts == null) return [(text: text, from: from ?? '', hlc: '')];
  final decodedFrom = from == null ? null : _decode(from);
  List<String>? names;
  List<String>? hlcs;
  String? plainName;
  if (decodedFrom is Map) {
    names = _stringList(decodedFrom['from']);
    hlcs = _stringList(decodedFrom['hlc']);
  } else {
    names = _stringList(decodedFrom);
    if (names == null) plainName = from;
  }
  String at(List<String>? l, int i) => l != null && i < l.length ? l[i] : '';
  return [
    for (final (i, t) in texts.indexed)
      (text: t, from: plainName ?? at(names, i), hlc: at(hlcs, i)),
  ];
}

/// Column values for [losers], keyed by field name for
/// `ChangeWriter.writeLocalOnly`. No losers → both null.
Map<String, Object?> encodeLosers(List<ConflictLoser> losers) {
  if (losers.isEmpty) return {'conflictText': null, 'conflictFrom': null};
  return {
    'conflictText': jsonEncode([for (final l in losers) l.text]),
    'conflictFrom': jsonEncode({
      'from': [for (final l in losers) l.from],
      'hlc': [for (final l in losers) l.hlc],
    }),
  };
}

Object? _decode(String s) {
  try {
    return jsonDecode(s);
  } on FormatException {
    return null;
  }
}

List<String>? _stringList(Object? decoded) {
  if (decoded is! List || decoded.any((e) => e is! String)) return null;
  return decoded.cast<String>();
}
