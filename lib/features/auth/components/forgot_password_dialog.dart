// lib/features/auth/components/forgot_password_dialog.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_button.dart';
import 'package:mapbox_api/common/ui/components/my_textfield.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailCtrl = TextEditingController();
  String? _message;
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (!RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$').hasMatch(email)) {
      setState(() => _message = 'Escribe un correo válido.');
      return;
    }

    setState(() {
      _sending = true;
      _message = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() {
        _sent = true;
        _message =
            'Te enviamos un correo con instrucciones para restablecer tu contraseña.';
      });
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'invalid-email':
          msg = 'El correo no es válido.';
          break;
        case 'user-not-found':
          msg = 'No existe una cuenta con ese correo.';
          break;
        default:
          msg = 'Ocurrió un error. Intenta de nuevo.';
      }
      setState(() => _message = msg);
    } catch (_) {
      setState(() => _message = 'Error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // ── Gradient header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors:
                      _sent
                          ? [const Color(0xFF16A34A), const Color(0xFF15803D)]
                          : [AppColors.headerTop, AppColors.headerBottom],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.26),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      _sent
                          ? Icons.mark_email_read_outlined
                          : Icons.lock_reset_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _sent ? '¡Correo enviado!' : 'Recuperar contraseña',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _sent
                        ? 'Revisa tu bandeja de entrada'
                        : 'Te enviaremos instrucciones a tu correo',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_sent) ...[
                    const Text(
                      'Correo electrónico',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ingresa el correo asociado a tu cuenta',
                      style: TextStyle(fontSize: 11, color: Color(0xFF8A94A6)),
                    ),
                    const SizedBox(height: 8),
                    MyTextField(
                      controller: _emailCtrl,
                      hintText: 'ejemplo@correo.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.mail_outline,
                      margin: EdgeInsets.zero,
                    ),
                  ],

                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _sent
                                ? const Color(0xFF16A34A).withOpacity(0.08)
                                : const Color(0xFFDC2626).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              _sent
                                  ? const Color(0xFF16A34A).withOpacity(0.25)
                                  : const Color(0xFFDC2626).withOpacity(0.20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _sent
                                ? Icons.check_circle_outline_rounded
                                : Icons.info_outline_rounded,
                            size: 16,
                            color:
                                _sent
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _message!,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    _sent
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

                  const SizedBox(height: 20),

                  if (_sent)
                    MyButton(
                      text: 'Entendido',
                      height: 46,
                      onTap: () => Navigator.pop(context),
                      margin: EdgeInsets.zero,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed:
                                  _sending
                                      ? null
                                      : () => Navigator.pop(context),
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
                        Expanded(
                          child: MyButton(
                            text: _sending ? 'Enviando...' : 'Enviar',
                            loading: _sending,
                            height: 46,
                            onTap: _sending ? null : _send,
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
