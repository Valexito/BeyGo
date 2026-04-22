import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/services/app_preferences_service.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/features/core/providers/app_preferences_provider.dart';
import 'package:mapbox_api/features/core/providers/firebase_providers.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';
import 'package:mapbox_api/features/owner/widgets/app_header.dart';
import 'package:mapbox_api/features/owner/pages/edit_owner_parking_page.dart';
import 'package:mapbox_api/features/owner/providers/owner_management_providers.dart';
import 'package:mapbox_api/features/auth/providers/auth_providers.dart'
    show authActionsProvider;
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';
import 'package:mapbox_api/features/users/pages/configure_profile_page.dart';

class OwnerSettingsPage extends ConsumerStatefulWidget {
  const OwnerSettingsPage({super.key});

  @override
  ConsumerState<OwnerSettingsPage> createState() => _OwnerSettingsPageState();
}

class _OwnerSettingsPageState extends ConsumerState<OwnerSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final notificationAsync = ref.watch(ownerNotificationSettingsStreamProvider);
    final parkingAsync = ref.watch(ownerParkingDocumentProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return OwnerOnly(
      builder: (_) {
        final notificationData = notificationAsync.asData?.value;
        final notifyNewReservation =
            (notificationData?['enabled'] as bool?) ??
            preferences.notificationsEnabled;
        final notifyExitRequest =
            (notificationData?['exitRequests'] as bool?) ?? true;
        final notifyCancellation =
            (notificationData?['cancellations'] as bool?) ?? true;
        final notifyForceCancel =
            (notificationData?['forceFinish'] as bool?) ?? false;

        final parking = parkingAsync.asData?.value;
        final autoApproveReservations =
            parking?.autoApproveReservations ?? false;
        final requirePlateOnEntry = parking?.requirePlateOnEntry ?? true;

        return Column(
          children: [
            const AppHeader(
              title: 'Configuración',
              subtitle: 'Preferencias y cuenta',
              showBack: true,
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  // ── Notifications ──────────────────────────────────────────
                  _SectionHeader(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notificaciones',
                    subtitle: 'Controla qué alertas recibes',
                  ),
                  _SettingsCard(
                    children: [
                      _SwitchRow(
                        icon: Icons.add_circle_outline_rounded,
                        iconColor: const Color(0xFF2563EB),
                        label: 'Nueva reservación',
                        sublabel: 'Al recibir una solicitud de reserva',
                        value: notifyNewReservation,
                        onChanged:
                            uid == null
                                ? null
                                : (v) => _saveOwnerNotification(uid, {
                                  'enabled': v,
                                }),
                      ),
                      _Divider(),
                      _SwitchRow(
                        icon: Icons.exit_to_app_rounded,
                        iconColor: const Color(0xFF0EA5E9),
                        label: 'Solicitud de salida',
                        sublabel: 'Cuando un usuario pide salir',
                        value: notifyExitRequest,
                        onChanged:
                            uid == null
                                ? null
                                : (v) => _saveOwnerNotification(uid, {
                                  'exitRequests': v,
                                }),
                      ),
                      _Divider(),
                      _SwitchRow(
                        icon: Icons.cancel_outlined,
                        iconColor: const Color(0xFFF59E0B),
                        label: 'Cancelación',
                        sublabel: 'Solicitudes de cancelación de reservas',
                        value: notifyCancellation,
                        onChanged:
                            uid == null
                                ? null
                                : (v) => _saveOwnerNotification(uid, {
                                  'cancellations': v,
                                }),
                      ),
                      _Divider(),
                      _SwitchRow(
                        icon: Icons.flag_rounded,
                        iconColor: const Color(0xFFDC2626),
                        label: 'Finalización forzada',
                        sublabel: 'Confirmación al liberar un espacio',
                        value: notifyForceCancel,
                        onChanged:
                            uid == null
                                ? null
                                : (v) => _saveOwnerNotification(uid, {
                                  'forceFinish': v,
                                }),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Parking behavior ───────────────────────────────────────
                  _SectionHeader(
                    icon: Icons.local_parking_rounded,
                    title: 'Comportamiento del parqueo',
                    subtitle: 'Ajusta cómo gestionas tus espacios',
                  ),
                  _SettingsCard(
                    children: [
                      _SwitchRow(
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: const Color(0xFF16A34A),
                        label: 'Auto-aprobar reservaciones',
                        sublabel: 'Aprueba automáticamente sin revisión manual',
                        value: autoApproveReservations,
                        onChanged:
                            parking == null
                                ? null
                                : (v) => _saveParkingBehavior(parking.id, {
                                  'autoApproveReservations': v,
                                }),
                        badge: autoApproveReservations ? 'ACTIVO' : null,
                        badgeColor: const Color(0xFF16A34A),
                      ),
                      _Divider(),
                      _SwitchRow(
                        icon: Icons.directions_car_outlined,
                        iconColor: AppColors.headerBottom,
                        label: 'Requerir placa al ingresar',
                        sublabel: 'Valida la placa antes de activar la reserva',
                        value: requirePlateOnEntry,
                        onChanged:
                            parking == null
                                ? null
                                : (v) => _saveParkingBehavior(parking.id, {
                                  'requirePlateOnEntry': v,
                                }),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _SectionHeader(
                    icon: Icons.manage_accounts_rounded,
                    title: 'Cuenta y parqueo',
                    subtitle: 'Administra tu perfil y la información publicada',
                  ),
                  _SettingsCard(
                    children: [
                      _NavRow(
                        icon: Icons.person_outline_rounded,
                        iconColor: AppColors.headerBottom,
                        label: 'Editar perfil',
                        subtitle: 'Actualiza tus datos, foto y vehículos',
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ConfigureProfilePage(),
                              ),
                            ),
                      ),
                      _Divider(),
                      _NavRow(
                        icon: Icons.storefront_outlined,
                        iconColor: const Color(0xFF16A34A),
                        label: 'Editar parqueo',
                        subtitle: 'Horarios, fotos, tarifa y datos públicos',
                        onTap:
                            parking == null
                                ? () => _toast(
                                  'Aún no hay un parqueo publicado para editar.',
                                )
                                : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => const EditOwnerParkingPage(),
                                  ),
                                ),
                      ),
                      _Divider(),
                      _NavRow(
                        icon: Icons.delete_outline_rounded,
                        iconColor: const Color(0xFFDC2626),
                        label: 'Solicitar eliminación del parqueo',
                        subtitle:
                            'Disponible fuera del horario publicado y sin reservas activas',
                        onTap:
                            parking == null
                                ? () => _toast(
                                  'Aún no hay un parqueo publicado para eliminar.',
                                )
                                : () => _showDeleteParkingDialog(parking),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── App ───────────────────────────────────────────────────
                  _SectionHeader(
                    icon: Icons.phone_iphone_rounded,
                    title: 'Aplicación',
                  ),
                  _SettingsCard(
                    children: [
                      _NavRow(
                        icon: Icons.palette_outlined,
                        iconColor: const Color(0xFF7C3AED),
                        label: 'Tema',
                        subtitle: _themeLabel(preferences.themePreference),
                        onTap: () => _showThemePicker(),
                      ),
                      _Divider(),
                      _NavRow(
                        icon: Icons.star_border_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        label: 'Calificar la app',
                        onTap: () => _toast('Abriendo tienda...'),
                      ),
                      _Divider(),
                      _NavRow(
                        icon: Icons.share_outlined,
                        iconColor: AppColors.headerBottom,
                        label: 'Compartir app',
                        onTap: () => _toast('Compartiendo...'),
                      ),
                      _Divider(),
                      _NavRow(
                        icon: Icons.info_outline_rounded,
                        iconColor: const Color(0xFF6B7280),
                        label: 'Versión de la app',
                        trailing: const Text(
                          'v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Legal ─────────────────────────────────────────────────
                  _SectionHeader(icon: Icons.gavel_rounded, title: 'Legal'),
                  _SettingsCard(
                    children: [
                      _NavRow(
                        icon: Icons.lock_outline_rounded,
                        iconColor: const Color(0xFF6B7280),
                        label: 'Política de privacidad',
                        onTap: () => _toast('Abriendo política...'),
                      ),
                      _Divider(),
                      _NavRow(
                        icon: Icons.description_outlined,
                        iconColor: const Color(0xFF6B7280),
                        label: 'Términos y condiciones',
                        onTap: () => _toast('Abriendo términos...'),
                      ),
                      _Divider(),
                      _NavRow(
                        icon: Icons.cookie_outlined,
                        iconColor: const Color(0xFF6B7280),
                        label: 'Política de cookies',
                        onTap: () => _toast('Abriendo cookies...'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Support ───────────────────────────────────────────────
                  _SectionHeader(
                    icon: Icons.support_agent_rounded,
                    title: 'Soporte',
                  ),
                  _SettingsCard(
                    children: [
                      _NavRow(
                        icon: Icons.email_outlined,
                        iconColor: AppColors.headerBottom,
                        label: 'Contactar soporte',
                        onTap: () => _toast('Abriendo contacto...'),
                      ),
                      _Divider(),
                      _NavRow(
                        icon: Icons.chat_bubble_outline_rounded,
                        iconColor: AppColors.headerBottom,
                        label: 'Enviar feedback',
                        onTap: () => _toast('Abriendo feedback...'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Logout ────────────────────────────────────────────────
                  _LogoutButton(onTap: () => _logout(context)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.headerBottom.withValues(alpha: 0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      children: [
                        const Text(
                          '¿Seguro que deseas cerrar sesión?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5A6478),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: AppColors.headerBottom.withValues(
                                        alpha: 0.35,
                                      ),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    backgroundColor: Colors.white,
                                  ),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.headerBottom,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Salir',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(authActionsProvider).signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveOwnerNotification(
    String uid,
    Map<String, dynamic> changes,
  ) async {
    try {
      await ref.read(ownerNotificationsSettingsProvider).call(uid, changes);
    } catch (e) {
      if (!mounted) return;
      _toast('No se pudo guardar la preferencia: $e');
    }
  }

  Future<void> _saveParkingBehavior(
    String parkingId,
    Map<String, dynamic> changes,
  ) async {
    try {
      await ref.read(ownerParkingBehaviorProvider).call(parkingId, changes);
    } catch (e) {
      if (!mounted) return;
      _toast('No se pudo guardar la configuración: $e');
    }
  }

  Future<void> _showThemePicker() async {
    final selected = await showModalBottomSheet<AppThemePreference>(
      context: context,
      backgroundColor: context.appCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        final current = ref.read(appPreferencesProvider).themePreference;
        final options = AppThemePreference.values;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Selecciona un tema',
                  style: TextStyle(
                    color: ctx.appTextPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                for (final option in options) ...[
                  _ThemeOptionTile(
                    title: _themeLabel(option),
                    selected: option == current,
                    onTap: () => Navigator.pop(ctx, option),
                  ),
                  if (option != options.last)
                    Divider(color: ctx.appBorderColor, height: 1),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) return;
    await ref.read(appPreferencesProvider.notifier).setThemePreference(selected);
  }

  Future<void> _showDeleteParkingDialog(OwnerParkingDocument parking) async {
    final reservations = await ref.read(ownerAllReservationsProvider.future);
    final hasBlockingReservations = reservations.any(
      (r) => r.state == 'active' || r.state == 'pending',
    );

    if (hasBlockingReservations) {
      _toast(
        'No puedes solicitar eliminación mientras existan reservaciones activas o pendientes.',
      );
      return;
    }

    if (_isWithinBusinessHours(parking.businessHours)) {
      _toast(
        'Esta solicitud solo puede enviarse fuera del horario publicado del parqueo.',
      );
      return;
    }

    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: ctx.appCardBackground,
            title: Text(
              'Solicitar eliminación',
              style: TextStyle(color: ctx.appTextPrimaryColor),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tu solicitud quedará pendiente de revisión del equipo. Indica el motivo para continuar.',
                  style: TextStyle(color: ctx.appTextSecondaryColor),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 4,
                  style: TextStyle(color: ctx.appTextPrimaryColor),
                  decoration: InputDecoration(
                    hintText: 'Ej: cerraré operaciones definitivamente',
                    hintStyle: TextStyle(color: ctx.appTextSecondaryColor),
                    filled: true,
                    fillColor: ctx.appInputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: ctx.appBorderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: ctx.appBorderColor),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      borderSide: BorderSide(color: AppColors.headerBottom),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Enviar'),
              ),
            ],
          ),
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();

    if (confirmed != true) return;
    if (reason.isEmpty) {
      _toast('Necesitas indicar el motivo de la solicitud.');
      return;
    }

    try {
      await ref
          .read(submitParkingDeletionRequestProvider)
          .call(parking: parking, reason: reason);
      if (!mounted) return;
      _toast('Solicitud enviada. El equipo revisará tu caso.');
    } catch (e) {
      if (!mounted) return;
      _toast('No se pudo enviar la solicitud: $e');
    }
  }

  bool _isWithinBusinessHours(Map<String, String> hours) {
    TimeOfDay? parse(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      final parts = raw.split(':');
      if (parts.length != 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      return TimeOfDay(hour: hour, minute: minute);
    }

    final open = parse(hours['open']);
    final close = parse(hours['close']);
    if (open == null || close == null) return false;

    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;

    if (openMinutes <= closeMinutes) {
      return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
    }
    return nowMinutes >= openMinutes || nowMinutes <= closeMinutes;
  }

  String _themeLabel(AppThemePreference preference) {
    switch (preference) {
      case AppThemePreference.system:
        return 'Sistema';
      case AppThemePreference.light:
        return 'Claro';
      case AppThemePreference.dark:
        return 'Oscuro';
    }
  }
}

// ─── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.headerBottom.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.headerBottom),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimaryColor,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextSecondaryColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Settings card container ───────────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDarkMode ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

// ─── Divider ───────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.appBorderColor,
      indent: 56,
    );
  }
}

// ─── Switch row ────────────────────────────────────────────────────────────────
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? sublabel;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? badge;
  final Color? badgeColor;

  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.sublabel,
    required this.value,
    required this.onChanged,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimaryColor,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor!.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appTextSecondaryColor,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.headerBottom,
          ),
        ],
      ),
    );
  }
}

// ─── Nav row ───────────────────────────────────────────────────────────────────
class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _NavRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimaryColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appTextSecondaryColor,
                      ),
                    ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.appTextSecondaryColor,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}

// ─── Logout button ─────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:
              context.isDarkMode
                  ? const Color(0xFF2A1620)
                  : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFDC2626).withValues(alpha: 0.25),
            width: 1.4,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
            SizedBox(width: 10),
            Text(
              'Cerrar sesión',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: TextStyle(
          color: context.appTextPrimaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing:
          selected
              ? const Icon(
                Icons.check_circle_rounded,
                color: AppColors.headerBottom,
              )
              : null,
    );
  }
}
