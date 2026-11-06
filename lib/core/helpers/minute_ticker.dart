import 'dart:async';

/// Calls [onTick] on every wall-clock minute (hh:mm:00): a one-shot timer
/// to the next minute, then a periodic one. Screens that read "now" (Up
/// next, overdue, the day thread, the sidebar count) turn over with the
/// clock instead of up to a minute late.
class MinuteTicker {
  MinuteTicker(this._onTick, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    final n = _now();
    final next = DateTime(n.year, n.month, n.day, n.hour, n.minute + 1);
    _timer = Timer(next.difference(n), () {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _onTick());
      _onTick();
    });
  }

  final void Function() _onTick;
  final DateTime Function() _now;
  Timer? _timer;

  void cancel() => _timer?.cancel();
}
