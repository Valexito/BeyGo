import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:beygo/features/users/models/user_role.dart';
import 'package:beygo/features/users/providers/user_providers.dart'
    show myRoleStreamProvider;

bool isOwnerLike(UserRole r) => r == UserRole.provider || r == UserRole.admin;
bool isUserOnly(UserRole r) => r == UserRole.user;

class RoleRedirect extends ConsumerWidget {
  const RoleRedirect({
    super.key,
    required this.allow,
    required this.builder,
    this.onDenied,
  });

  final Set<UserRole> allow;
  final WidgetBuilder builder;
  final WidgetBuilder? onDenied;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(myRoleStreamProvider);
    return roleAsync.when(
      loading:
          () => const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      error:
          (e, _) =>
              Scaffold(body: Center(child: Text('Error cargando rol: $e'))),
      data: (role) {
        if (allow.contains(role)) return builder(context);
        if (onDenied != null) return onDenied!(context);

        // Redirecciones por defecto
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
          if (isOwnerLike(role)) {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/owner', (_) => false);
          } else {
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/home', (_) => false);
          }
        });
        return const SizedBox.shrink();
      },
    );
  }
}

class UserOnly extends StatelessWidget {
  const UserOnly({super.key, required this.builder, this.onDenied});
  final WidgetBuilder builder;
  final WidgetBuilder? onDenied;
  @override
  Widget build(BuildContext context) => RoleRedirect(
    allow: const {UserRole.user},
    builder: builder,
    onDenied: onDenied,
  );
}

class OwnerOnly extends StatelessWidget {
  const OwnerOnly({super.key, required this.builder, this.onDenied});
  final WidgetBuilder builder;
  final WidgetBuilder? onDenied;
  @override
  Widget build(BuildContext context) => RoleRedirect(
    allow: const {UserRole.provider, UserRole.admin},
    builder: builder,
    onDenied: onDenied,
  );
}
