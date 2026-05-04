import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/providers/firebase_providers.dart'
    show firebaseAuthProvider;
import 'package:beygo/features/users/users.dart';

final authUserStreamProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.userChanges();
});

final googleSignInInstanceProvider = Provider<GoogleSignIn>((_) {
  return GoogleSignIn();
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

    try {
      await _auth.signOut().timeout(const Duration(seconds: 4));
    } catch (_) {}

    try {
      await _auth.authStateChanges().firstWhere((user) => user == null).timeout(
        const Duration(seconds: 4),
      );
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
