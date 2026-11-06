import 'dart:async';
import 'dart:io' show IOException;

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'auth_gateway.dart';

/// [AuthGateway] on Supabase Auth. `supabase_flutter` persists the session.
class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(
    this._client, {
    this.timeout = const Duration(seconds: 15),
  });

  final SupabaseClient _client;

  /// Per call; a stalled request maps to [AuthError.network].
  final Duration timeout;

  GoTrueClient get _auth => _client.auth;

  @override
  Stream<AuthUser?> get user =>
      // Read the current user per event: the auth stream replays old events.
      _auth.onAuthStateChange.map((_) => current).distinct();

  @override
  AuthUser? get current => _toUser(_auth.currentUser);

  static AuthUser? _toUser(User? u) =>
      u == null ? null : AuthUser(id: u.id, email: u.email);

  @override
  Future<void> signIn(String email, String password) =>
      _guard(() => _auth.signInWithPassword(email: email, password: password));

  @override
  Future<void> signUp(String email, String password) => _guard(() async {
    final res = await _auth.signUp(email: email, password: password);
    if (res.session == null) {
      throw const AuthFailure(AuthError.emailNotConfirmed);
    }
  });

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<void> deleteAccount() =>
      _guard(() => _client.rpc<void>('delete_account'));

  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call().timeout(timeout);
    } on Object catch (e) {
      throw AuthFailure(mapAuthError(e));
    }
  }
}

/// Maps a Supabase / network error to an [AuthError]. Uses the gotrue error
/// code; the message is a fallback only for servers that send no code.
AuthError mapAuthError(Object error) {
  if (error is AuthFailure) return error.code;
  if (error is AuthRetryableFetchException) return AuthError.network;
  if (error is AuthWeakPasswordException) return AuthError.weakPassword;
  if (error is AuthException) {
    final byCode = switch (error.code) {
      'invalid_credentials' => AuthError.wrongPassword,
      'user_already_exists' || 'email_exists' => AuthError.emailInUse,
      'weak_password' => AuthError.weakPassword,
      'email_not_confirmed' => AuthError.emailNotConfirmed,
      _ => null,
    };
    if (byCode != null) return byCode;
    if (error.code == null) {
      final m = error.message.toLowerCase();
      if (m.contains('invalid login credentials')) {
        return AuthError.wrongPassword;
      }
      if (m.contains('already registered')) return AuthError.emailInUse;
    }
    return AuthError.unknown;
  }
  if (error is IOException ||
      error is TimeoutException ||
      error is ClientException) {
    return AuthError.network;
  }
  return AuthError.unknown;
}
