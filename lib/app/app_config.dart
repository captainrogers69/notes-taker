import 'package:equatable/equatable.dart';

enum Flavor { dev, prod }

/// Runtime configuration, read from `--dart-define-from-file=config/<flavor>.json`.
class AppConfig extends Equatable {
  const AppConfig({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.profile,
  });

  final Flavor flavor;
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Names the DB folder, so two copies can run on one machine.
  final String profile;

  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _profile = String.fromEnvironment(
    'WEAVE_PROFILE',
    defaultValue: 'default',
  );

  static AppConfig fromEnvironment(Flavor f) {
    if (_url.isEmpty) {
      throw StateError(
        'SUPABASE_URL is missing. Run with '
        '--dart-define-from-file=config/${f.name}.json '
        '(copy config/dev.example.json and fill in the values).',
      );
    }
    if (_anonKey.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY is missing. Set it in config/${f.name}.json.',
      );
    }
    return AppConfig(
      flavor: f,
      supabaseUrl: _url,
      supabaseAnonKey: _anonKey,
      profile: _profile.isEmpty ? 'default' : _profile,
    );
  }

  @override
  List<Object?> get props => [flavor, supabaseUrl, supabaseAnonKey, profile];
}
