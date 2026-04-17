import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/components/ui/app_styles.dart';
import 'package:mapbox_api/common/components/ui/my_text.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';
import 'package:mapbox_api/features/owner/widgets/app_header.dart';
import 'package:mapbox_api/features/auth/providers/auth_providers.dart'
    show authActionsProvider;

class OwnerSettingsPage extends ConsumerStatefulWidget {
  const OwnerSettingsPage({super.key});

  @override
  ConsumerState<OwnerSettingsPage> createState() => _OwnerSettingsPageState();
}

class _OwnerSettingsPageState extends ConsumerState<OwnerSettingsPage> {
  // Notifications
  bool _notifyNewReservation = true;
  bool _notifyExitRequest = true;
  bool _notifyCancellation = true;
  bool _notifyForceCancel = false;

  // Parking behavior
  bool _autoApproveReservations = false;
  bool _requirePlateOnEntry = true;

  @override
  Widget build(BuildContext context) {
    return OwnerOnly(
      builder: (_) {
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
                        value: _notifyNewReservation,
                        onChanged:
                            (v) => setState(() => _notifyNewReservation = v),
                      ),
                      _Divider(),
                      _SwitchRow(
                        icon: Icons.exit_to_app_rounded,
                        iconColor: const Color(0xFF0EA5E9),
                        label: 'Solicitud de salida',
                        sublabel: 'Cuando un usuario pide salir',
                        value: _notifyExitRequest,
                        onChanged:
                            (v) => setState(() => _notifyExitRequest = v),
                      ),
                      _Divider(),
                      _SwitchRow(
                        icon: Icons.cancel_outlined,
                        iconColor: const Color(0xFFF59E0B),
                        label: 'Cancelación',
                        sublabel: 'Solicitudes de cancelación de reservas',
                        value: _notifyCancellation,
                        onChanged:
                            (v) => setState(() => _notifyCancellation = v),
                      ),
                      _Divider(),
                      _SwitchRow(
                        icon: Icons.flag_rounded,
                        iconColor: const Color(0xFFDC2626),
                        label: 'Finalización forzada',
                        sublabel: 'Confirmación al liberar un espacio',
                        value: _notifyForceCancel,
                        onChanged:
                            (v) => setState(() => _notifyForceCancel = v),
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
                        value: _autoApproveReservations,
                        onChanged:
                            (v) => setState(() => _autoApproveReservations = v),
                        badge: _autoApproveReservations ? 'ACTIVO' : null,
                        badgeColor: const Color(0xFF16A34A),
                      ),
                      _Divider(),
                      _SwitchRow(
                        icon: Icons.directions_car_outlined,
                        iconColor: AppColors.headerBottom,
                        label: 'Requerir placa al ingresar',
                        sublabel: 'Valida la placa antes de activar la reserva',
                        value: _requirePlateOnEntry,
                        onChanged:
                            (v) => setState(() => _requirePlateOnEntry = v),
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
                    color: AppColors.headerBottom.withOpacity(0.16),
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
                            color: Colors.white.withOpacity(0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.24),
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
                                      color: AppColors.headerBottom.withOpacity(
                                        0.35,
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
              color: AppColors.headerBottom.withOpacity(0.08),
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A94A6),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.05),
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
      color: AppColors.borderSoft,
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
  final ValueChanged<bool> onChanged;
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
              color: iconColor.withOpacity(0.10),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
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
                          color: badgeColor!.withOpacity(0.12),
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
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A94A6),
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
  final VoidCallback onTap;
  final Widget? trailing;

  const _NavRow({
    required this.icon,
    required this.iconColor,
    required this.label,
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
                color: iconColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
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
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFDC2626).withOpacity(0.25),
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
