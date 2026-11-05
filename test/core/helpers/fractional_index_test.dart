import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/helpers/fractional_index.dart';

void main() {
  test('keyBetween(null, null) is non-empty', () {
    expect(keyBetween(null, null), isNotEmpty);
  });

  test('200 random inserts stay strictly ordered', () {
    final rnd = Random(42);
    final keys = <String>[keyBetween(null, null)];
    for (var i = 0; i < 200; i++) {
      final pos = rnd.nextInt(keys.length + 1);
      final a = pos == 0 ? null : keys[pos - 1];
      final b = pos == keys.length ? null : keys[pos];
      final k = keyBetween(a, b);
      if (a != null) expect(a.compareTo(k), lessThan(0), reason: '$a $k');
      if (b != null) expect(k.compareTo(b), lessThan(0), reason: '$k $b');
      expect(k.endsWith('0'), isFalse);
      keys.insert(pos, k);
    }
    final sorted = [...keys]..sort();
    expect(keys, sorted);
    expect(keys.toSet().length, keys.length);
  });

  test('repeated front and back inserts stay ordered', () {
    var first = keyBetween(null, null);
    var last = first;
    for (var i = 0; i < 100; i++) {
      final f = keyBetween(null, first);
      expect(f.compareTo(first), lessThan(0));
      first = f;
      final l = keyBetween(last, null);
      expect(l.compareTo(last), greaterThan(0));
      last = l;
    }
  });

  test('repeated inserts into the same gap stay ordered', () {
    final a = keyBetween(null, null);
    var b = keyBetween(a, null);
    for (var i = 0; i < 100; i++) {
      final k = keyBetween(a, b);
      expect(a.compareTo(k), lessThan(0));
      expect(k.compareTo(b), lessThan(0));
      b = k;
    }
  });

  test('keyBetween(a, null) > a and keyBetween(null, b) < b', () {
    expect(keyBetween('zzz', null).compareTo('zzz'), greaterThan(0));
    expect(keyBetween(null, '1').compareTo('1'), lessThan(0));
    expect(keyBetween(null, '01').compareTo('01'), lessThan(0));
  });

  test('throws ArgumentError if a >= b', () {
    expect(() => keyBetween('b', 'a'), throwsArgumentError);
    expect(() => keyBetween('a', 'a'), throwsArgumentError);
  });

  test('throws ArgumentError on invalid keys', () {
    expect(() => keyBetween('', null), throwsArgumentError);
    expect(() => keyBetween('a-', null), throwsArgumentError);
    expect(() => keyBetween('a0', null), throwsArgumentError);
  });
}
