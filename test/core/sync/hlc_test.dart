import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/sync/hlc.dart';
import 'package:weave/core/sync/hlc_clock.dart';

void main() {
  test('tick is strictly increasing when wall time stands still', () {
    final clock = HlcClock('node-a', now: () => 1000);
    final a = clock.tick();
    final b = clock.tick();
    final c = clock.tick();
    expect(a.compareTo(b), lessThan(0));
    expect(b.compareTo(c), lessThan(0));
  });

  test('tick follows wall time when it moves forward and resets counter', () {
    var t = 1000;
    final clock = HlcClock('n', now: () => t);
    clock.tick();
    clock.tick();
    t = 2000;
    final h = clock.tick();
    expect(h.millis, 2000);
    expect(h.counter, 0);
  });

  test('pack/parse round-trip and string order equals compare order', () {
    final rnd = Random(7);
    final list = List.generate(
      50,
      (_) => Hlc(
        rnd.nextInt(1 << 30) * 1000 + rnd.nextInt(1000),
        rnd.nextInt(100000),
        'node-${rnd.nextInt(3)}',
      ),
    );
    for (final h in list) {
      final p = Hlc.parse(h.pack());
      expect(p.millis, h.millis);
      expect(p.counter, h.counter);
      expect(p.node, h.node);
      expect(p, h);
    }
    for (final x in list) {
      for (final y in list) {
        expect(x.pack().compareTo(y.pack()).sign, x.compareTo(y).sign);
      }
    }
  });

  test('pack format is fixed width', () {
    expect(Hlc(5, 3, 'n').pack(), '000000000000005-00003-n');
  });

  test('parse keeps dashes inside node (uuid)', () {
    const node = '0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b';
    expect(Hlc.parse(Hlc(1, 2, node).pack()).node, node);
  });

  test('parse rejects malformed input', () {
    for (final s in [
      '',
      'garbage',
      '1-2-n',
      '00000000000000x-00001-n',
      '000000000000001-0001-n',
      '000000000000001-00001-',
      '000000000000001-00001',
      '-00000000000001-00001-n',
    ]) {
      expect(() => Hlc.parse(s), throwsFormatException, reason: s);
    }
  });

  test('receive moves clock past a remote clock that is ahead', () {
    final clock = HlcClock('local', now: () => 1000);
    final remote = Hlc(3600000, 4, 'remote');
    final merged = clock.receive(remote);
    expect(merged.compareTo(remote), greaterThan(0));
    final next = clock.tick();
    expect(next.compareTo(remote), greaterThan(0));
    expect(next.compareTo(merged), greaterThan(0));
  });

  test('receive with remote behind keeps local monotonic', () {
    final clock = HlcClock('local', now: () => 1000);
    final prev = clock.tick();
    final merged = clock.receive(Hlc(10, 0, 'remote'));
    expect(merged.compareTo(prev), greaterThan(0));
    expect(clock.tick().compareTo(merged), greaterThan(0));
  });

  test('receive with equal millis takes max counter plus one', () {
    final clock = HlcClock('a', now: () => 1000);
    clock.tick(); // 1000/0
    final merged = clock.receive(Hlc(1000, 7, 'b'));
    expect(merged.millis, 1000);
    expect(merged.counter, 8);
  });

  test('ties compare by node', () {
    expect(Hlc(1, 1, 'a').compareTo(Hlc(1, 1, 'b')), lessThan(0));
    expect(Hlc(1, 1, 'a').compareTo(Hlc(1, 1, 'a')), 0);
  });

  test('counter overflow in tick carries into millis', () {
    final clock = HlcClock('n', now: () => 1000);
    expect(clock.receive(Hlc(1000, 99997, 'r')).counter, 99998);
    final next = clock.tick();
    expect((next.millis, next.counter), (1001, 0));
  });

  test('counter overflow in receive carries into millis', () {
    final clock = HlcClock('n', now: () => 1000);
    final got = clock.receive(Hlc(1000, 99998, 'r'));
    expect((got.millis, got.counter), (1001, 0));
  });

  test('a far-future remote clock never makes tick throw', () {
    final clock = HlcClock('n', now: () => 1000);
    var prev = clock.receive(Hlc.parse('999999999999999-99998-x'));
    for (var i = 0; i < 200000; i++) {
      final next = clock.tick();
      expect(next.compareTo(prev), greaterThan(0));
      expect(next.counter, lessThan(Hlc.maxCounter));
      prev = next;
    }
  });

  test('renew changes the node and stays monotonic', () {
    // 'zzz' sorts after 'aaa': a naive node swap would go backwards.
    final clock = HlcClock('zzz', now: () => 1000);
    final stamps = [clock.tick(), clock.tick()];
    clock.renew('aaa');
    expect(clock.node, 'aaa');
    expect(clock.last.node, 'aaa');
    stamps
      ..add(clock.tick())
      ..add(clock.receive(Hlc(1000, 0, 'other')));
    expect(stamps[2].node, 'aaa');
    for (var i = 1; i < stamps.length; i++) {
      expect(stamps[i].compareTo(stamps[i - 1]), greaterThan(0), reason: '$i');
    }
  });
}
