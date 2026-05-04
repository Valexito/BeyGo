import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/auth/providers/auth_providers.dart'
    show signOutAndNavigateToAuth;
import 'package:beygo/features/users/users.dart';
import 'package:beygo/features/reservations/reservations.dart';
import 'package:beygo/features/owner/owner.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final profile = ref.watch(myProfileStreamProvider).value;
    final photoUrl = user?.photoURL;
    final firestoreName = (profile?['name'] as String?)?.trim();
    final firestoreDisplayName = (profile?['displayName'] as String?)?.trim();
    final authName = user?.displayName?.trim();
    final resolvedName =
        (firestoreName?.isNotEmpty ?? false)
            ? firestoreName!
            : (firestoreDisplayName?.isNotEmpty ?? false)
            ? firestoreDisplayName!
            : (authName?.isNotEmpty ?? false)
            ? authName!
            : 'TU NOMBRE';
    final name = resolvedName.toUpperCase();
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
                      height: 310,
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
                            const SizedBox(height: 250, width: double.infinity),
                            Positioned.fill(
                              child: SafeArea(
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    0,
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          SizedBox(
                                            height: 34,
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: Colors.white.withValues(
                                                    alpha: 0.55,
                                                  ),
                                                ),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (_) =>
                                                            const ConfigureProfilePage(),
                                                  ),
                                                );
                                              },
                                              child: const Text(
                                                'Editar perfil',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: 92,
                                        height: 92,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 3,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 10,
                                              offset: Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: ClipOval(
                                          child:
                                              photoUrl != null
                                                  ? Image.network(
                                                    photoUrl,
                                                    fit: BoxFit.cover,
                                                  )
                                                  : Container(
                                                    color: Colors.white,
                                                    child: const Icon(
                                                      Icons.person,
                                                      size: 54,
                                                      color:
                                                          AppColors
                                                              .headerBottom,
                                                    ),
                                                  ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      MyText(
                                        text: name,
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: MyText(
                                      text: 'Configuración de perfil',
                                      variant: MyTextVariant.title,
                                      customColor:
                                          isDark
                                              ? Colors.white
                                              : AppColors.headerBottom,
                                      fontSize: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  MyText(
                                    text:
                                        'Administra tu cuenta, accesos y opciones principales desde aquí.',
                                    variant: MyTextVariant.subtitle,
                                    fontSize: 13,
                                    customColor: context.appTextSecondaryColor,
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: context.appCardBackground,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: isDark ? 0.28 : 0.07,
                                          ),
                                          blurRadius: 16,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: context.appBorderColor,
                                      ),
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      child: Column(
                                        children: [
                                          _ActionItem(
                                            icon: Icons.lock_outline_rounded,
                                            title: 'Contraseña',
                                            go: _Go.password,
                                          ),
                                          _Divider(),
                                          _ActionItem(
                                            icon: Icons.mail_outline_rounded,
                                            title: 'Correo electrónico',
                                            go: _Go.email,
                                          ),
                                          _Divider(),
                                          _ActionItem(
                                            icon: Icons.support_agent_outlined,
                                            title: 'Soporte',
                                            go: _Go.reportProblem,
                                          ),
                                          _Divider(),
                                          _ActionItem(
                                            icon: Icons.logout_outlined,
                                            title: 'Cerrar sesión',
                                            go: _Go.signout,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: MyText(
                                      text: 'Accesos rápidos',
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
                                            alpha: isDark ? 0.28 : 0.07,
                                          ),
                                          blurRadius: 16,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: context.appBorderColor,
                                      ),
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Column(
                                        children: [
                                          _Shortcut(
                                            icon: Icons.bookmark_added_outlined,
                                            title: 'Mis reservaciones',
                                            go: _Go.reservations,
                                          ),
                                          SizedBox(height: 10),
                                          _Shortcut(
                                            icon: Icons.badge_outlined,
                                            title: 'Registrar un parqueo',
                                            go: _Go.owner,
                                          ),
                                          SizedBox(height: 10),
                                          _Shortcut(
                                            icon:
                                                Icons
                                                    .notifications_active_outlined,
                                            title: 'Notificaciones',
                                            go: _Go.notifications,
                                          ),
                                          SizedBox(height: 10),
                                          _Shortcut(
                                            icon: Icons.delete_forever_outlined,
                                            title: 'Eliminar perfil',
                                            go: _Go.deleteProfile,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
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

enum _Go {
  password,
  email,
  configure,
  reportProblem,
  reservations,
  owner,
  signout,
  deleteProfile,
  notifications,
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.title,
    required this.go,
  });

  final IconData icon;
  final String title;
  final _Go go;

  Future<void> _handleTap(BuildContext context) async {
    switch (go) {
      case _Go.password:
        ProfileSecurityDialogs.handleAction(
          context,
          action: ProfileCredentialAction.password,
        );
        break;
      case _Go.email:
        ProfileSecurityDialogs.handleAction(
          context,
          action: ProfileCredentialAction.email,
        );
        break;
      case _Go.configure:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConfigureProfilePage()),
        );
        break;
      case _Go.reportProblem:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReportProblemPage()),
        );
        break;
      case _Go.signout:
        await signOutAndNavigateToAuth(context);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDanger = go == _Go.signout || go == _Go.deleteProfile;
    final iconColor =
        isDanger
            ? Colors.red
            : (context.isDarkMode
                ? const Color(0xFFE5E7EB)
                : AppColors.headerBottom);
    final textColor = isDanger ? Colors.red : context.appTextPrimaryColor;
    final bgColor =
        isDanger
            ? Colors.red.withValues(alpha: 0.08)
            : context.appIconCircleColor;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        await _handleTap(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color:
                  isDanger ? Colors.red : context.appTextSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.title, required this.go});

  final IconData icon;
  final String title;
  final _Go go;

  void _handleTap(BuildContext context) {
    switch (go) {
      case _Go.reservations:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReservationsPage()),
        );
        break;

      case _Go.owner:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BecomeOwnerPage()),
        );
        break;

      case _Go.notifications:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ConfigurationsPage()),
        );
        break;

      case _Go.reportProblem:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReportProblemPage()),
        );
        break;

      case _Go.deleteProfile:
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        showDialog(
          context: context,
          builder: (_) => const DeleteAccountDialog(),
        );
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDanger = go == _Go.deleteProfile;
    final textColor = isDanger ? Colors.red : context.appTextPrimaryColor;
    final iconColor =
        isDanger
            ? Colors.red
            : (context.isDarkMode
                ? const Color(0xFFE5E7EB)
                : AppColors.headerBottom);
    final bgColor =
        isDanger
            ? Colors.red.withValues(alpha: 0.08)
            : context.appIconCircleColor;
    return Material(
      color:
          isDanger
              ? Colors.red.withValues(alpha: 0.05)
              : context.appCardBackgroundSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.8,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDanger ? Colors.red : context.appTextSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
