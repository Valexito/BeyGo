import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';
import 'package:mapbox_api/features/core/pages/ownerv/widgets/app_header.dart';

// Auth
import 'package:mapbox_api/features/auth/providers/auth_providers.dart'
    show authActionsProvider;

class OwnerSettingsPage extends ConsumerStatefulWidget {
  const OwnerSettingsPage({super.key});

  @override
  ConsumerState<OwnerSettingsPage> createState() => _OwnerSettingsPageState();
}

class _OwnerSettingsPageState extends ConsumerState<OwnerSettingsPage> {
  bool notifications = true;
  bool darkMode =
      false; // TODO: conéctalo a tu provider de tema si ya lo tienes

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return OwnerOnly(
      builder: (_) {
        return Column(
          children: [
            const AppHeader(
              title: 'Settings',
              subtitle: 'Preferences and account',
              showBack: true,
            ),

            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  elevation: 8,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    child: MyText(
                      text: 'Settings',
                      variant: MyTextVariant.bodyBold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  const _GroupHeader(title: 'Preferences'),
                  _SwitchTile(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notification',
                    value: notifications,
                    onChanged: (v) => setState(() => notifications = v),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _SwitchTile(
                    icon: Icons.dark_mode_outlined,
                    label: 'Dark Mode',
                    value: darkMode,
                    onChanged: (v) => setState(() => darkMode = v),
                    isDark: isDark,
                  ),

                  const SizedBox(height: 24),

                  const _GroupHeader(title: 'App'),
                  _NavTile(
                    icon: Icons.star_border_rounded,
                    label: 'Rate App',
                    onTap: _rateApp,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _NavTile(
                    icon: Icons.share_outlined,
                    label: 'Share App',
                    onTap: _shareApp,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 24),

                  const _GroupHeader(title: 'Policies'),
                  _NavTile(
                    icon: Icons.lock_outline_rounded,
                    label: 'Privacy Policy',
                    onTap: () => _openPolicy(context, 'privacy'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _NavTile(
                    icon: Icons.description_outlined,
                    label: 'Terms and Conditions',
                    onTap: () => _openPolicy(context, 'terms'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _NavTile(
                    icon: Icons.cookie_outlined,
                    label: 'Cookies Policy',
                    onTap: () => _openPolicy(context, 'cookies'),
                    isDark: isDark,
                  ),

                  const SizedBox(height: 24),

                  const _GroupHeader(title: 'Support'),
                  _NavTile(
                    icon: Icons.email_outlined,
                    label: 'Contact',
                    onTap: () => _openSupport(context, 'contact'),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  _NavTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Feedback',
                    onTap: () => _openSupport(context, 'feedback'),
                    isDark: isDark,
                  ),

                  const SizedBox(height: 24),

                  _DangerTile(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    onTap: () => _logout(context),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ------- Acciones (placeholder/real) -------

  void _rateApp() {
    _toast('Open store to rate the app');
  }

  void _shareApp() {
    _toast('Share app link');
  }

  void _openPolicy(BuildContext context, String which) {
    _toast('Open $which policy');
  }

  void _openSupport(BuildContext context, String which) {
    _toast('Open $which page');
  }

  Future<void> _logout(BuildContext context) async {
    // Igual que en el Drawer: cierra sesión y navega al login limpiando el stack.
    try {
      // Opcional: pequeño feedback
      _toast('Logging out…');
      await ref.read(authActionsProvider).signOut();
    } catch (_) {
      // Puedes loguear el error si quieres
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ================== UI Helpers ==================

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MyText(text: title, variant: MyTextVariant.bodyBold),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  const _IconBadge({required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg =
        isDark
            ? theme.colorScheme.onSurface.withOpacity(0.08)
            : theme.colorScheme.primary.withOpacity(0.08);
    final ic = isDark ? theme.colorScheme.onSurface : theme.colorScheme.primary;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: ic),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.25),
            ),
          ),
          child: Row(
            children: [
              _IconBadge(icon: icon, isDark: isDark),
              const SizedBox(width: 12),
              Expanded(child: MyText(text: label, variant: MyTextVariant.body)),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          _IconBadge(icon: icon, isDark: isDark),
          const SizedBox(width: 12),
          Expanded(child: MyText(text: label, variant: MyTextVariant.body)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _DangerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _DangerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const color = Colors.redAccent;

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout_rounded, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MyText(text: label, variant: MyTextVariant.bodyBold),
              ),
              const Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
