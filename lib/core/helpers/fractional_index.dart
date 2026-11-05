const String _digits =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';

/// Returns a key strictly between [before] and [after] in ASCII order.
/// `null` means open-ended. Keys are non-empty base-62 strings with no
/// trailing '0'. Throws [ArgumentError] on invalid keys or if before >= after.
String keyBetween(String? before, String? after) {
  if (before != null) _validate(before);
  if (after != null) _validate(after);
  if (before != null && after != null && before.compareTo(after) >= 0) {
    throw ArgumentError('before must be less than after');
  }
  return _midpoint(before ?? '', after);
}

void _validate(String k) {
  if (k.isEmpty || k.endsWith('0')) {
    throw ArgumentError('Invalid key');
  }
  for (var i = 0; i < k.length; i++) {
    if (!_digits.contains(k[i])) throw ArgumentError('Invalid key');
  }
}

/// [a] is '' or a canonical key; [b] is null or a canonical key; a < b.
String _midpoint(String a, String? b) {
  if (b != null) {
    var n = 0;
    while ((n < a.length ? a[n] : '0') == (n < b.length ? b[n] : '') &&
        n < b.length) {
      n++;
    }
    if (n > 0) {
      return b.substring(0, n) +
          _midpoint(a.length > n ? a.substring(n) : '', b.substring(n));
    }
  }
  final da = a.isEmpty ? 0 : _digits.indexOf(a[0]);
  final db = b == null ? _digits.length : _digits.indexOf(b[0]);
  if (db - da > 1) {
    return _digits[(da + db + 1) ~/ 2];
  }
  if (b != null && b.length > 1) {
    return b[0];
  }
  return _digits[da] + _midpoint(a.length > 1 ? a.substring(1) : '', null);
}
