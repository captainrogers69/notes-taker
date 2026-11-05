import 'hlc.dart';

/// Local hybrid logical clock for one device (node).
class HlcClock {
  HlcClock(this.node, {int Function()? now})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
      _last = Hlc(0, 0, node);

  final String node;
  final int Function() _now;
  Hlc _last;

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

  Hlc _advance(int millis, int counter) {
    if (counter > Hlc.maxCounter) {
      throw StateError('HLC counter overflow');
    }
    return _last = Hlc(millis, counter, node);
  }
}
