import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/common/utils/components/ui/navy_header.dart';
import 'package:mapbox_api/features/core/pages/userv/report_problem_page.dart';
import 'package:mapbox_api/features/users/widgets/delete_account_dialog.dart';
import 'package:mapbox_api/features/users/widgets/profile_security_dialogs.dart';
import 'package:mapbox_api/features/users/pages/configure_profile_page.dart';
import 'package:mapbox_api/features/reservations/pages/reservations_page.dart';
import 'package:mapbox_api/features/owner/widgets/become_owner_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = user?.photoURL;
    final name =
        (user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!.trim().toUpperCase()
            : 'TU NOMBRE';

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
                      height: 310,
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
                            NavyHeader(
                              height: 250,
                              roundedBottom: false,
                              trailing: SizedBox(
                                height: 34,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.55),
                                    ),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => const ConfigureProfilePage(),
                                      ),
                                    );
                                  },
                                  child: const Text('Editar perfil'),
                                ),
                              ),
                              children: [
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
                                                color: AppColors.headerBottom,
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: MyText(
                                      text: 'Configuración de perfil',
                                      variant: MyTextVariant.title,
                                      customColor: AppColors.headerBottom,
                                      fontSize: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const MyText(
                                    text:
                                        'Administra tu cuenta, accesos y opciones principales desde aquí.',
                                    variant: MyTextVariant.subtitle,
                                    fontSize: 13,
                                  ),
                                  const SizedBox(height: 24),
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
                                      border: Border.all(
                                        color: const Color(0xFFE8EEF5),
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
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: MyText(
                                      text: 'Accesos rápidos',
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
                                      border: Border.all(
                                        color: const Color(0xFFE8EEF5),
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Divider(height: 1, thickness: 1, color: Color(0xFFE8EEF5)),
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
  none,
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
        await FirebaseAuth.instance.signOut();

        if (!context.mounted) return;

        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/auth', (route) => false);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDanger = go == _Go.signout || go == _Go.deleteProfile;

    final iconColor = isDanger ? Colors.red : AppColors.headerBottom;
    final textColor = isDanger ? Colors.red : AppColors.textPrimary;
    final bgColor =
        isDanger ? Colors.red.withOpacity(0.08) : const Color(0xFFEAF3FF);

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
              color: isDanger ? Colors.red : AppColors.textSecondary,
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
          MaterialPageRoute(builder: (_) => const ReportProblemPage()),
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
    final textColor = isDanger ? Colors.red : AppColors.textPrimary;
    final iconColor = isDanger ? Colors.red : AppColors.headerBottom;
    final bgColor =
        isDanger ? Colors.red.withOpacity(0.08) : const Color(0xFFEAF3FF);
    return Material(
      color: isDanger ? Colors.red.withOpacity(0.05) : const Color(0xFFF4F8FC),
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
                color: isDanger ? Colors.red : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
