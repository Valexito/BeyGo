import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/auth/providers/auth_providers.dart'
    show signOutAndNavigateToAuth;
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/owner/owner.dart';
import 'package:beygo/features/reservations/reservations.dart';
import 'package:beygo/features/users/users.dart';

class ConfigurationsPage extends ConsumerWidget {
  const ConfigurationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final uid = user?.uid;
    final isDark = context.isDarkMode;
    final headerGradient =
        isDark
            ? const [Color(0xFF111827), Color(0xFF0F172A), Color(0xFF0B1220)]
            : const [AppColors.headerTop, AppColors.headerBottom];

    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Stack(
                  children: [
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: headerGradient,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 38,
                      left: -20,
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: isDark ? 0.04 : 0.12,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -10,
                      right: -8,
                      child: Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: isDark ? 0.03 : 0.10,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Stack(
                          children: [
                            const SizedBox(height: 235, width: double.infinity),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: SafeArea(
                                  bottom: false,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      52,
                                      24,
                                      0,
                                    ),
                                    child: Column(
                                      children: const [
                                        Icon(
                                          Icons.settings_suggest_rounded,
                                          color: Colors.white,
                                          size: 52,
                                        ),
                                        SizedBox(height: 12),
                                        MyText(
                                          text: 'Configuraciones',
                                          variant: MyTextVariant.title,
                                          customColor: Colors.white,
                                          textAlign: TextAlign.center,
                                          fontSize: 28,
                                        ),
                                        SizedBox(height: 6),
                                        MyText(
                                          text:
                                              'Preferencias, cuenta y soporte',
                                          variant: MyTextVariant.subtitle,
                                          customColor: Colors.white70,
                                          textAlign: TextAlign.center,
                                          fontSize: 13,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (isDark)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.00),
                                          Colors.black.withValues(alpha: 0.08),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              left: 8,
                              top: 10,
                              child: SafeArea(
                                child: TextButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Regresar'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Transform.translate(
                          offset: const Offset(0, -22),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: context.appSectionBackground,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(34),
                                topRight: Radius.circular(34),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                28,
                                16,
                                34,
                              ),
                              child:
                                  uid == null
                                      ? const _NoSessionState()
                                      : _SettingsBody(uid: uid),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NoSessionState extends StatelessWidget {
  const _NoSessionState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: MyText(
          text: 'Inicia sesión para administrar tus configuraciones.',
          variant: MyTextVariant.bodyMuted,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(myNotificationSettingsStreamProvider);
    final preferences = ref.watch(appPreferencesProvider);

    return notifAsync.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 50),
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: MyText(
              text: 'Error cargando configuraciones: $e',
              variant: MyTextVariant.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ),
      data: (data) {
        final enabled =
            (data?['enabled'] as bool?) ?? preferences.notificationsEnabled;
        final reminders =
            (data?['reminders'] as bool?) ??
            preferences.reservationRemindersEnabled;
        final updates =
            (data?['updates'] as bool?) ?? preferences.appUpdatesEnabled;
        final sound =
            (data?['soundEnabled'] as bool?) ??
            preferences.notificationSoundEnabled;

        Future<void> savePartial(Map<String, dynamic> values) async {
          await ref.read(saveNotificationSettingsProvider).call(uid, values);
        }

        Future<void> saveNotificationToggle(String key, bool value) async {
          final controller = ref.read(appPreferencesProvider.notifier);
          switch (key) {
            case 'enabled':
              await controller.setNotificationsEnabled(value);
              break;
            case 'reminders':
              await controller.setReservationRemindersEnabled(value);
              break;
            case 'updates':
              await controller.setAppUpdatesEnabled(value);
              break;
          }
          await savePartial({key: value});
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              icon: Icons.notifications_none_rounded,
              title: 'Notificaciones',
              subtitle: 'Controla qué alertas recibes y cómo se muestran',
            ),
            _SettingsCard(
              children: [
                _SwitchRow(
                  icon: Icons.notifications_active_outlined,
                  iconColor: const Color(0xFF2563EB),
                  label: 'Notificaciones activas',
                  sublabel: 'Permitir alertas mientras usas la app',
                  value: enabled,
                  onChanged: (v) => saveNotificationToggle('enabled', v),
                  badge: enabled ? 'ON' : null,
                  badgeColor: const Color(0xFF2563EB),
                ),
                const _Divider(),
                _SwitchRow(
                  icon: Icons.alarm_on_outlined,
                  iconColor: const Color(0xFF0EA5E9),
                  label: 'Recordatorios',
                  sublabel: 'Antes de iniciar o terminar una reservación',
                  value: reminders,
                  onChanged:
                      enabled
                          ? (v) => saveNotificationToggle('reminders', v)
                          : null,
                ),
                const _Divider(),
                _SwitchRow(
                  icon: Icons.system_update_alt_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'Actualizaciones',
                  sublabel: 'Cambios importantes y estado del servicio',
                  value: updates,
                  onChanged:
                      enabled
                          ? (v) => saveNotificationToggle('updates', v)
                          : null,
                ),
                const _Divider(),
                _SwitchRow(
                  icon: Icons.volume_up_outlined,
                  iconColor: const Color(0xFF16A34A),
                  label: 'Sonido',
                  sublabel: 'Reproducir sonido en notificaciones visibles',
                  value: sound,
                  onChanged:
                      enabled
                          ? (v) async {
                            await ref
                                .read(appPreferencesProvider.notifier)
                                .setNotificationSoundEnabled(v);
                            await savePartial({'soundEnabled': v});
                          }
                          : null,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.person_outline_rounded,
              title: 'Cuenta y perfil',
              subtitle: 'Accesos importantes para tu cuenta de usuario',
            ),
            _SettingsCard(
              children: [
                _NavRow(
                  icon: Icons.edit_outlined,
                  iconColor: context.appBrandIconColor,
                  label: 'Editar perfil',
                  subtitle: 'Datos personales, foto y vehículos',
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ConfigureProfilePage(),
                        ),
                      ),
                ),
                const _Divider(),
                _NavRow(
                  icon: Icons.bookmark_added_outlined,
                  iconColor: const Color(0xFF16A34A),
                  label: 'Mis reservaciones',
                  subtitle: 'Consulta tus reservaciones activas e historial',
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ReservationsPage(),
                        ),
                      ),
                ),
                const _Divider(),
                _NavRow(
                  icon: Icons.local_parking_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'Registrar un parqueo',
                  subtitle: 'Inicia el proceso para convertirte en proveedor',
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BecomeOwnerPage(),
                        ),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.phone_iphone_rounded,
              title: 'Aplicación',
              subtitle: 'Personaliza la experiencia y comparte la app',
            ),
            _SettingsCard(
              children: [
                _NavRow(
                  icon: Icons.palette_outlined,
                  iconColor: context.appBrandIconColor,
                  label: 'Tema',
                  subtitle: _themeLabel(preferences.themePreference),
                  onTap: () => _showThemePicker(context, ref),
                ),
                const _Divider(),
                _NavRow(
                  icon: Icons.share_outlined,
                  iconColor: const Color(0xFF2563EB),
                  label: 'Compartir app',
                  subtitle: 'Copia un mensaje para recomendar la app',
                  onTap: () => _shareApp(context),
                ),
                const _Divider(),
                _NavRow(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF0EA5E9),
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
            _SectionHeader(
              icon: Icons.gavel_rounded,
              title: 'Legal',
              subtitle: 'Consulta información importante sobre el servicio',
            ),
            _SettingsCard(
              children: [
                _NavRow(
                  icon: Icons.lock_outline_rounded,
                  iconColor: context.appBrandIconColor,
                  label: 'Política de privacidad',
                  onTap: () => _openLegal(context, 'Privacidad'),
                ),
                const _Divider(),
                _NavRow(
                  icon: Icons.description_outlined,
                  iconColor: const Color(0xFF16A34A),
                  label: 'Términos y condiciones',
                  onTap: () => _openLegal(context, 'Términos de servicio'),
                ),
                const _Divider(),
                _NavRow(
                  icon: Icons.cookie_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'Política de cookies',
                  onTap: () => _openLegal(context, 'Política de cookies'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.support_agent_rounded,
              title: 'Soporte',
              subtitle:
                  'Pide ayuda o envíanos retroalimentación para mejorar BeyGo',
            ),
            _SettingsCard(
              children: [
                _NavRow(
                  icon: Icons.email_outlined,
                  iconColor: context.appBrandIconColor,
                  label: 'Contactar soporte',
                  subtitle: 'Envíanos un reporte si algo no está funcionando',
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => const ReportProblemPage(
                                initialReportType: 'Problema con reservación',
                                initialSubject: 'Soporte de usuario',
                              ),
                        ),
                      ),
                ),
                const _Divider(),
                _NavRow(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                  label: 'Enviar retroalimentación',
                  subtitle: 'Cuéntanos qué mejorar o qué te gustaría ver',
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => const ReportProblemPage(
                                initialReportType: 'Otro',
                                initialSubject: 'Retroalimentación de la app',
                              ),
                        ),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.warning_amber_rounded,
              title: 'Cuenta sensible',
              subtitle: 'Acciones delicadas para tu cuenta',
            ),
            _SettingsCard(
              children: [
                _NavRow(
                  icon: Icons.delete_forever_outlined,
                  iconColor: const Color(0xFFDC2626),
                  label: 'Eliminar cuenta',
                  subtitle: 'Borra tu perfil y la información asociada',
                  onTap:
                      () => showDialog(
                        context: context,
                        builder: (_) => const DeleteAccountDialog(),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _LogoutButton(onTap: () => _logout(context, ref)),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: MyText(
                text:
                    'Tus preferencias se guardan en tu cuenta y puedes ajustarlas cuando quieras.',
                variant: MyTextVariant.bodyMuted,
                fontSize: 12,
                customColor: context.appTextSecondaryColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: ctx.appCardBackground,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: ctx.isDarkMode ? 0.28 : 0.12,
                    ),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(
                            0xFFDC2626,
                          ).withValues(alpha: 0.20),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFDC2626),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        color: ctx.appTextPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¿Seguro que deseas cerrar sesión?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: ctx.appTextSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: ctx.appBorderColor,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: ctx.appCardBackground,
                              ),
                              child: Text(
                                'Cancelar',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: ctx.appTextPrimaryColor,
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
            ),
          ),
    );

    if (confirmed != true) return;
    await signOutAndNavigateToAuth(context);
  }

  Future<void> _shareApp(BuildContext context) async {
    const message =
        'Te recomiendo BeyGo para encontrar y reservar parqueos de forma rápida.';
    await Clipboard.setData(const ClipboardData(text: message));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mensaje copiado para compartir.')),
    );
  }

  void _openLegal(BuildContext context, String section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalInformationPage(initialSection: section),
      ),
    );
  }
}

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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.headerBottom.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: context.appBrandIconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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
        ],
      ),
    );
  }
}

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
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.18 : 0.05,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

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
    final textColor =
        onChanged == null
            ? context.appTextSecondaryColor.withValues(alpha: 0.7)
            : context.appTextPrimaryColor;

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
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
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
                      color:
                          onChanged == null
                              ? context.appTextSecondaryColor.withValues(
                                alpha: 0.7,
                              )
                              : context.appTextSecondaryColor,
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

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          backgroundColor: const Color(
            0xFFDC2626,
          ).withValues(alpha: context.isDarkMode ? 0.10 : 0.04),
          side: BorderSide(
            color: const Color(0xFFDC2626).withValues(alpha: 0.45),
            width: 1.3,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text(
          'Cerrar sesión',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}

String _themeLabel(AppThemePreference preference) {
  switch (preference) {
    case AppThemePreference.system:
      return 'Predeterminado del sistema';
    case AppThemePreference.light:
      return 'Claro';
    case AppThemePreference.dark:
      return 'Oscuro';
  }
}

Future<void> _showThemePicker(BuildContext context, WidgetRef ref) async {
  final current = ref.read(appPreferencesProvider).themePreference;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appBorderColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Selecciona un tema',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimaryColor,
              ),
            ),
            const SizedBox(height: 14),
            ...AppThemePreference.values.map((option) {
              final selected = option == current;
              return ListTile(
                tileColor:
                    selected
                        ? context.appBrandIconColor.withValues(
                          alpha: context.isDarkMode ? 0.16 : 0.08,
                        )
                        : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  switch (option) {
                    AppThemePreference.system => Icons.brightness_auto_rounded,
                    AppThemePreference.light => Icons.light_mode_rounded,
                    AppThemePreference.dark => Icons.dark_mode_rounded,
                  },
                  color:
                      selected
                          ? context.appBrandIconColor
                          : context.appTextPrimaryColor,
                ),
                title: Text(
                  _themeLabel(option),
                  style: TextStyle(color: context.appTextPrimaryColor),
                ),
                trailing:
                    selected
                        ? Icon(
                          Icons.check_rounded,
                          color: context.appBrandIconColor,
                        )
                        : null,
                onTap: () async {
                  await ref
                      .read(appPreferencesProvider.notifier)
                      .setThemePreference(option);
                  if (context.mounted) Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      );
    },
  );
}
