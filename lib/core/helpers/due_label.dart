import '../../features/items/domain/entities/due_spec.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Zero-padded 24-hour clock, e.g. 570 -> '09:30'.
String fmtClock(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Calendar date form, e.g. 'Thu 12 Nov'.
String dateLabel(DateTime d) =>
    '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// 'Today 17:00', 'Tomorrow 18:00', 'Fri 10:00', 'Thu 12 Nov'.
/// Dates 0-6 days away use words; anything else uses [dateLabel].
String dueLabel(DueSpec due, DateTime now) {
  final diff = DateTime.utc(
    due.date.year,
    due.date.month,
    due.date.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  final String day;
  if (diff == 0) {
    day = 'Today';
  } else if (diff == 1) {
    day = 'Tomorrow';
  } else if (diff >= 2 && diff <= 6) {
    day = _days[due.date.weekday - 1];
  } else {
    day = dateLabel(due.date);
  }
  final m = due.minutes;
  return m == null ? day : '$day ${fmtClock(m)}';
}

/// Overdue as the Up next and list queries define it: due on an earlier
/// day, or today at a time already past. A task due today without a time
/// is not overdue.
bool isOverdue(DueSpec due, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(due.date.year, due.date.month, due.date.day);
  if (day.isBefore(today)) return true;
  final m = due.minutes;
  return day == today && m != null && m < now.hour * 60 + now.minute;
}

/// A row's time (03 `dueLabel`): '17:00' today, 'Today' today without a
/// time, otherwise [dueLabel] ('Tomorrow 10:00', 'Fri 10:00', 'Thu 12 Nov').
String rowDueLabel(DueSpec due, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(due.date.year, due.date.month, due.date.day);
  if (day != today) return dueLabel(due, now);
  final m = due.minutes;
  return m == null ? 'Today' : fmtClock(m);
}
