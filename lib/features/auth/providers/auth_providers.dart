import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:mapbox_api/common/services/notification_service.dart';
import 'package:mapbox_api/features/core/providers/firebase_providers.dart'
    show firebaseAuthProvider;
import 'package:mapbox_api/features/users/providers/user_providers.dart';

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

class _AuthActions {
  _AuthActions(this._auth, this._ref);

  final FirebaseAuth _auth;
  final Ref _ref;

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
    final uid = _auth.currentUser?.uid;

    // ✅ Remove FCM token BEFORE signing out so this device stops receiving
    // notifications for the user that is leaving.
    try {
      await NotificationService.instance.onSignOut().timeout(
        const Duration(seconds: 6),
      );
    } catch (_) {}

    try {
      await _ref.read(googleSignInInstanceProvider).signOut();
    } catch (_) {}

    await _auth.signOut();

    if (uid != null) {
      _ref.invalidate(isProfileCompleteProvider(uid));
      _ref.invalidate(canEnterAppProvider(uid));
    }

    _ref.invalidate(myProfileStreamProvider);
    _ref.invalidate(myRoleStreamProvider);
    _ref.invalidate(iOwnAtLeastOneParkingProvider);
  }
}
