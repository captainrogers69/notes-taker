import 'package:equatable/equatable.dart';
import 'package:weave/features/items/domain/entities/due_spec.dart';

enum RepeatUnit { day, weekdays, week, month }

class RepeatRule extends Equatable {
  const RepeatRule(this.unit, this.every);

  final RepeatUnit unit;

  /// Ignored for [RepeatUnit.weekdays].
  final int every;

  /// 'day:1' | 'weekdays' | 'week:2' | 'month:1'
  String encode() =>
      unit == RepeatUnit.weekdays ? 'weekdays' : '${unit.name}:$every';

  static RepeatRule? decode(String s) {
    if (s == 'weekdays') return const RepeatRule(RepeatUnit.weekdays, 1);
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final n = int.tryParse(parts[1]);
    if (n == null || n <= 0) return null;
    return switch (parts[0]) {
      'day' => RepeatRule(RepeatUnit.day, n),
      'week' => RepeatRule(RepeatUnit.week, n),
      'month' => RepeatRule(RepeatUnit.month, n),
      _ => null,
    };
  }

  /// Next occurrence after [from]; keeps the time of day.
  DueSpec next(DueSpec from) {
    final d = from.date;
    final DateTime date;
    switch (unit) {
      case RepeatUnit.day:
        date = DateTime(d.year, d.month, d.day + every);
      case RepeatUnit.week:
        date = DateTime(d.year, d.month, d.day + 7 * every);
      case RepeatUnit.weekdays:
        final skip = switch (d.weekday) {
          DateTime.friday => 3,
          DateTime.saturday => 2,
          _ => 1,
        };
        date = DateTime(d.year, d.month, d.day + skip);
      case RepeatUnit.month:
        final total = d.year * 12 + (d.month - 1) + every;
        final y = total ~/ 12;
        final m = total % 12 + 1;
        final last = DateTime(y, m + 1, 0).day;
        date = DateTime(y, m, d.day > last ? last : d.day);
    }
    return DueSpec(date: date, minutes: from.minutes);
  }

  @override
  List<Object?> get props => [unit, unit == RepeatUnit.weekdays ? 1 : every];
}
