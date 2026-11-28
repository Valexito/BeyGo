import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:beygo/app_environment.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/providers/firebase_providers.dart'
    show firebaseAuthProvider;
import 'package:beygo/features/users/users.dart';

final authUserStreamProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.userChanges();
});

// Web OAuth client (client_type 3 en google-services.json) de cada proyecto
// Firebase. Passing it explicitly helps Google Sign-In resolve the correct
// OAuth setup on Play-distributed builds. Debe coincidir con el ambiente: si se
// usa el de producción en DEV, Google responde ApiException 10.
const _googleServerClientIdProd =
    '102949234278-ktoqboaffipnlsilm28qsefriuefon3q.apps.googleusercontent.com';
const _googleServerClientIdDev =
    '694572629413-punh5om919mdm87v2e4s9n89jqf08lu8.apps.googleusercontent.com';

final googleSignInInstanceProvider = Provider<GoogleSignIn>((_) {
  return GoogleSignIn(
    serverClientId:
        AppEnv.isDev ? _googleServerClientIdDev : _googleServerClientIdProd,
  );
});

final signInWithGoogleProvider = Provider<Future<UserCredential> Function()>((
  ref,
) {
  final google = ref.watch(googleSignInInstanceProvider);
  final auth = ref.watch(firebaseAuthProvider);

  return () async {
    final account = await google.signIn();
    if (account == null) throw Exception('Google sign-in cancelled');

    final tokens = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
    );

    return auth.signInWithCredential(credential);
  };
});

final signInWithGoogleFnProvider = signInWithGoogleProvider;

/// El usuario cerró la ventana de Facebook sin iniciar sesión.
class FacebookSignInCancelled implements Exception {
  const FacebookSignInCancelled();
  @override
  String toString() => 'Facebook sign-in cancelled';
}

String _generateNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

/// Inicio de sesión / registro con Facebook (por ahora solo en DEV).
///
/// - Android, o iOS con rastreo permitido: token clásico → FacebookAuthProvider.
/// - iOS sin permiso de rastreo: Facebook entrega un token "Limited Login"
///   (OIDC); Firebase lo acepta como OAuthProvider('facebook.com') + nonce.
final signInWithFacebookProvider =
    Provider<Future<UserCredential> Function()>((ref) {
      final auth = ref.watch(firebaseAuthProvider);

      return () async {
        final rawNonce = _generateNonce();
        final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

        final result = await FacebookAuth.instance.login(
          permissions: const ['email', 'public_profile'],
          loginTracking: LoginTracking.enabled,
          nonce: nonce,
        );

        if (result.status == LoginStatus.cancelled) {
          throw const FacebookSignInCancelled();
        }
        final token = result.accessToken;
        if (result.status != LoginStatus.success || token == null) {
          throw Exception('Facebook login failed: ${result.message}');
        }

        final AuthCredential credential =
            token.type == AccessTokenType.limited
                ? OAuthProvider(
                  'facebook.com',
                ).credential(idToken: token.tokenString, rawNonce: rawNonce)
                : FacebookAuthProvider.credential(token.tokenString);

        return auth.signInWithCredential(credential);
      };
    });

final authActionsProvider = Provider<_AuthActions>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return _AuthActions(auth, ref);
});

Future<void> signOutAndNavigateToAuth(
  BuildContext context, {
  String message = 'Cerrando sesión...',
  String submessage = 'Saliendo de tu cuenta de forma segura.',
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final container = ProviderScope.containerOf(context, listen: false);

  showGeneralDialog<void>(
    context: navigator.context,
    barrierDismissible: false,
    barrierLabel: 'Cerrando sesión',
    barrierColor: Colors.black.withValues(alpha: 0.20),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder:
        (_, __, ___) => AppLoadingScreen(
          message: message,
          submessage: submessage,
          variant: LoadingVariant.general,
        ),
    transitionBuilder: (_, animation, __, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );

  await Future<void>.delayed(const Duration(milliseconds: 80));

  try {
    await container.read(authActionsProvider).signOut();
  } finally {
    if (navigator.mounted) {
      navigator.pushNamedAndRemoveUntil('/auth', (_) => false);
    }
  }
}

class _AuthActions {
  _AuthActions(this._auth, this._ref);

  final FirebaseAuth _auth;
  final Ref _ref;
  Future<void>? _ongoingSignOut;

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    if (_ongoingSignOut != null) {
      return _ongoingSignOut!;
    }

    _ongoingSignOut = _performSignOut();

    try {
      await _ongoingSignOut;
    } finally {
      _ongoingSignOut = null;
    }
  }

  Future<void> _performSignOut() async {
    final uid = _auth.currentUser?.uid;

    // ✅ Remove FCM token BEFORE signing out so this device stops receiving
    // notifications for the user that is leaving.
    try {
      await NotificationService.instance.onSignOut().timeout(
        const Duration(seconds: 6),
      );
    } catch (_) {}

    final googleSignIn = _ref.read(googleSignInInstanceProvider);

    try {
      // Disconnect is stronger than signOut and helps avoid the same Google
      // account silently reattaching after repeated login/logout cycles.
      await googleSignIn.disconnect().timeout(const Duration(seconds: 4));
    } catch (_) {}

    try {
      await googleSignIn.signOut().timeout(const Duration(seconds: 4));
    } catch (_) {}

    if (AppEnv.isDev) {
      try {
        await FacebookAuth.instance.logOut().timeout(
          const Duration(seconds: 4),
        );
      } catch (_) {}
    }

    try {
      await _auth.signOut().timeout(const Duration(seconds: 4));
    } catch (_) {}

    try {
      await _auth
          .authStateChanges()
          .firstWhere((user) => user == null)
          .timeout(const Duration(seconds: 4));
    } catch (_) {}

    if (uid != null) {
      _ref.invalidate(isProfileCompleteProvider(uid));
      _ref.invalidate(canEnterAppProvider(uid));
    }

    _ref.invalidate(myProfileStreamProvider);
    _ref.invalidate(myRoleStreamProvider);
    _ref.invalidate(iOwnAtLeastOneParkingProvider);
  }
}
