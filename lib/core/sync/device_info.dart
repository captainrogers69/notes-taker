import 'package:equatable/equatable.dart';

/// A device registered for the signed-in account.
class DeviceInfo extends Equatable {
  const DeviceInfo({
    required this.id,
    required this.name,
    required this.platform,
    required this.lastSeen,
  });

  final String id;
  final String name;
  final String platform;
  final DateTime lastSeen;

  @override
  List<Object?> get props => [id, name, platform, lastSeen];
}
