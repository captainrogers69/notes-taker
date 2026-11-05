import 'package:equatable/equatable.dart';

/// When to remind: at the due time, a fixed offset before it, or at a
/// floating local wall-clock time (no zone, F4.8).
sealed class ReminderSpec extends Equatable {
  const ReminderSpec();

  /// Encoded as `due`, `before:MINUTES` or `at:yyyy-MM-ddTHH:mm`.
  String encode();

  static final _atRe = RegExp(r'^at:(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$');
  static final _beforeRe = RegExp(r'^before:(\d+)$');

  static ReminderSpec? decode(String s) {
    if (s == 'due') return const AtDue();
    final b = _beforeRe.firstMatch(s);
    if (b != null) {
      final n = int.tryParse(b.group(1)!);
      return n == null ? null : Before(Duration(minutes: n));
    }
    final a = _atRe.firstMatch(s);
    if (a != null) {
      final p = [for (var i = 1; i <= 5; i++) int.parse(a.group(i)!)];
      final dt = DateTime(p[0], p[1], p[2], p[3], p[4]);
      if (dt.year != p[0] ||
          dt.month != p[1] ||
          dt.day != p[2] ||
          dt.hour != p[3] ||
          dt.minute != p[4]) {
        return null;
      }
      return AtTime(dt);
    }
    return null;
  }
}

class AtDue extends ReminderSpec {
  const AtDue();

  @override
  String encode() => 'due';

  @override
  List<Object?> get props => const [];
}

class Before extends ReminderSpec {
  const Before(this.offset);

  final Duration offset;

  @override
  String encode() => 'before:${offset.inMinutes}';

  @override
  List<Object?> get props => [offset];
}

class AtTime extends ReminderSpec {
  const AtTime(this.local);

  final DateTime local;

  @override
  String encode() {
    String p(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    return 'at:${p(local.year, 4)}-${p(local.month)}-${p(local.day)}'
        'T${p(local.hour)}:${p(local.minute)}';
  }

  @override
  List<Object?> get props => [
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
  ];
}
