import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/auth/auth.dart';

class LoginPage extends ConsumerStatefulWidget {
  final VoidCallback onShowRegister;
  const LoginPage({Key? key, required this.onShowRegister}) : super(key: key);

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;

  bool _googleLoading = false;

  bool _rememberMe = false;

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
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Routing ────────────────────────────────────────────────────────────────
  Future<void> _routeAfterAuth(User user) async {
    await user.reload();
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || !mounted) return;

    if (current.providerData.any((p) => p.providerId == 'password') &&
        !current.emailVerified) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailPage(user: current)),
        (_) => false,
      );
      return;
    }

    if (!mounted) return;
    //check if user document exists, if not, route to onboarding, else to home
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
  }

  // ── Google Sign-In — double-tap fixed ──────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    if (_googleLoading || _loading) return; // hard guard
    setState(() => _googleLoading = true);
    try {
      final signInGoogle = ref.read(signInWithGoogleProvider);
      final cred = await signInGoogle();
      final user = cred.user;
      if (!mounted || user == null) return;
      await _routeAfterAuth(user);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      final cancelled =
          msg.contains('cancel') ||
          msg.contains('cancelled') ||
          msg.contains('cancelado') ||
          msg.contains('sign-in cancelled');
      if (!cancelled) {
        _showError('Error al iniciar sesión con Google. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  // ── Facebook — placeholder to be implemented next
  Future<void> _signInWithFacebook() async {}

  // ── Email/Password ─────────────────────────────────────────────────────────
  Future<void> _signInEmailPassword() async {
    if (_loading || _googleLoading) return;
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      _showError('Ingresa tu correo y contraseña.');
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = ref.read(authActionsProvider);
      final cred = await auth.signInWithEmailPassword(
        email: email,
        password: pass,
      );
      if (!mounted || cred.user == null) return;
      await _routeAfterAuth(cred.user!);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_mapFirebaseError(e.code));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('network') || msg.contains('socket')) {
        _showError('Sin conexión a internet. Revisa tu red.');
      } else {
        _showError('Error inesperado. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con ese correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Contraseña incorrecta. Intenta de nuevo.';
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada.';
      default:
        return 'Error al iniciar sesión. Intenta de nuevo.';
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final anyLoading = _loading || _googleLoading;
    final heroTop = screen.height < 760 ? 8.0 : screen.height * 0.03;
    final sheetTop =
        screen.height < 760 ? screen.height * 0.305 : screen.height * 0.245;

    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: SafeArea(
        top: false,
        child: SizedBox(
          height: screen.height,
          child: Stack(
            children: [
              AuthHeaderBackground(height: screen.height * 0.42),
              const AuthHeaderBlobs(),

              // Hero section
              Positioned(
                top: heroTop,
                left: 28,
                right: 28,
                child: const AuthBrandHero(),
              ),

              // Content sheet
              Positioned(
                top: sheetTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.appSectionBackground,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(34),
                        topRight: Radius.circular(34),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: context.appBrandTextColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),

                          const SizedBox(height: 22),

                          _FieldLabel(label: 'Correo electrónico'),
                          const SizedBox(height: 6),
                          MyTextField(
                            controller: _emailCtrl,
                            hintText: '',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.email_outlined,
                            margin: EdgeInsets.zero,
                          ),

                          const SizedBox(height: 14),

                          _FieldLabel(label: 'Contraseña'),
                          const SizedBox(height: 6),
                          MyPasswordField(
                            controller: _passCtrl,
                            hintText: '',
                            prefixIcon: Icons.lock_outline,
                            margin: EdgeInsets.zero,
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged:
                                      (v) => setState(
                                        () => _rememberMe = v ?? false,
                                      ),
                                  activeColor: context.appBrandIconColor,
                                  checkColor:
                                      context.isDarkMode
                                          ? const Color(0xFF0F172A)
                                          : Colors.white,
                                  side: BorderSide(
                                    color: context.appTextSecondaryColor,
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Recordarme',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.appTextSecondaryColor,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed:
                                    anyLoading
                                        ? null
                                        : () => showDialog(
                                          context: context,
                                          builder:
                                              (_) =>
                                                  const ForgotPasswordDialog(),
                                        ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                ),
                                child: Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.appBrandTextColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          MyButton(
                            text:
                                _loading
                                    ? 'Iniciando sesión...'
                                    : 'Iniciar Sesión',
                            loading: _loading,
                            onTap: anyLoading ? null : _signInEmailPassword,
                            margin: EdgeInsets.zero,
                          ),

                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: Divider(color: context.appBorderColor),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'O continuar con',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.appTextSecondaryColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: context.appBorderColor),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Social buttons
                          Row(
                            children: [
                              Expanded(
                                child: _SocialButton(
                                  label: 'Google',
                                  imagePath: 'assets/branding/google.png',
                                  loading: _googleLoading,
                                  disabled: anyLoading,
                                  onTap: _signInWithGoogle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SocialButton(
                                  label: 'Facebook',
                                  imagePath: 'assets/images/facebook.png',
                                  loading: false,
                                  disabled: anyLoading,
                                  onTap: _signInWithFacebook,
                                  isFacebook: true,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          Center(
                            child: GestureDetector(
                              onTap: anyLoading ? null : widget.onShowRegister,
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.appTextSecondaryColor,
                                  ),
                                  children: [
                                    const TextSpan(text: '¿No tienes cuenta? '),
                                    TextSpan(
                                      text: 'Registrarme',
                                      style: TextStyle(
                                        color: context.appBrandTextColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
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

// ─── Social button ─────────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final String label;
  final String imagePath;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;
  final bool isFacebook;

  const _SocialButton({
    required this.label,
    required this.imagePath,
    required this.loading,
    required this.disabled,
    required this.onTap,
    this.isFacebook = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled && !loading ? 0.55 : 1.0,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: context.appCardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.appBorderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: context.isDarkMode ? 0.16 : 0.04,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child:
              loading
                  ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                            isFacebook
                                ? const Color(0xFF1877F2)
                                : context.appBrandIconColor,
                      ),
                    ),
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        imagePath,
                        height: 22,
                        width: 22,
                        errorBuilder:
                            (_, __, ___) => Icon(
                              isFacebook
                                  ? Icons.facebook_rounded
                                  : Icons.login_rounded,
                              size: 22,
                              color:
                                  isFacebook
                                      ? const Color(0xFF1877F2)
                                      : context.appBrandIconColor,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              isFacebook
                                  ? const Color(0xFF1877F2)
                                  : context.appTextPrimaryColor,
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.appTextPrimaryColor,
        ),
      ),
      const SizedBox(height: 2),
    ],
  );
}
