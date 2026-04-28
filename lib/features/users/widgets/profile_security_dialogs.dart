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

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const MyText(
                text: 'Actualizar correo',
                variant: MyTextVariant.title,
                customColor: AppColors.headerBottom,
              ),
              content: SingleChildScrollView(
                child: Column(
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
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed:
                      isLoading
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                SizedBox(
                  width: 150,
                  child: MyButton(
                    text: isLoading ? 'Guardando...' : 'Guardar',
                    loading: isLoading,
                    onTap: isLoading ? null : submit,
                    margin: EdgeInsets.zero,
                  ),
                ),
              ],
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

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const MyText(
                text: 'Actualizar contraseña',
                variant: MyTextVariant.title,
                customColor: AppColors.headerBottom,
              ),
              content: SingleChildScrollView(
                child: Column(
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
                          color: AppColors.textSecondary,
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
                          color: AppColors.textSecondary,
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
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed:
                      isLoading
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                SizedBox(
                  width: 150,
                  child: MyButton(
                    text: isLoading ? 'Guardando...' : 'Guardar',
                    loading: isLoading,
                    onTap: isLoading ? null : submit,
                    margin: EdgeInsets.zero,
                  ),
                ),
              ],
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
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: MyText(
            text: title,
            variant: MyTextVariant.title,
            customColor: AppColors.headerBottom,
          ),
          content: MyText(text: message, variant: MyTextVariant.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Aceptar'),
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
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: MyText(
            text: title,
            variant: MyTextVariant.title,
            customColor: AppColors.headerBottom,
          ),
          content: MyText(text: message, variant: MyTextVariant.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Aceptar'),
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
}
