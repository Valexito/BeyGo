import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_button.dart';
import 'package:mapbox_api/common/ui/widgets/app_widgets.dart';

class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key});

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final _auth = FirebaseAuth.instance;

  bool get _isPasswordUser =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ??
      false;

  bool get _isGoogleUser =>
      _auth.currentUser?.providerData.any(
        (p) => p.providerId == 'google.com',
      ) ??
      false;

  bool get _isFacebookUser =>
      _auth.currentUser?.providerData.any(
        (p) => p.providerId == 'facebook.com',
      ) ??
      false;

  String get _providerName {
    if (_isGoogleUser) return 'Google';
    if (_isFacebookUser) return 'Facebook';
    return 'Email';
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.headerTop, AppColors.headerBottom],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 18),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Seguridad de cuenta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Provider info banner
                if (!_isPasswordUser) ...[
                  _ProviderBanner(providerName: _providerName),
                  const SizedBox(height: 16),
                ],

                // Email section
                AppSectionCard(
                  title: 'Correo electrónico',
                  titleIcon: Icons.mail_outline_rounded,
                  children: [
                    AppInfoRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Correo actual',
                      value: user.email ?? 'Sin correo',
                    ),
                    const AppInfoRowSpacer(),
                    if (_isPasswordUser)
                      _ActionTile(
                        icon: Icons.edit_outlined,
                        label: 'Cambiar correo',
                        description: 'Requerirá verificar el nuevo correo',
                        onTap: () => _showChangeEmailDialog(context),
                      )
                    else
                      _InfoTile(
                        icon: Icons.info_outline_rounded,
                        message:
                            'Tu correo está vinculado a $_providerName y no puede cambiarse aquí.',
                      ),
                  ],
                  dividers: true,
                ),

                const SizedBox(height: 16),

                // Password section
                AppSectionCard(
                  title: 'Contraseña',
                  titleIcon: Icons.lock_outline_rounded,
                  children: [
                    if (_isPasswordUser) ...[
                      _ActionTile(
                        icon: Icons.lock_reset_rounded,
                        label: 'Cambiar contraseña',
                        description:
                            'Necesitarás ingresar tu contraseña actual',
                        onTap: () => _showChangePasswordDialog(context),
                      ),
                    ] else ...[
                      _ActionTile(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Establecer contraseña',
                        description:
                            'Vincula email/contraseña a tu cuenta de $_providerName',
                        onTap: () => _showLinkPasswordDialog(context),
                        accent: true,
                      ),
                      const AppInfoRowSpacer(),
                      _InfoTile(
                        icon: Icons.lightbulb_outline_rounded,
                        message:
                            'Al establecer una contraseña, podrás iniciar sesión con tu correo además de $_providerName. Ambos métodos funcionarán.',
                      ),
                    ],
                  ],
                  dividers: true,
                ),

                const SizedBox(height: 16),

                // Linked providers
                AppSectionCard(
                  title: 'Métodos de acceso',
                  titleIcon: Icons.security_outlined,
                  children: [
                    ...user.providerData.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ProviderTile(providerId: p.providerId),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Change email (password users) ──────────────────────────────────────────
  Future<void> _showChangeEmailDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ChangeEmailDialog(),
    );
  }

  // ── Change password (password users) ──────────────────────────────────────
  Future<void> _showChangePasswordDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ChangePasswordDialog(),
    );
  }

  // ── Link password to Google/Facebook account ───────────────────────────────
  Future<void> _showLinkPasswordDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (_) => _LinkPasswordDialog(
            currentEmail: _auth.currentUser?.email ?? '',
            providerName: _providerName,
          ),
    );
    // Refresh UI after linking
    if (mounted) setState(() {});
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Change Email Dialog
// ═════════════════════════════════════════════════════════════════════════════
class _ChangeEmailDialog extends StatefulWidget {
  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  final _newEmailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _newEmailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newEmail = _newEmailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (newEmail.isEmpty || password.isEmpty) {
      setState(() => _message = 'Completa todos los campos.');
      return;
    }
    if (!RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$').hasMatch(newEmail)) {
      setState(() => _message = 'El correo no es válido.');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      // Re-authenticate first
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      // Update email
      await user.verifyBeforeUpdateEmail(newEmail);
      setState(() {
        _success = true;
        _message =
            'Te enviamos un correo de verificación a $newEmail. Confírmalo para completar el cambio.';
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _message = _mapError(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'Ese correo ya está en uso.';
      case 'requires-recent-login':
        return 'Sesión expirada. Cierra sesión e inicia de nuevo.';
      default:
        return 'Error al actualizar. Intenta de nuevo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthDialog(
      icon: Icons.mail_outline_rounded,
      title: 'Cambiar correo',
      subtitle: 'Ingresa tu contraseña actual para continuar',
      loading: _loading,
      message: _message,
      isSuccess: _success,
      onConfirm: _success ? () => Navigator.pop(context) : _submit,
      confirmText: _success ? 'Entendido' : 'Actualizar',
      showCancel: !_success,
      children:
          _success
              ? []
              : [
                _DialogLabel('Nuevo correo electrónico'),
                const SizedBox(height: 6),
                _DialogField(
                  controller: _newEmailCtrl,
                  hint: 'nuevo@correo.com',
                  icon: Icons.mail_outline_rounded,
                ),
                const SizedBox(height: 12),
                _DialogLabel('Contraseña actual'),
                const SizedBox(height: 6),
                _DialogField(
                  controller: _passwordCtrl,
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.headerBottom,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Change Password Dialog
// ═════════════════════════════════════════════════════════════════════════════
class _ChangePasswordDialog extends StatefulWidget {
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _message = 'Las contraseñas nuevas no coinciden.');
      return;
    }
    if (_newCtrl.text.length < 8) {
      setState(
        () =>
            _message = 'La nueva contraseña debe tener al menos 8 caracteres.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentCtrl.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newCtrl.text);
      setState(() {
        _success = true;
        _message = 'Tu contraseña fue actualizada exitosamente.';
      });
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
          msg = 'Contraseña actual incorrecta.';
          break;
        case 'requires-recent-login':
          msg = 'Sesión expirada. Cierra sesión e inicia de nuevo.';
          break;
        default:
          msg = 'Error al cambiar contraseña.';
      }
      setState(() => _message = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthDialog(
      icon: Icons.lock_reset_rounded,
      title: 'Cambiar contraseña',
      subtitle: 'Ingresa tu contraseña actual primero',
      loading: _loading,
      message: _message,
      isSuccess: _success,
      onConfirm: _success ? () => Navigator.pop(context) : _submit,
      confirmText: _success ? 'Entendido' : 'Cambiar',
      showCancel: !_success,
      children:
          _success
              ? []
              : [
                _DialogLabel('Contraseña actual'),
                const SizedBox(height: 6),
                _DialogField(
                  controller: _currentCtrl,
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscureCurrent,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.headerBottom,
                    ),
                    onPressed:
                        () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                const SizedBox(height: 12),
                _DialogLabel('Nueva contraseña'),
                const SizedBox(height: 6),
                _DialogField(
                  controller: _newCtrl,
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscureNew,
                  suffix: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.headerBottom,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                const SizedBox(height: 12),
                _DialogLabel('Confirmar nueva contraseña'),
                const SizedBox(height: 6),
                _DialogField(
                  controller: _confirmCtrl,
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  obscure: true,
                ),
              ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Link Password to Google/Facebook account
// ═════════════════════════════════════════════════════════════════════════════
class _LinkPasswordDialog extends StatefulWidget {
  final String currentEmail;
  final String providerName;
  const _LinkPasswordDialog({
    required this.currentEmail,
    required this.providerName,
  });

  @override
  State<_LinkPasswordDialog> createState() => _LinkPasswordDialogState();
}

class _LinkPasswordDialogState extends State<_LinkPasswordDialog> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _message;
  bool _success = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _message = 'Las contraseñas no coinciden.');
      return;
    }
    if (_passwordCtrl.text.length < 8) {
      setState(() => _message = 'Mínimo 8 caracteres.');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: widget.currentEmail,
        password: _passwordCtrl.text,
      );
      await user.linkWithCredential(credential);
      setState(() {
        _success = true;
        _message =
            '¡Listo! Ahora puedes iniciar sesión con tu correo (${widget.currentEmail}) y tu nueva contraseña, además de ${widget.providerName}.';
      });
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Este correo ya tiene contraseña vinculada.';
          break;
        case 'provider-already-linked':
          msg = 'Ya tienes contraseña configurada.';
          break;
        default:
          msg = 'Error al vincular. Intenta de nuevo.';
      }
      setState(() => _message = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthDialog(
      icon: Icons.add_circle_outline_rounded,
      title: 'Establecer contraseña',
      subtitle: 'Se vinculará a: ${widget.currentEmail}',
      loading: _loading,
      message: _message,
      isSuccess: _success,
      onConfirm: _success ? () => Navigator.pop(context) : _link,
      confirmText: _success ? 'Entendido' : 'Establecer',
      showCancel: !_success,
      children:
          _success
              ? []
              : [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.headerBottom.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.headerBottom.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mail_outline_rounded,
                        size: 16,
                        color: AppColors.headerBottom,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.currentEmail,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.headerBottom,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DialogLabel('Nueva contraseña'),
                const SizedBox(height: 6),
                _DialogField(
                  controller: _passwordCtrl,
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AppColors.headerBottom,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                const SizedBox(height: 12),
                _DialogLabel('Confirmar contraseña'),
                const SizedBox(height: 6),
                _DialogField(
                  controller: _confirmCtrl,
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  obscure: true,
                ),
              ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Shared dialog scaffold — consistent with app UI
// ═════════════════════════════════════════════════════════════════════════════
class _AuthDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final String? message;
  final bool isSuccess;
  final VoidCallback onConfirm;
  final String confirmText;
  final bool showCancel;
  final List<Widget> children;

  const _AuthDialog({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.message,
    required this.isSuccess,
    required this.onConfirm,
    required this.confirmText,
    required this.showCancel,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final headerColors =
        isSuccess
            ? [const Color(0xFF16A34A), const Color(0xFF15803D)]
            : [AppColors.headerTop, AppColors.headerBottom];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
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
            // Gradient header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: headerColors,
                ),
                borderRadius: const BorderRadius.only(
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
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.26),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      isSuccess ? Icons.check_circle_outline_rounded : icon,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...children,
                  if (message != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSuccess
                                ? const Color(0xFF16A34A).withOpacity(0.08)
                                : const Color(0xFFDC2626).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSuccess
                                  ? const Color(0xFF16A34A).withOpacity(0.25)
                                  : const Color(0xFFDC2626).withOpacity(0.20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSuccess
                                ? Icons.check_circle_outline_rounded
                                : Icons.info_outline_rounded,
                            size: 16,
                            color:
                                isSuccess
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              message!,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isSuccess
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFB91C1C),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (showCancel) ...[
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed:
                                  loading ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.headerBottom.withOpacity(
                                    0.28,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: Colors.white,
                              ),
                              child: Text(
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
                      ],
                      Expanded(
                        child: MyButton(
                          text: loading ? 'Procesando...' : confirmText,
                          loading: loading,
                          height: 46,
                          onTap: loading ? null : onConfirm,
                          margin: EdgeInsets.zero,
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
    );
  }
}

// ─── Small helpers ─────────────────────────────────────────────────────────
class _DialogLabel extends StatelessWidget {
  final String label;
  const _DialogLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1E293B),
    ),
  );
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;

  const _DialogField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF8A94A6)),
        prefixIcon: Icon(icon, size: 16, color: AppColors.headerBottom),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.headerBottom.withOpacity(0.4),
            width: 1.2,
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool accent;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (accent
                        ? const Color(0xFF16A34A)
                        : AppColors.headerBottom)
                    .withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 17,
                color:
                    accent ? const Color(0xFF16A34A) : AppColors.headerBottom,
              ),
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
                      fontWeight: FontWeight.w700,
                      color:
                          accent
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A94A6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String message;
  const _InfoTile({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.headerBottom.withOpacity(0.6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A94A6)),
          ),
        ),
      ],
    );
  }
}

class _ProviderBanner extends StatelessWidget {
  final String providerName;
  const _ProviderBanner({required this.providerName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.headerBottom.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.headerBottom.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.headerBottom.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 18,
              color: AppColors.headerBottom,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta vinculada a $providerName',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headerBottom,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tu correo es administrado por $providerName. Puedes agregar una contraseña para iniciar sesión también con email.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A94A6),
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

class _ProviderTile extends StatelessWidget {
  final String providerId;
  const _ProviderTile({required this.providerId});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String name;
    Color color;

    switch (providerId) {
      case 'google.com':
        icon = Icons.g_mobiledata_rounded;
        name = 'Google';
        color = const Color(0xFFDB4437);
        break;
      case 'facebook.com':
        icon = Icons.facebook_rounded;
        name = 'Facebook';
        color = const Color(0xFF1877F2);
        break;
      case 'password':
        icon = Icons.email_outlined;
        name = 'Email / Contraseña';
        color = AppColors.headerBottom;
        break;
      case 'apple.com':
        icon = Icons.apple_rounded;
        name = 'Apple';
        color = Colors.black;
        break;
      default:
        icon = Icons.device_unknown_outlined;
        name = providerId;
        color = AppColors.textSecondary;
    }

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF16A34A).withOpacity(0.25),
            ),
          ),
          child: const Text(
            'ACTIVO',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF16A34A),
            ),
          ),
        ),
      ],
    );
  }
}
