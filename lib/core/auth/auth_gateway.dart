import 'package:equatable/equatable.dart';

/// The signed-in account. [email] is for display only: never log it.
class AuthUser extends Equatable {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;

  @override
  List<Object?> get props => [id, email];

  /// Never includes the email (logs and test output).
  @override
  String toString() => 'AuthUser($id)';
}

/// Why an auth call failed, in terms the account dialogs can show.
enum AuthError {
  wrongPassword,
  emailInUse,
  weakPassword,

  /// Sign-up needs the email confirmed first (the project setting is on), or
  /// sign-in was tried before confirming. Not a failure of the form: the
  /// dialog asks the user to confirm and then sign in.
  emailNotConfirmed,
  network,

  /// No backend configured or it failed to start: local-only build.
  unavailable,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final AuthError code;

  @override
  String toString() => 'AuthFailure(${code.name})';
}

/// Email + password auth (D5). Every method throws [AuthFailure] on failure.
abstract class AuthGateway {
  /// The current user, re-emitted on every auth change.
  Stream<AuthUser?> get user;

  AuthUser? get current;

  Future<void> signIn(String email, String password);

  /// Signs up and, when the project returns a session, signs in. Throws
  /// [AuthFailure] with [AuthError.emailNotConfirmed] when no session comes
  /// back (email confirmation is on).
  Future<void> signUp(String email, String password);

  /// Ends the local session. May throw [AuthError.network] after the local
  /// session is already gone (the server call failed); callers treat sign
  /// out as done locally either way.
  Future<void> signOut();

  /// Deletes the account and all its server data (`rpc('delete_account')`).
  /// Does not sign out: `SessionCubit` wipes first, then calls [signOut].
  Future<void> deleteAccount();
}

/// Used when the backend is not configured or failed to start: the app is
/// local-only and every account action fails with [AuthError.unavailable].
class UnavailableAuthGateway implements AuthGateway {
  const UnavailableAuthGateway();

  static const _failure = AuthFailure(AuthError.unavailable);

  @override
  Stream<AuthUser?> get user => const Stream.empty();

  @override
  AuthUser? get current => null;

  @override
  Future<void> signIn(String email, String password) async => throw _failure;

  @override
  Future<void> signUp(String email, String password) async => throw _failure;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async => throw _failure;
}
