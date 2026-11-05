import 'package:flutter_test/flutter_test.dart';
import 'package:weave/features/items/domain/entities/due_spec.dart';
import 'package:weave/features/items/domain/entities/reminder_spec.dart';
import 'package:weave/features/items/domain/entities/repeat_rule.dart';

void main() {
  group('DueSpec', () {
    test('round-trips date only and date with minutes', () {
      final a = DueSpec(date: DateTime(2026, 11, 6));
      expect(DueSpec.decode(a.encodeDate(), null), a);
      expect(a.encodeDate(), '2026-11-06');
      expect(a.at(), isNull);
      final b = DueSpec(date: DateTime(2026, 11, 6), minutes: 9 * 60 + 5);
      expect(DueSpec.decode('2026-11-06', 545), b);
      expect(b.at(), DateTime(2026, 11, 6, 9, 5));
    });

    test('null or invalid date decodes to null', () {
      expect(DueSpec.decode(null, 10), isNull);
      expect(DueSpec.decode('garbage', null), isNull);
      expect(DueSpec.decode('2026-13-40', null), isNull);
    });
  });

  group('ReminderSpec', () {
    test('round-trips every variant', () {
      final specs = <ReminderSpec>[
        const AtDue(),
        const Before(Duration(minutes: 15)),
        AtTime(DateTime(2026, 11, 6, 8, 30)),
      ];
      for (final s in specs) {
        expect(ReminderSpec.decode(s.encode()), s);
      }
      expect(const AtDue().encode(), 'due');
      expect(const Before(Duration(minutes: 15)).encode(), 'before:15');
      expect(
        AtTime(DateTime(2026, 11, 6, 8, 30)).encode(),
        'at:2026-11-06T08:30',
      );
    });

    test('garbage decodes to null', () {
      expect(ReminderSpec.decode('garbage'), isNull);
      expect(ReminderSpec.decode('before:x'), isNull);
      expect(ReminderSpec.decode('at:nope'), isNull);
      expect(ReminderSpec.decode(''), isNull);
    });
  });

  group('RepeatRule', () {
    test('round-trips and rejects bad input', () {
      for (final s in ['day:1', 'weekdays', 'week:2', 'month:1']) {
        expect(RepeatRule.decode(s)?.encode(), s);
      }
      expect(RepeatRule.decode('garbage'), isNull);
      expect(RepeatRule.decode('day:0'), isNull);
      expect(RepeatRule.decode('day:-2'), isNull);
      expect(RepeatRule.decode('year:1'), isNull);
    });

    test('weekdays from Friday goes to Monday keeping time', () {
      final from = DueSpec(date: DateTime(2026, 11, 6), minutes: 540);
      final next = const RepeatRule(RepeatUnit.weekdays, 1).next(from);
      expect(next, DueSpec(date: DateTime(2026, 11, 9), minutes: 540));
    });

    test('weekdays from Monday goes to Tuesday', () {
      final next = const RepeatRule(
        RepeatUnit.weekdays,
        1,
      ).next(DueSpec(date: DateTime(2026, 11, 9)));
      expect(next.date, DateTime(2026, 11, 10));
    });

    test('month clamps to month end', () {
      final next = const RepeatRule(
        RepeatUnit.month,
        1,
      ).next(DueSpec(date: DateTime(2026, 1, 31)));
      expect(next.date, DateTime(2026, 2, 28));
    });

    test('month crosses year', () {
      final next = const RepeatRule(
        RepeatUnit.month,
        2,
      ).next(DueSpec(date: DateTime(2026, 12, 31)));
      expect(next.date, DateTime(2027, 2, 28));
    });

    test('day and week add days', () {
      final d = DueSpec(date: DateTime(2026, 11, 5));
      expect(
        const RepeatRule(RepeatUnit.day, 3).next(d).date,
        DateTime(2026, 11, 8),
      );
      expect(
        const RepeatRule(RepeatUnit.week, 2).next(d).date,
        DateTime(2026, 11, 19),
      );
    });
  });
}
