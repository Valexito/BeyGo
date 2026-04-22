import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_text.dart';
import 'package:mapbox_api/common/services/app_preferences_service.dart';
import 'package:mapbox_api/features/core/providers/firebase_providers.dart'
    show currentUserProvider;
import 'package:mapbox_api/features/core/providers/app_preferences_provider.dart';
import 'package:mapbox_api/features/users/providers/user_providers.dart'
    show myNotificationSettingsStreamProvider, saveNotificationSettingsProvider;

class ConfigurationsPage extends ConsumerWidget {
  const ConfigurationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final uid = user?.uid;
    final isDark = context.isDarkMode;
    final headerGradient =
        isDark
            ? const [
              Color(0xFF111827),
              Color(0xFF0F172A),
              Color(0xFF0B1220),
            ]
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
                          color: (isDark ? Colors.white : Colors.white)
                              .withValues(alpha: isDark ? 0.04 : 0.12),
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
                          color: (isDark ? Colors.white : Colors.white)
                              .withValues(alpha: isDark ? 0.03 : 0.10),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Stack(
                          children: [
                            SizedBox(
                              height: 235,
                              width: double.infinity,
                            ),
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
                                      children: [
                                        Icon(
                                          Icons.settings_outlined,
                                          color: Colors.white,
                                          size: 52,
                                        ),
                                        const SizedBox(height: 12),
                                        const MyText(
                                          text: 'Configuraciones',
                                          variant: MyTextVariant.title,
                                          customColor: Colors.white,
                                          textAlign: TextAlign.center,
                                          fontSize: 28,
                                        ),
                                        const SizedBox(height: 6),
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
                                20,
                                28,
                                20,
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

        Future<void> saveNotificationToggle(
          String key,
          bool value,
        ) async {
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
            Align(
              alignment: Alignment.centerLeft,
              child: MyText(
                text: 'Preferencias de la app',
                variant: MyTextVariant.title,
                customColor:
                    context.isDarkMode
                        ? Colors.white
                        : AppColors.headerBottom,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            MyText(
              text:
                  'Administra tus notificaciones y preferencias generales desde aquí.',
              variant: MyTextVariant.subtitle,
              fontSize: 13,
              customColor: context.appTextSecondaryColor,
            ),
            const SizedBox(height: 24),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: MyText(
                text: 'Notificaciones',
                variant: MyTextVariant.normal,
                fontSize: 13,
                customColor: context.appTextPrimaryColor,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: context.appCardBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: context.isDarkMode ? 0.22 : 0.07,
                    ),
                    blurRadius: context.isDarkMode ? 20 : 16,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: context.appBorderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  children: [
                    _SwitchActionItem(
                      icon: Icons.notifications_active_outlined,
                      title: 'Activadas',
                      subtitle: 'Permitir alertas mientras usas la app',
                      value: enabled,
                      onChanged: (v) => saveNotificationToggle('enabled', v),
                    ),
                    const _Divider(),
                    _SwitchActionItem(
                      icon: Icons.alarm_on_outlined,
                      title: 'Recordatorios',
                      subtitle: 'Antes de iniciar o terminar una reservación',
                      value: reminders,
                      onChanged:
                          enabled
                              ? (v) => saveNotificationToggle('reminders', v)
                              : null,
                    ),
                    const _Divider(),
                    _SwitchActionItem(
                      icon: Icons.system_update_alt_rounded,
                      title: 'Actualizaciones',
                      subtitle: 'Cambios importantes y estado del servicio',
                      value: updates,
                      onChanged:
                          enabled
                              ? (v) => saveNotificationToggle('updates', v)
                              : null,
                    ),
                    const _Divider(),
                    _SwitchActionItem(
                      icon: Icons.volume_up_outlined,
                      title: 'Sonido',
                      subtitle: 'Reproducir sonido en notificaciones visibles',
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
              ),
            ),

            const SizedBox(height: 18),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: MyText(
                text: 'Preferencias generales',
                variant: MyTextVariant.normal,
                fontSize: 13,
                customColor: context.appTextPrimaryColor,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: context.appCardBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: context.isDarkMode ? 0.22 : 0.07,
                    ),
                    blurRadius: context.isDarkMode ? 20 : 16,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: context.appBorderColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    _ArrowActionItem(
                      icon: Icons.palette_outlined,
                      title: 'Tema',
                      subtitle: _themeLabel(preferences.themePreference),
                      onTap: () => _showThemePicker(context, ref),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: MyText(
                text:
                    'Estos ajustes se guardan en tu cuenta y puedes cambiarlos cuando quieras.',
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
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Divider(height: 1, thickness: 1, color: context.appBorderColor),
    );
  }
}

class _SwitchActionItem extends StatelessWidget {
  const _SwitchActionItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textColor =
        onChanged == null
            ? context.appTextSecondaryColor.withValues(alpha: 0.7)
            : context.appTextPrimaryColor;
    final subtitleColor =
        onChanged == null
            ? context.appTextSecondaryColor.withValues(alpha: 0.7)
            : context.appTextSecondaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.appIconCircleColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color:
                  onChanged == null
                      ? context.appTextSecondaryColor
                      : AppColors.headerBottom,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.headerBottom,
          ),
        ],
      ),
    );
  }
}

class _ArrowActionItem extends StatelessWidget {
  const _ArrowActionItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appCardBackgroundSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.appIconCircleColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: AppColors.headerBottom),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.8,
                        color: context.appTextPrimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.appTextSecondaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.appTextSecondaryColor,
              ),
            ],
          ),
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
                        ? AppColors.headerBottom.withValues(
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
                          ? AppColors.headerBottom
                          : context.appTextPrimaryColor,
                ),
                title: Text(
                  _themeLabel(option),
                  style: TextStyle(color: context.appTextPrimaryColor),
                ),
                trailing:
                    selected
                        ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.headerBottom,
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
