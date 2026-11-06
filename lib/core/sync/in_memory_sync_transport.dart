import 'dart:async';

import 'package:weave/core/sync/device_info.dart';
import 'package:weave/core/sync/pulled_change.dart';
import 'package:weave/core/sync/remote_change.dart';
import 'package:weave/core/sync/sync_offline_exception.dart';
import 'package:weave/core/sync/sync_transport.dart';

class _Server {
  final visible = <PulledChange>[];
  final held = <PulledChange>[];
  final heldOrigin = <int, String>{};
  final knownIds = <String>{};
  final devices = <String, DeviceInfo>{};
  final hints = StreamController<String>.broadcast();
  int nextSeq = 1;
}

/// In-process transport for tests. Clients made by one [newServer] factory
/// share one server.
class InMemorySyncTransport implements SyncTransport {
  InMemorySyncTransport._(this._server, this._deviceId);

  /// Creates a fresh server and returns a factory of clients bound to it.
  static InMemorySyncTransport Function(String deviceId) newServer() {
    final server = _Server();
    return (deviceId) => InMemorySyncTransport._(server, deviceId);
  }

  final _Server _server;
  final String _deviceId;
  bool _holdNext = false;

  /// When true, push/pull/devices/touchDevice throw [SyncOfflineException].
  bool offline = false;

  /// Test hook: arms the NEXT non-empty push on this client to be held. Its
  /// rows get seq numbers now but stay invisible to pull until [releaseHeld].
  /// Later pushes by any client are visible immediately with higher seqs. The
  /// armed flag is cleared only by a push that stores at least one fresh row;
  /// empty or duplicate-only pushes leave it armed.
  void commitOutOfOrder() => _holdNext = true;

  /// Makes all held rows visible and hints every client except each row's
  /// origin device. Acts on the shared server, so any client may call it.
  void releaseHeld() {
    if (_server.held.isEmpty) return;
    final origins = <String>{..._server.heldOrigin.values};
    _server.visible.addAll(_server.held);
    _server.visible.sort((a, b) => a.seq.compareTo(b.seq));
    _server.held.clear();
    _server.heldOrigin.clear();
    origins.forEach(_server.hints.add);
  }

  void _checkOnline() {
    if (offline) throw const SyncOfflineException();
  }

  @override
  Future<void> push(List<RemoteChange> changes) async {
    _checkOnline();
    final fresh = <PulledChange>[];
    for (final c in changes) {
      if (!_server.knownIds.add(c.changeId)) continue;
      fresh.add(PulledChange(seq: _server.nextSeq++, change: c));
    }
    if (fresh.isEmpty) return;
    if (_holdNext) {
      _holdNext = false;
      _server.held.addAll(fresh);
      for (final p in fresh) {
        _server.heldOrigin[p.seq] = _deviceId;
      }
      return;
    }
    _server.visible.addAll(fresh);
    _server.hints.add(_deviceId);
  }

  @override
  Future<PulledPage> pull({required int afterSeq, int limit = 500}) async {
    _checkOnline();
    final rows = _server.visible
        .where((p) => p.seq > afterSeq)
        .take(limit)
        .toList(growable: false);
    return PulledPage(rows, full: rows.length >= limit);
  }

  /// Advisory, broadcast, no replay: a hint may be missed or coalesced, so
  /// engines must pull on start and on reconnect.
  @override
  Stream<void> hints() =>
      _server.hints.stream.where((origin) => origin != _deviceId);

  @override
  Future<void> touchDevice(String id, String name, String platform) async {
    _checkOnline();
    _server.devices[id] = DeviceInfo(
      id: id,
      name: name,
      platform: platform,
      lastSeen: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<DeviceInfo>> devices() async {
    _checkOnline();
    return _server.devices.values.toList(growable: false);
  }
}
