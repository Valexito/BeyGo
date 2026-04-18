// lib/features/auth/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_textfield.dart';
import 'package:mapbox_api/common/ui/components/my_password_field.dart';
import 'package:mapbox_api/common/ui/components/my_button.dart';

import 'package:mapbox_api/features/auth/components/forgot_password_dialog.dart';
import 'package:mapbox_api/features/auth/components/verify_email_page.dart';
import 'package:mapbox_api/features/auth/providers/auth_providers.dart';

import 'package:mapbox_api/features/users/pages/complete_profile_page.dart';
import 'package:mapbox_api/features/users/providers/user_providers.dart';
import 'package:mapbox_api/features/core/pages/home_switch.dart';

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

  // ── SEPARATE flag for Google — this is the fix for the double-tap bug ──────
  // Root cause: GoogleSignIn.signIn() can return null on the first call on
  // Android emulators and some physical devices due to a cold-start race with
  // Play Services. Having a single _loading flag means the second tap fires
  // while the first is still "in progress" (state not yet updated).
  // Fix: use an independent flag so Google state is isolated.
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

    final ready = await ref.read(canEnterAppProvider(current.uid).future);
    if (!mounted) return;

    if (ready) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeSwitch()),
        (_) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => CompleteProfilePage(user: current, isNewUser: false),
        ),
        (_) => false,
      );
    }
  }

  // ── Google Sign-In — double-tap fixed ──────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    if (_googleLoading || _loading) return; // hard guard
    setState(() => _googleLoading = true);
    try {
      final signInGoogle = ref.read(signInWithGoogleProvider);
      final cred = await signInGoogle();
      final user = (cred as UserCredential).user;
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

  // ── Facebook — placeholder ready to implement ──────────────────────────────
  Future<void> _signInWithFacebook() async {
    // ─────────────────────────────────────────────────────────────────────────
    // TO IMPLEMENT:
    // 1. flutter pub add flutter_facebook_auth
    // 2. Add to android/app/src/main/res/values/strings.xml:
    //      <string name="facebook_app_id">YOUR_APP_ID</string>
    //      <string name="fb_login_protocol_scheme">fbYOUR_APP_ID</string>
    //      <string name="facebook_client_token">YOUR_CLIENT_TOKEN</string>
    // 3. Add to android/app/src/main/AndroidManifest.xml (inside <application>):
    //      <meta-data android:name="com.facebook.sdk.ApplicationId" android:value="@string/facebook_app_id"/>
    // 4. Enable Facebook provider in Firebase Console → Authentication
    // 5. Replace this body with:
    //
    //    final result = await FacebookAuth.instance.login();
    //    if (result.status == LoginStatus.success) {
    //      final credential = FacebookAuthProvider.credential(result.accessToken!.tokenString);
    //      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
    //      if (!mounted || cred.user == null) return;
    //      await _routeAfterAuth(cred.user!);
    //    }
    // ─────────────────────────────────────────────────────────────────────────
    _showError('Facebook login próximamente disponible.');
  }

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

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        top: false,
        child: SizedBox(
          height: screen.height,
          child: Stack(
            children: [
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

              // Hero section
              Positioned(
                top: screen.height * 0.04,
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
                        Icons.local_parking_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Parking App',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '¡Bienvenido! Reserva tu lugar fácil y rápido.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content sheet
              Positioned(
                top: screen.height * 0.23,
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
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.headerBottom,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Accede a tu cuenta para continuar.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8A94A6),
                            ),
                          ),

                          const SizedBox(height: 22),

                          _FieldLabel(label: 'Correo electrónico'),
                          const SizedBox(height: 6),
                          MyTextField(
                            controller: _emailCtrl,
                            hintText: 'ejemplo@correo.com',
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
                            hintText: 'Ingresa tu contraseña',
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
                                  activeColor: AppColors.headerBottom,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Recordarme',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
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
                                child: const Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.headerBottom,
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
                                child: Divider(color: Colors.grey.shade300),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'O continuar con',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(color: Colors.grey.shade300),
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
                                  imagePath: 'assets/images/google.png',
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
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                  children: [
                                    const TextSpan(text: '¿No tienes cuenta? '),
                                    TextSpan(
                                      text: 'Registrarme',
                                      style: TextStyle(
                                        color: AppColors.headerBottom,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
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
                                : AppColors.headerBottom,
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
                                      : AppColors.headerBottom,
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
                                  : const Color(0xFF3D4554),
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
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B),
        ),
      ),
      const SizedBox(height: 2),
    ],
  );
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
