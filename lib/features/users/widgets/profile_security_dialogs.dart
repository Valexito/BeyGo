import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/auth/providers/auth_providers.dart'
    show signOutAndNavigateToAuth;

enum ProfileCredentialAction { password, email }

class ProfileSecurityDialogs {
  static bool _isGoogleUser(User user) {
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  static bool _isEmailPasswordUser(User user) {
    return user.providerData.any((p) => p.providerId == 'password');
  }

  static Future<void> handleAction(
    BuildContext context, {
    required ProfileCredentialAction action,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        context,
        title: 'Sesión no encontrada',
        message: 'Debes iniciar sesión nuevamente.',
      );
      return;
    }

    if (_isGoogleUser(user) && !_isEmailPasswordUser(user)) {
      final text =
          action == ProfileCredentialAction.password
              ? 'Has iniciado sesión con Google. No puedes actualizar tu contraseña desde aquí.'
              : 'Has iniciado sesión con Google. No puedes actualizar tu correo desde aquí.';
      _showMessage(context, title: 'Cuenta de Google', message: text);
      return;
    }

    if (!_isEmailPasswordUser(user)) {
      _showMessage(
        context,
        title: 'No disponible',
        message: 'Esta acción no está disponible para tu tipo de cuenta.',
      );
      return;
    }

    if (action == ProfileCredentialAction.password) {
      await _showChangePasswordDialog(context);
      return;
    }

    await _showChangeEmailDialog(context);
  }

  static Future<void> _showChangeEmailDialog(BuildContext context) async {
    final password = TextEditingController();
    final newEmail = TextEditingController();

    bool obscurePassword = true;
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final user = FirebaseAuth.instance.currentUser;
              final currentEmail = user?.email?.trim() ?? '';

              if (user == null || currentEmail.isEmpty) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                _showMessage(
                  context,
                  title: 'Error',
                  message: 'No fue posible validar tu cuenta.',
                );
                return;
              }

              final nextEmail = newEmail.text.trim();

              if (password.text.trim().isEmpty || nextEmail.isEmpty) {
                _showSnack(context, 'Completa todos los campos.');
                return;
              }

              if (nextEmail.toLowerCase() == currentEmail.toLowerCase()) {
                _showSnack(context, 'Ingresa un correo diferente.');
                return;
              }

              try {
                setState(() => isLoading = true);

                final credential = EmailAuthProvider.credential(
                  email: currentEmail,
                  password: password.text.trim(),
                );

                await user.reauthenticateWithCredential(credential);
                await user.verifyBeforeUpdateEmail(nextEmail);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                await _showMessageAwait(
                  context,
                  title: 'Verificación enviada',
                  message:
                      'Te enviamos un correo de verificación a $nextEmail. Después de confirmarlo, inicia sesión nuevamente con tu nuevo correo para completar el cambio.',
                );

                await signOutAndNavigateToAuth(
                  context,
                  message: 'Actualizando sesión...',
                  submessage:
                      'Te llevaremos al acceso para completar el cambio.',
                );
              } on FirebaseAuthException catch (e) {
                _showSnack(context, _firebaseMessage(e));
              } catch (_) {
                _showSnack(context, 'No se pudo actualizar el correo.');
              } finally {
                if (context.mounted) {
                  setState(() => isLoading = false);
                }
              }
            }

            return _buildDialogShell(
              context: context,
              title: 'Actualizar correo',
              icon: Icons.mail_outline_rounded,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MyTextField(
                    controller: newEmail,
                    hintText: 'Nuevo correo electrónico',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline_rounded,
                    margin: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),
                  MyTextField(
                    controller: password,
                    hintText: 'Contraseña actual',
                    obscureText: obscurePassword,
                    prefixIcon: Icons.lock_outline_rounded,
                    margin: EdgeInsets.zero,
                    suffix: IconButton(
                      onPressed: () {
                        setState(() => obscurePassword = !obscurePassword);
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: context.appTextSecondaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              actions: _buildDialogActions(
                context: context,
                isLoading: isLoading,
                onCancel: () => Navigator.of(dialogContext).pop(),
                onConfirm: submit,
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final user = FirebaseAuth.instance.currentUser;
              final email = user?.email ?? '';

              if (user == null || email.isEmpty) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                _showMessage(
                  context,
                  title: 'Error',
                  message: 'No fue posible validar tu cuenta.',
                );
                return;
              }

              if (currentPassword.text.trim().isEmpty ||
                  newPassword.text.trim().isEmpty ||
                  confirmPassword.text.trim().isEmpty) {
                _showSnack(context, 'Completa todos los campos.');
                return;
              }

              if (newPassword.text.trim().length < 6) {
                _showSnack(
                  context,
                  'La nueva contraseña debe tener al menos 6 caracteres.',
                );
                return;
              }

              if (newPassword.text.trim() != confirmPassword.text.trim()) {
                _showSnack(context, 'Las contraseñas nuevas no coinciden.');
                return;
              }

              try {
                setState(() => isLoading = true);

                final credential = EmailAuthProvider.credential(
                  email: email,
                  password: currentPassword.text.trim(),
                );

                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(newPassword.text.trim());

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                _showMessage(
                  context,
                  title: 'Contraseña actualizada',
                  message: 'Tu contraseña fue actualizada correctamente.',
                );
              } on FirebaseAuthException catch (e) {
                _showSnack(context, _firebaseMessage(e));
              } catch (_) {
                _showSnack(context, 'No se pudo actualizar la contraseña.');
              } finally {
                if (context.mounted) {
                  setState(() => isLoading = false);
                }
              }
            }

            return _buildDialogShell(
              context: context,
              title: 'Actualizar contraseña',
              icon: Icons.lock_reset_outlined,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MyTextField(
                    controller: currentPassword,
                    hintText: 'Contraseña actual',
                    obscureText: obscureCurrent,
                    prefixIcon: Icons.lock_outline_rounded,
                    margin: EdgeInsets.zero,
                    suffix: IconButton(
                      onPressed: () {
                        setState(() => obscureCurrent = !obscureCurrent);
                      },
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: context.appTextSecondaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  MyTextField(
                    controller: newPassword,
                    hintText: 'Nueva contraseña',
                    obscureText: obscureNew,
                    prefixIcon: Icons.lock_reset_outlined,
                    margin: EdgeInsets.zero,
                    suffix: IconButton(
                      onPressed: () {
                        setState(() => obscureNew = !obscureNew);
                      },
                      icon: Icon(
                        obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: context.appTextSecondaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  MyTextField(
                    controller: confirmPassword,
                    hintText: 'Confirmar nueva contraseña',
                    obscureText: obscureConfirm,
                    prefixIcon: Icons.verified_user_outlined,
                    margin: EdgeInsets.zero,
                    suffix: IconButton(
                      onPressed: () {
                        setState(() => obscureConfirm = !obscureConfirm);
                      },
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: context.appTextSecondaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              actions: _buildDialogActions(
                context: context,
                isLoading: isLoading,
                onCancel: () => Navigator.of(dialogContext).pop(),
                onConfirm: submit,
              ),
            );
          },
        );
      },
    );
  }

  static void _showMessage(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return _buildDialogShell(
          context: dialogContext,
          title: title,
          icon: Icons.info_outline_rounded,
          body: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: dialogContext.appTextPrimaryColor,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: MyButton(
                text: 'Aceptar',
                onTap: () => Navigator.of(dialogContext).pop(),
                margin: EdgeInsets.zero,
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _showMessageAwait(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return _buildDialogShell(
          context: dialogContext,
          title: title,
          icon: Icons.mark_email_read_outlined,
          body: Text(
            message,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: dialogContext.appTextPrimaryColor,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: MyButton(
                text: 'Aceptar',
                onTap: () => Navigator.of(dialogContext).pop(),
                margin: EdgeInsets.zero,
              ),
            ),
          ],
        );
      },
    );
  }

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _firebaseMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'La contraseña actual no es correcta.';
      case 'weak-password':
        return 'La nueva contraseña es demasiado débil.';
      case 'email-already-in-use':
        return 'Ese correo ya está en uso.';
      case 'invalid-email':
        return 'El correo ingresado no es válido.';
      case 'requires-recent-login':
        return 'Por seguridad, vuelve a iniciar sesión e inténtalo de nuevo.';
      case 'network-request-failed':
        return 'Error de red. Intenta nuevamente.';
      default:
        return e.message ?? 'Ocurrió un error inesperado.';
    }
  }

  static Widget _buildDialogShell({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget body,
    required List<Widget> actions,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.appBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDarkMode ? 0.28 : 0.12,
              ),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.appIconCircleColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: context.appBrandIconColor, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimaryColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 14),
              body,
              const SizedBox(height: 18),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }

  static List<Widget> _buildDialogActions({
    required BuildContext context,
    required bool isLoading,
    required VoidCallback onCancel,
    required VoidCallback onConfirm,
  }) {
    return [
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: isLoading ? null : onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.appTextSecondaryColor,
                  backgroundColor: context.appCardBackgroundSoft,
                  side: BorderSide(color: context.appBorderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDims.radiusLg),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MyButton(
              text: isLoading ? 'Guardando...' : 'Guardar',
              loading: isLoading,
              onTap: isLoading ? null : onConfirm,
              margin: EdgeInsets.zero,
              height: 48,
            ),
          ),
        ],
      ),
    ];
  }
}
