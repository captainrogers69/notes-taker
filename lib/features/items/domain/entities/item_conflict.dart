import 'package:equatable/equatable.dart';

/// A losing concurrent edit kept for the user to resolve.
class ItemConflict extends Equatable {
  const ItemConflict({required this.otherText, required this.fromDevice});

  final String otherText;
  final String fromDevice;

  @override
  List<Object?> get props => [otherText, fromDevice];
}
