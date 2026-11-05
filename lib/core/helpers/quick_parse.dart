import 'package:equatable/equatable.dart';

import '../../features/items/domain/entities/due_spec.dart';
import 'due_label.dart';

/// Result of reading a quick-add line: the cleaned text and optional due.
class ParsedCapture extends Equatable {
  const ParsedCapture({required this.text, this.due, this.timerMinutes});

  final String text;
  final DueSpec? due;

  /// Set when the line was a relative timer ("in 2 h").
  final int? timerMinutes;

  @override
  List<Object?> get props => [text, due, timerMinutes];
}

// Trailing whitespace, optionally preceded by punctuation that is consumed.
const _e = r'[.,;:!?]*\s';

RegExp _re(String body, {bool ci = true}) =>
    RegExp('$body$_e', caseSensitive: !ci);

final _tomorrow = _re(r'\s(tomorrow|tmrw)');
final _today = _re(r'\s(today)');
final _weekday = _re(
  r'\s(?:on\s+)?(sun(?:day)?|mon(?:day)?|tue(?:s|sday)?|wed(?:nesday)?|'
  r'thu(?:r|rs|rsday)?|fri(?:day)?|sat(?:urday)?)',
);
final _tonight = _re(r'\s(tonight)');
final _timer = _re(r'\sin\s+(\d{1,3})\s*(h|hr|hrs|hours?|m|min|mins|minutes?)');
final _ampm = _re(r'\s(?:at\s+)?(1[0-2]|0?[1-9])(?::([0-5]\d))?\s*(am|pm)');
final _clock24 = _re(r'\s(?:at\s+)?([01]?\d|2[0-3]):([0-5]\d)', ci: false);

const _dow = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];

/// Port of `parseQuick` in docs/design-02/assets/data.js. Pure: [now] is
/// injected. Returns the raw text and no due when nothing is recognised, or
/// when stripping tokens would leave no text.
ParsedCapture quickParse(String raw, DateTime now) {
  var s = ' $raw ';
  int? d;
  int? t;
  int? timer;
  var tonight = false;
  final nowMin = now.hour * 60 + now.minute;

  RegExpMatch? take(RegExp re) {
    final m = re.firstMatch(s);
    if (m != null) s = '${s.substring(0, m.start)} ${s.substring(m.end)}';
    return m;
  }

  if (take(_tomorrow) != null) d = 1;
  if (take(_today) != null) d = 0;
  final wd = take(_weekday);
  if (wd != null) {
    final target = _dow.indexOf(wd.group(1)!.substring(0, 3).toLowerCase());
    final today = now.weekday % 7; // Sun = 0
    d = ((target - today + 7) % 7);
    if (d == 0) d = 7; // same weekday means next week
  }
  if (take(_tonight) != null) {
    d = 0;
    t = 20 * 60;
    tonight = true;
  }
  final tm = take(_timer);
  if (tm != null) {
    final n = int.parse(tm.group(1)!);
    final mins = tm.group(2)!.toLowerCase().startsWith('h') ? n * 60 : n;
    timer = mins;
    final at = nowMin + mins;
    d = at ~/ 1440;
    t = at % 1440;
  }
  final ap = take(_ampm);
  if (ap != null) {
    var h = int.parse(ap.group(1)!) % 12;
    if (ap.group(3)!.toLowerCase() == 'pm') h += 12;
    t = h * 60 + (int.tryParse(ap.group(2) ?? '') ?? 0);
  }
  final c24 = take(_clock24);
  if (c24 != null) {
    t = int.parse(c24.group(1)!) * 60 + int.parse(c24.group(2)!);
  }

  final text = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t != null && d == null) d = t <= nowMin ? 1 : 0;
  // 'tonight' already past today means tomorrow.
  if (tonight && d == 0 && t != null && t <= nowMin) d = 1;
  if (d == null || text.isEmpty) {
    return ParsedCapture(text: raw.trim());
  }
  return ParsedCapture(
    text: text,
    due: DueSpec(date: DateTime(now.year, now.month, now.day + d), minutes: t),
    timerMinutes: timer,
  );
}

/// Read-back line shown under the add field, e.g. 'Due Tomorrow 18:00'.
String parseReadBack(ParsedCapture p, DateTime now) {
  final due = p.due;
  if (due == null) return '';
  final label = dueLabel(due, now);
  final timer = p.timerMinutes;
  if (timer != null) {
    final span = timer >= 60 && timer % 60 == 0
        ? '${timer ~/ 60} h'
        : '$timer min';
    return 'Reminder in $span · $label';
  }
  return 'Due $label';
}
