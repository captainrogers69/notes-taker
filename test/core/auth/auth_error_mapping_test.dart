import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:weave/core/auth/auth_gateway.dart';
import 'package:weave/core/auth/supabase_auth_gateway.dart';

void main() {
  test('gotrue error codes map to AuthError', () {
    const cases = {
      'invalid_credentials': AuthError.wrongPassword,
      'user_already_exists': AuthError.emailInUse,
      'email_exists': AuthError.emailInUse,
      'weak_password': AuthError.weakPassword,
      'email_not_confirmed': AuthError.emailNotConfirmed,
      'over_request_rate_limit': AuthError.unknown,
    };
    for (final e in cases.entries) {
      expect(
        mapAuthError(AuthApiException('x', statusCode: '400', code: e.key)),
        e.value,
        reason: e.key,
      );
    }
  });

  test('code wins over message; message is only a fallback', () {
    expect(
      mapAuthError(
        const AuthApiException(
          'Invalid login credentials',
          code: 'over_request_rate_limit',
        ),
      ),
      AuthError.unknown,
    );
    expect(
      mapAuthError(const AuthException('Invalid login credentials')),
      AuthError.wrongPassword,
    );
    expect(
      mapAuthError(const AuthException('User already registered')),
      AuthError.emailInUse,
    );
    expect(mapAuthError(const AuthException('nope')), AuthError.unknown);
  });

  test('weak password exception maps to weakPassword', () {
    expect(
      mapAuthError(
        AuthWeakPasswordException(
          message: 'weak',
          statusCode: '422',
          reasons: const ['length'],
        ),
      ),
      AuthError.weakPassword,
    );
  });

  test('network failures map to network', () {
    expect(
      mapAuthError(AuthRetryableFetchException(message: 'x')),
      AuthError.network,
    );
    expect(mapAuthError(const SocketException('x')), AuthError.network);
    expect(mapAuthError(TimeoutException('x')), AuthError.network);
    expect(mapAuthError(ClientException('x')), AuthError.network);
  });

  test('anything else maps to unknown; AuthFailure passes through', () {
    expect(mapAuthError(StateError('x')), AuthError.unknown);
    expect(
      mapAuthError(const PostgrestException(message: 'x', code: '42501')),
      AuthError.unknown,
    );
    expect(
      mapAuthError(const AuthFailure(AuthError.emailNotConfirmed)),
      AuthError.emailNotConfirmed,
    );
  });

  test('AuthUser toString never shows the email', () {
    const user = AuthUser(id: 'u1', email: 'a@example.com');
    expect(user.toString(), isNot(contains('example')));
    expect(user.toString(), contains('u1'));
  });

  test('UnavailableAuthGateway fails with unavailable', () async {
    const gateway = UnavailableAuthGateway();
    await expectLater(
      gateway.signIn('a', 'b'),
      throwsA(
        isA<AuthFailure>().having((f) => f.code, 'code', AuthError.unavailable),
      ),
    );
  });
}
