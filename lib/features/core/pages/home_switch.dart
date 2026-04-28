import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/features/owner/owner.dart';
import 'package:beygo/features/users/users.dart' as users;

class HomeSwitch extends ConsumerWidget {
  const HomeSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(users.myRoleStreamProvider);

    return roleAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      // 👇 en error, no bloquee la UI; asume user
      error: (_, __) => const users.HomePage(),
      data: (role) {
        switch (role) {
          case users.UserRole.provider:
          case users.UserRole.admin:
            return const OwnerHomePage();
          case users.UserRole.user:
          case users.UserRole.unknown:
            return const users.HomePage();
        }
      },
    );
  }
}
