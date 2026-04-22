import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_button.dart';
import 'package:mapbox_api/features/auth/components/verify_email_page.dart';
import '../providers/auth_providers.dart';

class SignUpPage extends ConsumerStatefulWidget {
  final VoidCallback onBackToLogin;
  const SignUpPage({super.key, required this.onBackToLogin});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);
    try {
      final auth = ref.read(authActionsProvider);
      final cred = await auth.signUpWithEmailPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      final user = cred.user;
      if (!mounted || user == null) return;
      await user.sendEmailVerification();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => VerifyEmailPage(user: user)),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showError(_mapError(e.code));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('network') || msg.contains('socket')) {
        _showError('Sin conexión. Revisa tu internet.');
      } else {
        _showError('Error inesperado. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'weak-password':
        return 'La contraseña es muy débil. Mínimo 8 caracteres.';
      default:
        return 'No se pudo crear la cuenta. Intenta de nuevo.';
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

  String? _validateEmail(String? v) {
    final email = (v ?? '').trim();
    if (email.isEmpty) return 'Ingresa tu correo.';
    if (!RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$').hasMatch(email))
      return 'Correo inválido.';
    return null;
  }

  String? _validatePassword(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Ingresa tu contraseña.';
    if (text.length < 8) return 'Mínimo 8 caracteres.';
    return null;
  }

  String? _validateConfirm(String? v) {
    if ((v ?? '').trim() != _password.text.trim())
      return 'Las contraseñas no coinciden.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final headerGradient =
        context.isDarkMode
            ? const [Color(0xFF111827), Color(0xFF0F172A), Color(0xFF0B1220)]
            : const [AppColors.headerTop, AppColors.headerBottom];

    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: SafeArea(
        top: false,
        child: SizedBox(
          height: screen.height,
          child: Stack(
            children: [
              Container(
                height: screen.height * 0.38,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: headerGradient,
                  ),
                ),
              ),
              Positioned(top: 40, left: -20, child: _blob(90, 0.12)),
              Positioned(top: -10, right: -10, child: _blob(120, 0.10)),

              Positioned(
                top: 15,
                left: 18,
                child: SafeArea(
                  child: TextButton.icon(
                    onPressed: _loading ? null : widget.onBackToLogin,
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

              Positioned(
                top: screen.height * 0.10,
                left: 28,
                right: 28,
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.4,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              Positioned(
                top: screen.height * 0.24,
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
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Crear cuenta',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.headerBottom,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Confirmarás tu email y completarás tu perfil a continuación.',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.appTextSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 24),

                            _SectionHeader(
                              icon: Icons.lock_outline_rounded,
                              title: 'Datos de acceso',
                            ),
                            const SizedBox(height: 14),

                            const _FieldLabel('Correo electrónico'),
                            const SizedBox(height: 6),
                            _Field(
                              controller: _email,
                              hint: 'ejemplo@correo.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 16),

                            const _FieldLabel('Contraseña'),
                            const SizedBox(height: 6),
                            _Field(
                              controller: _password,
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePass,
                              validator: _validatePassword,
                              suffix: _EyeBtn(
                                visible: _obscurePass,
                                onToggle:
                                    () => setState(
                                      () => _obscurePass = !_obscurePass,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            const _FieldLabel('Confirmar contraseña'),
                            const SizedBox(height: 6),
                            _Field(
                              controller: _confirm,
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscureConfirm,
                              validator: _validateConfirm,
                              suffix: _EyeBtn(
                                visible: _obscureConfirm,
                                onToggle:
                                    () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            MyButton(
                              text:
                                  _loading
                                      ? 'Creando cuenta...'
                                      : 'Crear cuenta',
                              loading: _loading,
                              onTap: _loading ? null : _signUp,
                              margin: EdgeInsets.zero,
                            ),
                            const SizedBox(height: 16),

                            Center(
                              child: GestureDetector(
                                onTap: _loading ? null : widget.onBackToLogin,
                                child: RichText(
                                text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.appTextSecondaryColor,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: '¿Ya tienes cuenta? ',
                                      ),
                                      TextSpan(
                                        text: 'Iniciar sesión',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      shape: BoxShape.circle,
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.headerBottom.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 16, color: AppColors.headerBottom),
      ),
      const SizedBox(width: 9),
      Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: context.appTextPrimaryColor,
        ),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: context.appTextPrimaryColor,
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.appTextPrimaryColor,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13,
          color: context.appTextSecondaryColor,
        ),
        prefixIcon: Icon(icon, size: 18, color: AppColors.headerBottom),
        suffixIcon: suffix,
        filled: true,
        fillColor: context.appInputBackgroundActive,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.appBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.appBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.headerBottom, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
    );
  }
}

class _EyeBtn extends StatelessWidget {
  final bool visible;
  final VoidCallback onToggle;
  const _EyeBtn({required this.visible, required this.onToggle});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(
      visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      size: 18,
      color: AppColors.headerBottom,
    ),
    onPressed: onToggle,
  );
}
