import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/auth/providers/auth_providers.dart'
    show signOutAndNavigateToAuth;

class VerifyEmailPage extends StatefulWidget {
  final User user;
  final bool autoSendOnOpen;
  const VerifyEmailPage({
    super.key,
    required this.user,
    this.autoSendOnOpen = false,
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage>
    with SingleTickerProviderStateMixin {
  static const int _resendCooldownSeconds = 45;

  bool _checking = false;
  bool _resending = false;
  bool _resent = false;
  bool _initialEmailAttempted = false;
  String? _errorMsg;
  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _secondsUntilResend = 0;

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
    if (widget.autoSendOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _sendInitialEmailOnOpen();
      });
    }
    _startVerificationPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _startVerificationPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _checking) return;
      _checkVerification(showLoading: false);
    });
  }

  Future<void> _checkVerification({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _checking = true;
        _errorMsg = null;
      });
    }
    try {
      final auth = FirebaseAuth.instance;
      await auth.currentUser?.reload();
      final current = auth.currentUser;
      if (!mounted) return;

      if (current != null && current.emailVerified) {
        _pollTimer?.cancel();
        Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
        return;
      }

      if (showLoading) {
        setState(() {
          _errorMsg =
              'Tu correo aún no está verificado. Revisa tu bandeja de entrada o spam.';
        });
      }
    } catch (_) {
      if (showLoading) {
        setState(
          () => _errorMsg = 'No se pudo verificar el estado. Intenta de nuevo.',
        );
      }
    } finally {
      if (showLoading && mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _resendEmail() async {
    if (_secondsUntilResend > 0) return;
    setState(() {
      _resending = true;
      _errorMsg = null;
      _resent = false;
    });
    try {
      final current = await _resolveCurrentUser();
      await current?.sendEmailVerification();
      if (!mounted) return;
      setState(() => _resent = true);
      _startResendCooldown();
    } on FirebaseAuthException catch (e) {
      debugPrint('[VerifyEmail] resend failed: $e');
      if (!mounted) return;
      setState(() => _errorMsg = _mapVerificationError(e.code));
      if (e.code == 'too-many-requests') {
        _startResendCooldown(seconds: 90);
      }
    } catch (e) {
      debugPrint('[VerifyEmail] resend failed: $e');
      if (!mounted) return;
      setState(
        () =>
            _errorMsg =
                'No se pudo reenviar por ahora. Espera un momento e intenta de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _sendInitialEmailOnOpen() async {
    if (_initialEmailAttempted) return;
    _initialEmailAttempted = true;

    setState(() {
      _resending = true;
      _errorMsg = null;
      _resent = false;
    });
    try {
      await Future.delayed(const Duration(milliseconds: 1800));
      final current = await _resolveCurrentUser() ?? widget.user;
      await current.reload();
      await current.sendEmailVerification();
      if (!mounted) return;
      setState(() => _resent = true);
      _startResendCooldown();
      debugPrint('[VerifyEmail] initial email sent to ${current.email}');
    } on FirebaseAuthException catch (e) {
      debugPrint('[VerifyEmail] initial send failed: $e');
      if (!mounted) return;
      setState(() => _errorMsg = _mapVerificationError(e.code));
      if (e.code == 'too-many-requests') {
        _startResendCooldown(seconds: 90);
      }
    } catch (e) {
      debugPrint('[VerifyEmail] initial send failed: $e');
      if (!mounted) return;
      setState(
        () =>
            _errorMsg =
                'No pudimos enviar el correo automáticamente. Usa reenviar en unos segundos.',
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startResendCooldown({int seconds = _resendCooldownSeconds}) {
    _cooldownTimer?.cancel();
    if (!mounted) return;
    setState(() => _secondsUntilResend = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsUntilResend <= 1) {
        timer.cancel();
        setState(() => _secondsUntilResend = 0);
        return;
      }
      setState(() => _secondsUntilResend -= 1);
    });
  }

  String _mapVerificationError(String code) {
    switch (code) {
      case 'too-many-requests':
        return 'Firebase bloqueó temporalmente los envíos desde este dispositivo. Espera un poco antes de reenviar.';
      case 'network-request-failed':
        return 'No pudimos enviar el correo por conexión inestable.';
      case 'user-token-expired':
      case 'invalid-user-token':
        return 'Tu sesión se actualizó. Regresa e inicia sesión otra vez.';
      default:
        return 'No pudimos enviar el correo automáticamente. Intenta reenviar en un momento.';
    }
  }

  Future<User?> _resolveCurrentUser() async {
    final auth = FirebaseAuth.instance;
    final current = auth.currentUser;
    if (current != null) return current;

    try {
      return await auth.authStateChanges().first.timeout(
        const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('[VerifyEmail] authStateChanges timeout/error: $e');
      return null;
    }
  }

  Future<void> _backToLogin() async {
    await signOutAndNavigateToAuth(
      context,
      message: 'Saliendo...',
      submessage: 'Volviendo al acceso de BeyGo.',
    );
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
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
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
                                color: AppColors.headerBottom.withValues(alpha: 0.15),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.headerBottom.withValues(alpha: 
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
                                    color: AppColors.headerBottom.withValues(alpha: 
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
                              onPressed:
                                  (_resending || _secondsUntilResend > 0)
                                      ? null
                                      : _resendEmail,
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
                                    : _secondsUntilResend > 0
                                    ? 'Reenviar en ${_secondsUntilResend}s'
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
                                  color: AppColors.headerBottom.withValues(alpha: 
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
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
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
      color: Colors.white.withValues(alpha: opacity),
      shape: BoxShape.circle,
    ),
  );
}
