// lib/features/auth/pages/auth_gate.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mapbox_api/common/ui/widgets/app_loading_screen.dart';
import '../../core/providers/firebase_providers.dart';
import '../../users/pages/complete_profile_page.dart';
import '../../users/providers/user_providers.dart';
import '../../core/pages/home_switch.dart';
import '../components/verify_email_page.dart';
import 'auth_flow_page.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _lastUid;
  bool? _cachedCanEnter;

  bool _isPasswordUser(User user) =>
      user.providerData.any((p) => p.providerId == 'password');

  void _clearProvidersForUid(String uid) {
    ref.invalidate(canEnterAppProvider(uid));
    ref.invalidate(isProfileCompleteProvider(uid));
    ref.invalidate(myProfileStreamProvider);
    ref.invalidate(myRoleStreamProvider);
    ref.invalidate(iOwnAtLeastOneParkingProvider);
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateChangesProvider);

    return authAsync.when(
      loading:
          () => const AppLoadingScreen(
            message: 'Iniciando...',
            variant: LoadingVariant.general,
          ),
      error: (_, __) => const AuthFlowPage(),
      data: (user) {
        // ── Signed out ──────────────────────────────────────────────────────
        if (user == null) {
          if (_lastUid != null) {
            final prev = _lastUid!;
            _lastUid = null;
            _cachedCanEnter = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _clearProvidersForUid(prev);
            });
          }
          return const AuthFlowPage();
        }

        // ── Email not verified ──────────────────────────────────────────────
        if (_isPasswordUser(user) && !user.emailVerified) {
          return VerifyEmailPage(user: user);
        }

        // ── User switched accounts ──────────────────────────────────────────
        if (_lastUid != null && _lastUid != user.uid) {
          final prev = _lastUid!;
          _cachedCanEnter = null;
          // Clear previous user's providers so their streams stop
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _clearProvidersForUid(prev);
          });
        }
        _lastUid = user.uid;

        // ── Already confirmed this user can enter ───────────────────────────
        if (_cachedCanEnter == true) return const HomeSwitch();

        // ── Check Firestore ─────────────────────────────────────────────────
        final canEnterAsync = ref.watch(canEnterAppProvider(user.uid));

        return canEnterAsync.when(
          loading: () {
            if (_cachedCanEnter == true) return const HomeSwitch();
            return const AppLoadingScreen(
              message: 'Verificando perfil...',
              variant: LoadingVariant.profile,
            );
          },
          error: (_, __) => CompleteProfilePage(user: user, isNewUser: false),
          data: (canEnter) {
            _cachedCanEnter = canEnter;
            if (canEnter) return const HomeSwitch();
            return CompleteProfilePage(user: user, isNewUser: false);
          },
        );
      },
    );
  }
}
