import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
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
          error:
              (error, _) => _ProfileValidationErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(canEnterAppProvider(user.uid)),
              ),
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

class _ProfileValidationErrorView extends StatelessWidget {
  const _ProfileValidationErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFF2563EB),
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No pudimos validar tu perfil todavía',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
