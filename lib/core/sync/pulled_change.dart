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
