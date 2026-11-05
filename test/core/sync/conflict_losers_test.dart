import 'package:flutter_test/flutter_test.dart';
import 'package:weave/core/sync/conflict_losers.dart';

void main() {
  test('losers round-trip with names and hlcs', () {
    final losers = [
      (text: 'a', from: 'Phone', hlc: 'h1'),
      (text: 'multi\nline', from: 'Phone', hlc: 'h2'),
    ];
    final enc = encodeLosers(losers);
    expect(enc['conflictText'], '["a","multi\\nline"]');
    expect(enc['conflictFrom'], '{"from":["Phone","Phone"],"hlc":["h1","h2"]}');
    expect(
      decodeLosers(
        enc['conflictText'] as String?,
        enc['conflictFrom'] as String?,
      ),
      losers,
    );
  });

  test('no losers encodes as nulls and decodes as empty', () {
    expect(encodeLosers([]), {'conflictText': null, 'conflictFrom': null});
    expect(decodeLosers(null, null), isEmpty);
  });

  test('a legacy plain-string value is read as one loser', () {
    expect(decodeLosers('old text', 'Tablet'), [
      (text: 'old text', from: 'Tablet', hlc: ''),
    ]);
    expect(decodeLosers('[not json', null), [
      (text: '[not json', from: '', hlc: ''),
    ]);
    expect(decodeLosers('"quoted"', 'X'), [
      (text: '"quoted"', from: 'X', hlc: ''),
    ]);
  });

  test('older from formats and short lists pad with empty values', () {
    expect(decodeLosers('["a","b"]', '["P"]'), [
      (text: 'a', from: 'P', hlc: ''),
      (text: 'b', from: '', hlc: ''),
    ]);
    expect(decodeLosers('["a"]', 'Legacy'), [
      (text: 'a', from: 'Legacy', hlc: ''),
    ]);
    expect(decodeLosers('["a","b"]', '{"from":["P","Q"],"hlc":["h1"]}'), [
      (text: 'a', from: 'P', hlc: 'h1'),
      (text: 'b', from: 'Q', hlc: ''),
    ]);
  });
}
