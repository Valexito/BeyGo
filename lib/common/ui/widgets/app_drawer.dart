import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:mapbox_api/common/ui/components/app_styles.dart';

import 'package:mapbox_api/features/core/pages/userv/configurations_page.dart';
import 'package:mapbox_api/features/core/pages/userv/frequent_questions_page.dart';
import 'package:mapbox_api/features/core/pages/userv/legal_information_page.dart';
import 'package:mapbox_api/features/core/pages/userv/report_problem_page.dart';
import 'package:mapbox_api/features/reservations/pages/reservations_page.dart';
import 'package:mapbox_api/features/core/pages/userv/favorites_page.dart';
import 'package:mapbox_api/features/users/pages/profile_page.dart';
import 'package:mapbox_api/features/auth/providers/auth_providers.dart'
    show authUserStreamProvider, authActionsProvider;

final _drawerProfileProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
      final authAsync = ref.watch(authUserStreamProvider);
      final uid = authAsync.valueOrNull?.uid;
      if (uid == null) return Stream.value(null);

      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((snap) => snap.data());
    });

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  Future<void> _openFromDrawer(BuildContext context, Widget page) async {
    final scaffoldState = Scaffold.maybeOf(context);
    Navigator.of(context).pop();
    await Navigator.of(
      scaffoldState!.context,
    ).push(MaterialPageRoute(builder: (_) => page));
    if (scaffoldState.mounted) scaffoldState.openDrawer();
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    Navigator.of(context).pop();
    await ref.read(authActionsProvider).signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
  }

  String? _resolvePhoto(fb.User? u, Map<String, dynamic>? profile) {
    // 1. Firestore profile photo
    final fsPhoto = profile?['photoURL'] as String?;
    if (fsPhoto != null && fsPhoto.isNotEmpty) return fsPhoto;

    // 2. Firebase Auth photo (Google, etc.)
    if (u == null) return null;
    String? url = u.photoURL;
    if (url == null || url.isEmpty) {
      for (final p in u.providerData) {
        final pUrl = p.photoURL;
        if (pUrl != null && pUrl.isNotEmpty) {
          url = pUrl;
          break;
        }
      }
    }
    if (url == null) return null;
    if (url.contains('googleusercontent.com')) {
      url = url.replaceFirst(RegExp(r'/s\d+-'), '/s200-');
    }
    return url;
  }

  String _resolveName(fb.User? user, Map<String, dynamic>? profile) {
    // ✅ Priority: Firestore 'name' → Firestore 'displayName' → Auth displayName → fallback
    final fsName = (profile?['name'] as String?)?.trim();
    if (fsName != null && fsName.isNotEmpty) return fsName;

    final fsDisplay = (profile?['displayName'] as String?)?.trim();
    if (fsDisplay != null && fsDisplay.isNotEmpty) return fsDisplay;

    final authName = user?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) return authName;

    return 'Mi perfil';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authUserStreamProvider);
    final profileAsync = ref.watch(_drawerProfileProvider);

    return userAsync.when(
      loading:
          () => const Drawer(child: Center(child: CircularProgressIndicator())),
      error:
          (e, _) => Drawer(child: Center(child: Text('Error de sesión: $e'))),
      data: (user) {
        final profile = profileAsync.valueOrNull;
        final displayName = _resolveName(user, profile);
        final email = user?.email ?? '';
        final photoUrl = _resolvePhoto(user, profile);
        final isDark = context.isDarkMode;
        final headerGradient =
            isDark
                ? const [
                  Color(0xFF111827),
                  Color(0xFF0F172A),
                  Color(0xFF0B1220),
                ]
                : const [AppColors.headerTop, AppColors.headerBottom];

        return Drawer(
          backgroundColor: context.appCardBackground,
          surfaceTintColor: Colors.transparent,
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 54, bottom: 28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: headerGradient,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 12,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child:
                                photoUrl != null
                                    ? Image.network(
                                      photoUrl,
                                      key: ValueKey(user?.uid),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) => _DefaultAvatar(),
                                    )
                                    : _DefaultAvatar(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            displayName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              email,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.04 : 0.09,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 60,
                    left: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.03 : 0.07,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  children: [
                    _SectionLabel(label: 'Principal'),
                    _DrawerItem(
                      icon: Icons.bookmark_added_outlined,
                      label: 'Mis reservaciones',
                      onTap:
                          () => _openFromDrawer(
                            context,
                            const ReservationsPage(),
                          ),
                    ),
                    _DrawerItem(
                      icon: Icons.favorite_outline_rounded,
                      label: 'Favoritos',
                      onTap:
                          () => _openFromDrawer(context, const FavoritesPage()),
                    ),
                    _DrawerItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Mi perfil',
                      onTap:
                          () => _openFromDrawer(context, const ProfilePage()),
                    ),
                    _DrawerItem(
                      icon: Icons.settings_outlined,
                      label: 'Configuraciones',
                      onTap:
                          () => _openFromDrawer(
                            context,
                            const ConfigurationsPage(),
                          ),
                    ),
                    const SizedBox(height: 6),
                    _SectionLabel(label: 'Soporte'),
                    _DrawerItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Preguntas frecuentes',
                      onTap:
                          () => _openFromDrawer(
                            context,
                            const FrequentQuestionsPage(),
                          ),
                    ),
                    _DrawerItem(
                      icon: Icons.gavel_outlined,
                      label: 'Información legal',
                      onTap:
                          () => _openFromDrawer(
                            context,
                            const LegalInformationPage(),
                          ),
                    ),
                    _DrawerItem(
                      icon: Icons.flag_outlined,
                      label: 'Reportar un problema',
                      onTap:
                          () => _openFromDrawer(
                            context,
                            const ReportProblemPage(),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Divider(color: context.appBorderColor, height: 1),
                    const SizedBox(height: 6),
                    _DrawerItem(
                      icon: Icons.logout_rounded,
                      label: 'Cerrar sesión',
                      danger: true,
                      onTap: () => _signOut(context, ref),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DefaultAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white.withValues(alpha: 0.18),
    child: const Icon(Icons.person_rounded, size: 48, color: Colors.white),
  );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: context.appTextSecondaryColor.withValues(alpha: 0.6),
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _DrawerItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color activeColor =
        widget.danger ? const Color(0xFFDC2626) : AppColors.headerBottom;
    final Color bg =
        _pressed ? activeColor.withValues(alpha: 0.08) : Colors.transparent;
    final Color textColor =
        _pressed
            ? activeColor
            : (widget.danger
                ? const Color(0xFFDC2626)
                : context.appTextPrimaryColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        _pressed
                            ? activeColor.withValues(alpha: 0.10)
                            : (widget.danger
                                ? const Color(
                                  0xFFDC2626,
                                ).withValues(alpha: 0.08)
                                : context.appIconCircleColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, size: 18, color: activeColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color:
                      _pressed
                          ? activeColor
                          : context.appTextSecondaryColor.withValues(
                            alpha: 0.5,
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
