import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/features/owner/owner_home_page.dart';
import 'package:mapbox_api/features/core/pages/userv/home_page.dart';
import 'package:mapbox_api/features/users/models/user_role.dart';
import 'package:mapbox_api/features/users/providers/user_providers.dart'
    show myRoleStreamProvider;

class HomeSwitch extends ConsumerWidget {
  const HomeSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(myRoleStreamProvider);

    return roleAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      // 👇 en error, no bloquee la UI; asume user
      error: (_, __) => const HomePage(),
      data: (role) {
        switch (role) {
          case UserRole.provider:
          case UserRole.admin:
            return const OwnerHomePage();
          case UserRole.user:
          case UserRole.unknown:
            return const HomePage();
        }
      },
    );
  }
}
