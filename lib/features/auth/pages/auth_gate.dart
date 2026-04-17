// lib/features/auth/pages/auth_gate.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mapbox_api/common/widgets/app_loading_screen.dart';
import '../../core/providers/firebase_providers.dart';
import '../../users/pages/complete_profile_page.dart';
import '../../users/providers/user_providers.dart';
import '../../core/pages/home_switch.dart';
import '../components/verify_email_page.dart';
import 'auth_flow_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  bool _isPasswordUser(User user) {
    return user.providerData.any((p) => p.providerId == 'password');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateChangesProvider);

    return authAsync.when(
      loading:
          () => const AppLoadingScreen(
            message: 'Iniciando...',
            variant: LoadingVariant.general,
          ),
      error: (_, __) => const AuthFlowPage(),
      data: (user) {
        // No user — show login/register
        if (user == null) return const AuthFlowPage();

        // Password user with unverified email
        if (_isPasswordUser(user) && !user.emailVerified) {
          return VerifyEmailPage(user: user);
        }

        // Check if profile is complete
        final canEnterAsync = ref.watch(canEnterAppProvider(user.uid));

        return canEnterAsync.when(
          loading:
              () => const AppLoadingScreen(
                message: 'Verificando perfil...',
                variant: LoadingVariant.profile,
              ),
          error: (_, __) => CompleteProfilePage(user: user, isNewUser: false),
          data: (canEnter) {
            if (canEnter) return const HomeSwitch();
            return CompleteProfilePage(user: user, isNewUser: false);
          },
        );
      },
    );
  }
}
