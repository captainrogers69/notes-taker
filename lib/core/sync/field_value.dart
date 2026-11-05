import 'package:equatable/equatable.dart';

/// A field value with the packed HLC of the write that set it.
///
/// [b] is only used for `text`: the HLC of the text version this edit was
/// made on top of (null when unknown or when the item had no text yet).
class FieldValue extends Equatable {
  const FieldValue(this.v, this.h, {this.b});

  final Object? v;
  final String h;
  final String? b;

  @override
  List<Object?> get props => [v, h, b];
}
