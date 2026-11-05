import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/helpers/due_label.dart';
import 'package:weave/core/helpers/quick_parse.dart';
import 'package:weave/features/items/domain/entities/due_spec.dart';

void main() {
  final now = DateTime(2026, 11, 5, 15); // Thursday

  DateTime? at(String raw) => quickParse(raw, now).due?.at();

  test('tomorrow 6pm', () {
    final p = quickParse('call mom tomorrow 6pm', now);
    expect(p.text, 'call mom');
    expect(p.due?.at(), DateTime(2026, 11, 6, 18));
  });
  test('weekday fri 10am', () {
    final p = quickParse('dentist fri 10am', now);
    expect(p.text, 'dentist');
    expect(p.due?.at(), DateTime(2026, 11, 6, 10));
  });
  test(
    'tonight',
    () => expect(at('buy milk tonight'), DateTime(2026, 11, 5, 20)),
  );
  test(
    'past time rolls to tomorrow',
    () => expect(at('standup 9:30'), DateTime(2026, 11, 6, 9, 30)),
  );
  test(
    '24h today',
    () => expect(at('review 18:00'), DateTime(2026, 11, 5, 18)),
  );
  test('in 2 h', () => expect(at('stretch in 2 h'), DateTime(2026, 11, 5, 17)));
  test('in 30 min', () {
    final p = quickParse('tea in 30 min', now);
    expect(p.text, 'tea');
    expect(p.due?.at(), DateTime(2026, 11, 5, 15, 30));
    expect(p.timerMinutes, 30);
  });
  test('plain task', () {
    final p = quickParse('plain task', now);
    expect(p.due, isNull);
    expect(p.text, 'plain task');
  });
  test('6:30pm', () {
    final p = quickParse('dinner 6:30pm', now);
    expect(p.text, 'dinner');
    expect(p.due?.at(), DateTime(2026, 11, 5, 18, 30));
  });
  test('case-insensitive', () {
    final p = quickParse('Call TOMORROW 9AM', now);
    expect(p.text, 'Call');
    expect(p.due?.at(), DateTime(2026, 11, 6, 9));
  });
  test('short weekday mon', () {
    final p = quickParse('gym mon', now);
    expect(p.text, 'gym');
    expect(p.due, DueSpec(date: DateTime(2026, 11, 9)));
  });
  test('weekday equal to today means next week', () {
    expect(quickParse('x thu', now).due?.date, DateTime(2026, 11, 12));
  });
  test('weekday words are not matched inside other words', () {
    expect(quickParse('fix monitor', now).due, isNull);
  });
  test('text-only input with day word only keeps raw text', () {
    final p = quickParse('tomorrow', now);
    expect(p.text, 'tomorrow');
    expect(p.due, isNull);
  });
  test('input that is only a time token keeps raw text', () {
    final p = quickParse('6pm', now);
    expect(p.text, '6pm');
    expect(p.due, isNull);
  });
  test('time without date and day without time', () {
    final p = quickParse('pay rent tomorrow', now);
    expect(p.text, 'pay rent');
    expect(p.due, DueSpec(date: DateTime(2026, 11, 6)));
  });
  test('timer crossing midnight', () {
    expect(at('call in 10 h'), DateTime(2026, 11, 6, 1));
  });

  group('labels', () {
    test('dueLabel forms', () {
      expect(
        dueLabel(DueSpec(date: DateTime(2026, 11, 12)), now),
        'Thu 12 Nov',
      );
      expect(
        dueLabel(DueSpec(date: DateTime(2026, 11, 5), minutes: 1020), now),
        'Today 17:00',
      );
      expect(
        dueLabel(DueSpec(date: DateTime(2026, 11, 6), minutes: 1080), now),
        'Tomorrow 18:00',
      );
      expect(
        dueLabel(DueSpec(date: DateTime(2026, 11, 11), minutes: 600), now),
        'Wed 10:00',
      );
      expect(
        dueLabel(DueSpec(date: DateTime(2026, 11, 7), minutes: 570), now),
        'Sat 09:30',
      );
    });
    test('parseReadBack', () {
      expect(
        parseReadBack(quickParse('call mom tomorrow 6pm', now), now),
        'Due Tomorrow 18:00',
      );
      expect(parseReadBack(quickParse('plain', now), now), '');
      expect(
        parseReadBack(quickParse('tea in 30 min', now), now),
        'Reminder in 30 min · Today 15:30',
      );
    });
  });
}
