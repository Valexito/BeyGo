import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mapbox_api/features/users/models/user_role.dart';
import 'package:mapbox_api/features/users/providers/user_providers.dart'
    show myRoleStreamProvider;

class RoleGate extends ConsumerWidget {
  const RoleGate({
    super.key,
    required this.allow,
    required this.child,
    this.fallback,
    this.loading,
  });

  final Set<UserRole> allow;
  final Widget child;
  final Widget? fallback;
  final Widget? loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(myRoleStreamProvider);

    return roleAsync.when(
      loading:
          () =>
              loading ??
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error:
          (e, _) =>
              fallback ??
              const Center(child: Text('No se pudo determinar tu rol.')),
      data: (role) {
        if (allow.contains(role)) return child;
        return fallback ??
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No tienes permiso para ver esta sección.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
      },
    );
  }
}
