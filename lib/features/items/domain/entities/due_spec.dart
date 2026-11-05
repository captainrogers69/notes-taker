import 'package:equatable/equatable.dart';

/// Due date (local midnight) plus optional minutes after local midnight.
class DueSpec extends Equatable {
  const DueSpec({required this.date, this.minutes});

  final DateTime date;
  final int? minutes;

  /// Local due DateTime, or null when the item has no time.
  DateTime? at() {
    final m = minutes;
    if (m == null) return null;
    return DateTime(date.year, date.month, date.day, 0, m);
  }

  /// 'yyyy-MM-dd' (local).
  String encodeDate() =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static final _dateRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static DueSpec? decode(String? date, int? minutes) {
    if (date == null) return null;
    final m = _dateRe.firstMatch(date);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final parsed = DateTime(y, mo, d);
    if (parsed.year != y || parsed.month != mo || parsed.day != d) return null;
    return DueSpec(date: parsed, minutes: minutes);
  }

  @override
  List<Object?> get props => [date, minutes];
}
