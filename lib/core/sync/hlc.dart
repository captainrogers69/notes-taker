/// Hybrid logical clock timestamp. The packed form sorts as a string in the
/// same order as [compareTo] (for equal-length node strings and nodes without
/// ordering surprises, node ties are compared as plain strings).
class Hlc implements Comparable<Hlc> {
  const Hlc(this.millis, this.counter, this.node);

  static const int maxCounter = 99999;

  final int millis;
  final int counter;
  final String node;

  String pack() =>
      '${millis.toString().padLeft(15, '0')}-'
      '${counter.toString().padLeft(5, '0')}-$node';

  static final RegExp _format = RegExp(r'^(\d{15})-(\d{5})-(.+)$');

  /// Parses a packed HLC; throws [FormatException] when malformed.
  static Hlc parse(String s) {
    final m = _format.firstMatch(s);
    if (m == null) throw FormatException('Invalid HLC', s.length);
    final millis = int.tryParse(m.group(1) ?? '');
    final counter = int.tryParse(m.group(2) ?? '');
    final node = m.group(3);
    if (millis == null || counter == null || node == null) {
      throw FormatException('Invalid HLC', s.length);
    }
    return Hlc(millis, counter, node);
  }

  @override
  int compareTo(Hlc other) {
    final byMillis = millis.compareTo(other.millis);
    if (byMillis != 0) return byMillis;
    final byCounter = counter.compareTo(other.counter);
    if (byCounter != 0) return byCounter;
    return node.compareTo(other.node);
  }

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.millis == millis &&
      other.counter == counter &&
      other.node == node;

  @override
  int get hashCode => Object.hash(millis, counter, node);

  @override
  String toString() => pack();
}
