import 'package:equatable/equatable.dart';
import 'package:weave/core/sync/remote_change.dart';

/// A [RemoteChange] together with its server-assigned sequence number.
class PulledChange extends Equatable {
  const PulledChange({required this.seq, required this.change});

  final int seq;
  final RemoteChange change;

  @override
  List<Object?> get props => [seq, change];
}

/// One page from `SyncTransport.pull`.
///
/// [full] is true when the server returned `limit` raw rows, so more may
/// follow, even if some were malformed and left out of [rows]. [lastSeq] is
/// the highest raw seq on the page (malformed rows included), where the next
/// page starts.
class PulledPage extends Equatable {
  PulledPage(this.rows, {required this.full, int? lastSeq})
    : lastSeq =
          lastSeq ??
          rows.fold<int?>(null, (m, r) => m == null || r.seq > m ? r.seq : m);

  final List<PulledChange> rows;
  final bool full;
  final int? lastSeq;

  @override
  List<Object?> get props => [rows, full, lastSeq];
}
