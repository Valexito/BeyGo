import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_api/common/ui/components/my_text.dart';
import 'package:mapbox_api/common/ui/components/my_textfield.dart';

class ResetPasswordDialog extends StatefulWidget {
  final String? initialEmail; // usa el email logueado si no lo pasas
  const ResetPasswordDialog({super.key, this.initialEmail});

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final _emailCtrl = TextEditingController();
  String? _message;
  bool _sending = false;
  bool _editable = false;

  static const _navyDark = Color(0xFF0D1B2A);
  static const _navyLight = Color(0xFF1B3A57);
  static const _iconColor = _navyLight;
  static const _btnH = 40.0;
  static const _btnW = 120.0; // <-- mismo ancho para ambos botones

  @override
  void initState() {
    super.initState();
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    _emailCtrl.text =
        (widget.initialEmail?.trim().isNotEmpty ?? false)
            ? widget.initialEmail!.trim()
            : currentEmail;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailCtrl.text.trim();
    final isEmail = RegExp(
      r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$',
    ).hasMatch(email);
    if (!isEmail) {
      setState(() => _message = 'Escribe un correo válido.');
      return;
    }

    setState(() {
      _sending = true;
      _message = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(
        () =>
            _message = 'Te enviamos un enlace para restablecer tu contraseña.',
      );
    } on FirebaseAuthException catch (e) {
      var msg = 'Ocurrió un error. Intenta de nuevo.';
      if (e.code == 'invalid-email') msg = 'El correo no es válido.';
      if (e.code == 'user-not-found')
        msg = 'No existe una cuenta con ese correo.';
      setState(() => _message = msg);
    } catch (_) {
      setState(() => _message = 'Ocurrió un error inesperado.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MyText(
              text: 'REESTABLECER CONTRASEÑA',
              variant: MyTextVariant.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const MyText(
              text:
                  'Te enviaremos un enlace para restablecer/cambiar tu contraseña.',
              variant: MyTextVariant.bodyMuted,
              textAlign: TextAlign.center,
              fontSize: 13,
            ),
            const SizedBox(height: 16),

            // Email + lápiz/check
            Row(
              children: [
                Expanded(
                  child: MyTextField(
                    controller: _emailCtrl,
                    hintText: 'Correo electrónico',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    obscureText: false,
                    prefixIcon: Icons.mail_outline,
                    margin: EdgeInsets.zero,
                    readOnly: !_editable,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _editable = !_editable),
                      child: Center(
                        child: Tooltip(
                          message: _editable ? 'Listo' : 'Editar',
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder:
                                (c, a) => ScaleTransition(scale: a, child: c),
                            child: Icon(
                              _editable
                                  ? Icons.check_rounded
                                  : Icons.edit_rounded,
                              key: ValueKey(_editable),
                              color: _iconColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_message != null) ...[
              const SizedBox(height: 12),
              MyText(
                text: _message!,
                variant: MyTextVariant.body,
                textAlign: TextAlign.center,
                fontSize: 12,
              ),
            ],
            const SizedBox(height: 18),

            // Botones (idénticos al ForgotPasswordDialog)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: _btnH,
                  width: _btnW,
                  child: OutlinedButton(
                    onPressed: _sending ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _navyLight, width: 1.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const MyText(
                      text: 'Cancelar',
                      variant: MyTextVariant.normalBold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: _btnH,
                  width: _btnW, // <-- mismo ancho que el de Cancelar
                  child: InkWell(
                    onTap: _sending ? null : _sendResetEmail,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_navyDark, _navyLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _sending ? 'Enviando...' : 'Enviar',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
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
    );
  }
}
