import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/common/utils/components/ui/navy_header.dart';
import 'package:mapbox_api/features/core/providers/firebase_providers.dart'
    show currentUserProvider;
import 'package:mapbox_api/features/users/providers/user_providers.dart'
    show myNotificationSettingsStreamProvider, saveNotificationSettingsProvider;

class ConfigurationsPage extends ConsumerWidget {
  const ConfigurationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final uid = user?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
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
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.headerTop, AppColors.headerBottom],
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
                          color: Colors.white.withOpacity(0.12),
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
                          color: Colors.white.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Stack(
                          children: [
                            const NavyHeader(
                              height: 235,
                              roundedBottom: false,
                              children: [
                                Icon(
                                  Icons.settings_outlined,
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
                              ],
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
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.only(
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
        final enabled = (data?['enabled'] as bool?) ?? true;
        final reminders = (data?['reminders'] as bool?) ?? true;
        final marketing = (data?['marketing'] as bool?) ?? false;
        final updates = (data?['updates'] as bool?) ?? true;

        Future<void> savePartial(Map<String, dynamic> values) async {
          await ref.read(saveNotificationSettingsProvider).call(uid, values);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: MyText(
                text: 'Preferencias de la app',
                variant: MyTextVariant.title,
                customColor: AppColors.headerBottom,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            const MyText(
              text:
                  'Administra tus notificaciones y preferencias generales desde aquí.',
              variant: MyTextVariant.subtitle,
              fontSize: 13,
            ),
            const SizedBox(height: 24),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: MyText(
                text: 'Notificaciones',
                variant: MyTextVariant.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE8EEF5)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  children: [
                    _SwitchActionItem(
                      icon: Icons.notifications_active_outlined,
                      title: 'Activadas',
                      subtitle: 'Permitir notificaciones de la app',
                      value: enabled,
                      onChanged: (v) => savePartial({'enabled': v}),
                    ),
                    const _Divider(),
                    _SwitchActionItem(
                      icon: Icons.alarm_on_outlined,
                      title: 'Recordatorios',
                      subtitle: 'Antes de iniciar o terminar una reservación',
                      value: reminders,
                      onChanged: (v) => savePartial({'reminders': v}),
                    ),
                    const _Divider(),
                    _SwitchActionItem(
                      icon: Icons.system_update_alt_rounded,
                      title: 'Actualizaciones',
                      subtitle: 'Cambios importantes y estado del servicio',
                      value: updates,
                      onChanged: (v) => savePartial({'updates': v}),
                    ),
                    const _Divider(),
                    _SwitchActionItem(
                      icon: Icons.local_offer_outlined,
                      title: 'Promociones',
                      subtitle: 'Ofertas y recomendaciones personalizadas',
                      value: marketing,
                      onChanged: (v) => savePartial({'marketing': v}),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: MyText(
                text: 'Preferencias generales',
                variant: MyTextVariant.normal,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE8EEF5)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Column(
                  children: [
                    _ArrowActionItem(
                      icon: Icons.translate_rounded,
                      title: 'Idioma',
                      subtitle: 'Español',
                    ),
                    SizedBox(height: 10),
                    _ArrowActionItem(
                      icon: Icons.palette_outlined,
                      title: 'Tema',
                      subtitle: 'Predeterminado del sistema',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: MyText(
                text:
                    'Estos ajustes se guardan en tu cuenta y puedes cambiarlos cuando quieras.',
                variant: MyTextVariant.bodyMuted,
                fontSize: 12,
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFE8EEF5)),
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
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF3FF),
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
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
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
      color: const Color(0xFFF4F8FC),
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
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF3FF),
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
                      style: const TextStyle(
                        fontSize: 14.8,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
