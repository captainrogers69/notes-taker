import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/helpers/minute_ticker.dart';

void main() {
  test('ticks on each wall-clock minute, starting at the next :00', () {
    fakeAsync((async) {
      final start = DateTime(2026, 11, 3, 16, 20, 40, 500);
      final ticks = <DateTime>[];
      DateTime now() => start.add(async.elapsed);
      final t = MinuteTicker(() => ticks.add(now()), now: now);
      async.elapse(const Duration(seconds: 19));
      expect(ticks, isEmpty);
      async.elapse(const Duration(milliseconds: 500));
      expect(ticks, [DateTime(2026, 11, 3, 16, 21)]);
      async.elapse(const Duration(minutes: 2));
      expect(ticks.last, DateTime(2026, 11, 3, 16, 23));
      expect(ticks, hasLength(3));
      t.cancel();
      async.elapse(const Duration(minutes: 5));
      expect(ticks, hasLength(3));
    });
  });
}
