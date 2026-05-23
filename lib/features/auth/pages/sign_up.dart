import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/auth/auth.dart';

class SignUpPage extends ConsumerStatefulWidget {
  final VoidCallback onBackToLogin;
  const SignUpPage({super.key, required this.onBackToLogin});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage>
    with SingleTickerProviderStateMixin {
  static final Uri _privacyPolicyUri = Uri.parse(
    'https://beygo-app-prod.web.app/privacy',
  );

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
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailPage(user: user, autoSendOnOpen: true),
        ),
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
        return 'Usa una contraseña fuerte con mayúscula, minúscula, número y símbolo.';
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

  Future<void> _openPrivacyPolicy() async {
    final opened = await launchUrl(
      _privacyPolicyUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showError('No se pudo abrir la Política de privacidad.');
    }
  }

  Future<void> _showPasswordRequirements() async {
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: ctx.appCardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.headerBottom.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.headerBottom,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Contraseña segura',
                  style: TextStyle(
                    color: ctx.appTextPrimaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu contraseña debe incluir:',
                  style: TextStyle(
                    color: ctx.appTextSecondaryColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                ...const [
                  '8 caracteres o más',
                  '1 letra mayúscula',
                  '1 letra minúscula',
                  '1 número',
                  '1 símbolo o carácter especial',
                ].map(
                  (item) => Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppColors.headerBottom,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
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
    if (!RegExp(r'[A-Z]').hasMatch(text))
      return 'Agrega al menos una mayúscula.';
    if (!RegExp(r'[a-z]').hasMatch(text))
      return 'Agrega al menos una minúscula.';
    if (!RegExp(r'\d').hasMatch(text)) return 'Agrega al menos un número.';
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(text)) {
      return 'Agrega al menos un símbolo.';
    }
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
    final heroTop =
        screen.height < 760 ? screen.height * 0.06 : screen.height * 0.10;
    final sheetTop =
        screen.height < 760 ? screen.height * 0.26 : screen.height * 0.24;

    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: SafeArea(
        top: false,
        child: SizedBox(
          height: screen.height,
          child: Stack(
            children: [
              AuthHeaderBackground(height: screen.height * 0.38),
              const AuthHeaderBlobs(),

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
                top: heroTop,
                left: 28,
                right: 28,
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
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
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Crear cuenta',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: context.appBrandTextColor,
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
                            const SizedBox(height: 4),
                            _Field(
                              controller: _email,
                              hint: '',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                const Expanded(child: _FieldLabel('Contraseña')),
                                IconButton(
                                  tooltip: 'Requisitos de contraseña',
                                  onPressed: _showPasswordRequirements,
                                  icon: Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: context.appTextSecondaryColor,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  splashRadius: 18,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _Field(
                              controller: _password,
                              hint: '',
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
                            const SizedBox(height: 4),
                            _Field(
                              controller: _confirm,
                              hint: '',
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
                            const SizedBox(height: 14),

                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: context.appTextSecondaryColor,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Al registrarte aceptas nuestra ',
                                  ),
                                  TextSpan(
                                    text: 'Política de privacidad',
                                    style: const TextStyle(
                                      color: AppColors.headerBottom,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    recognizer:
                                        TapGestureRecognizer()
                                          ..onTap =
                                              _loading
                                                  ? null
                                                  : _openPrivacyPolicy,
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                              textAlign: TextAlign.center,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          color: context.appIconCircleColor,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 16, color: context.appBrandIconColor),
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
        prefixIcon: Icon(icon, size: 18, color: context.appBrandIconColor),
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
          borderSide: BorderSide(color: context.appBrandIconColor, width: 1.5),
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
      color: context.appBrandIconColor,
    ),
    onPressed: onToggle,
  );
}
