// lib/features/auth/components/verify_email_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mapbox_api/common/components/ui/app_styles.dart';
import 'package:mapbox_api/common/components/ui/my_button.dart';
import 'package:mapbox_api/common/widgets/app_loading_screen.dart';
import 'package:mapbox_api/features/users/pages/complete_profile_page.dart';

class VerifyEmailPage extends StatefulWidget {
  final User user;
  const VerifyEmailPage({super.key, required this.user});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage>
    with SingleTickerProviderStateMixin {
  bool _checking = false;
  bool _resending = false;
  bool _resent = false;
  String? _errorMsg;

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    setState(() {
      _checking = true;
      _errorMsg = null;
    });
    try {
      await widget.user.reload();
      final current = FirebaseAuth.instance.currentUser;
      if (!mounted) return;

      if (current != null && current.emailVerified) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => CompleteProfilePage(user: current, isNewUser: true),
          ),
          (_) => false,
        );
        return;
      }

      setState(() {
        _errorMsg =
            'Tu correo aún no está verificado. Revisa tu bandeja de entrada o spam.';
      });
    } catch (_) {
      setState(
        () => _errorMsg = 'No se pudo verificar el estado. Intenta de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() {
      _resending = true;
      _errorMsg = null;
      _resent = false;
    });
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      setState(() => _resent = true);
    } catch (_) {
      setState(() => _errorMsg = 'No se pudo reenviar. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _backToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const AppLoadingScreen(
        message: 'Verificando tu correo...',
        variant: LoadingVariant.profile,
      );
    }

    final screen = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        top: false,
        child: SizedBox(
          height: screen.height,
          child: Stack(
            children: [
              // Gradient
              Container(
                height: screen.height * 0.42,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.headerTop, AppColors.headerBottom],
                  ),
                ),
              ),

              // Blobs
              Positioned(
                top: 40,
                left: -20,
                child: _Blob(size: 90, opacity: 0.12),
              ),
              Positioned(
                top: -10,
                right: -10,
                child: _Blob(size: 120, opacity: 0.10),
              ),

              // Hero
              Positioned(
                top: screen.height * 0.09,
                left: 28,
                right: 28,
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.22),
                          width: 1.4,
                        ),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Verifica tu correo',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Te enviamos un correo a\n${widget.user.email ?? ''}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Sheet
              Positioned(
                top: screen.height * 0.30,
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(34),
                        topRight: Radius.circular(34),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Confirma tu correo electrónico',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.headerBottom,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Revisa tu bandeja principal, spam o promociones. Luego toca el botón de abajo.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8A94A6),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Email card
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.headerBottom.withOpacity(0.15),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.headerBottom.withOpacity(
                                    0.05,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.headerBottom.withOpacity(
                                      0.08,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.mail_outline_rounded,
                                    size: 18,
                                    color: AppColors.headerBottom,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Correo registrado',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF8A94A6),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.user.email ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Feedback messages
                          if (_resent) ...[
                            const SizedBox(height: 12),
                            _FeedbackBanner(
                              message: 'Correo reenviado. Revisa tu bandeja.',
                              isSuccess: true,
                            ),
                          ],
                          if (_errorMsg != null) ...[
                            const SizedBox(height: 12),
                            _FeedbackBanner(
                              message: _errorMsg!,
                              isSuccess: false,
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Primary action
                          MyButton(
                            text: 'Ya verifiqué mi correo',
                            onTap: _checking ? null : _checkVerification,
                            loading: _checking,
                            margin: EdgeInsets.zero,
                          ),

                          const SizedBox(height: 12),

                          // Resend
                          SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _resending ? null : _resendEmail,
                              icon:
                                  _resending
                                      ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.headerBottom,
                                        ),
                                      )
                                      : const Icon(
                                        Icons.send_outlined,
                                        size: 16,
                                        color: AppColors.headerBottom,
                                      ),
                              label: Text(
                                _resending
                                    ? 'Reenviando...'
                                    : 'Reenviar correo de verificación',
                                style: const TextStyle(
                                  color: AppColors.headerBottom,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide(
                                  color: AppColors.headerBottom.withOpacity(
                                    0.28,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Back to login
                          TextButton(
                            onPressed: _backToLogin,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: const Text(
                              'Regresar a inicio de sesión',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool isSuccess;

  const _FeedbackBanner({required this.message, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final double opacity;
  const _Blob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(opacity),
      shape: BoxShape.circle,
    ),
  );
}
