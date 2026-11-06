import 'hlc.dart';

/// Local hybrid logical clock for one device (node).
class HlcClock {
  /// [seed] is the last stamp persisted before a restart; the clock never
  /// issues anything at or below it, even if the wall clock went back.
  HlcClock(String node, {int Function()? now, Hlc? seed})
    : _node = node,
      _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
      _last = seed ?? Hlc(0, 0, node);

  String _node;

  /// This device's id. Changes only through [renew].
  String get node => _node;
  final int Function() _now;
  Hlc _last;

  /// The most recent stamp issued (or the seed), for persisting.
  Hlc get last => _last;

  /// Switches to a new device id (sign-out). The next stamp is still strictly
  /// greater than every stamp issued before, under either node: millis and
  /// counter are kept, and [tick] / [receive] always advance the counter or
  /// millis, so a node that sorts lower never makes a stamp go back.
  void renew(String node) {
    _node = node;
    _last = Hlc(_last.millis, _last.counter, node);
  }

  /// Returns a new timestamp strictly greater than every previous one.
  Hlc tick() {
    final wall = _now();
    final millis = wall > _last.millis ? wall : _last.millis;
    final counter = millis == _last.millis ? _last.counter + 1 : 0;
    return _advance(millis, counter);
  }

  /// Merges [remote] and returns the new local timestamp, which is greater
  /// than both the remote and any previous local value.
  Hlc receive(Hlc remote) {
    final wall = _now();
    var millis = wall;
    if (_last.millis > millis) millis = _last.millis;
    if (remote.millis > millis) millis = remote.millis;
    var counter = 0;
    final fromLast = millis == _last.millis;
    final fromRemote = millis == remote.millis;
    if (fromLast && fromRemote) {
      counter =
          (_last.counter > remote.counter ? _last.counter : remote.counter) + 1;
    } else if (fromLast) {
      counter = _last.counter + 1;
    } else if (fromRemote) {
      counter = remote.counter + 1;
    }
    return _advance(millis, counter);
  }

  /// A counter reaching [Hlc.maxCounter] carries into millis, so the clock
  /// stays strictly increasing and never throws (even after a far-future
  /// remote). The clock never issues counter [Hlc.maxCounter] itself, which
  /// the merger treats as malformed.
  Hlc _advance(int millis, int counter) {
    if (counter >= Hlc.maxCounter) return _last = Hlc(millis + 1, 0, _node);
    return _last = Hlc(millis, counter, _node);
  }
}
