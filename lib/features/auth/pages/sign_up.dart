// lib/features/auth/pages/sign_up.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/components/ui/app_styles.dart';
import 'package:mapbox_api/common/components/ui/my_button.dart';
import 'package:mapbox_api/common/widgets/conection_issues.dart';
import 'package:mapbox_api/features/auth/components/verify_email_page.dart';
import '../providers/auth_providers.dart';

// ─── Country code model (same as configure_profile_page) ─────────────────────
class _CountryCode {
  final String flag;
  final String name;
  final String code;
  const _CountryCode(this.flag, this.name, this.code);
}

const _kCountryCodes = [
  _CountryCode('🇬🇹', 'Guatemala', '+502'),
  _CountryCode('🇲🇽', 'México', '+52'),
  _CountryCode('🇺🇸', 'Estados Unidos', '+1'),
  _CountryCode('🇸🇻', 'El Salvador', '+503'),
  _CountryCode('🇭🇳', 'Honduras', '+504'),
  _CountryCode('🇳🇮', 'Nicaragua', '+505'),
  _CountryCode('🇨🇷', 'Costa Rica', '+506'),
  _CountryCode('🇵🇦', 'Panamá', '+507'),
  _CountryCode('🇨🇴', 'Colombia', '+57'),
  _CountryCode('🇪🇸', 'España', '+34'),
  _CountryCode('🇦🇷', 'Argentina', '+54'),
  _CountryCode('🇨🇱', 'Chile', '+56'),
  _CountryCode('🇵🇪', 'Perú', '+51'),
  _CountryCode('🇻🇪', 'Venezuela', '+58'),
  _CountryCode('🇧🇷', 'Brasil', '+55'),
];

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
  final _name = TextEditingController();
  final _phoneNumber = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  _CountryCode _selectedCountry = _kCountryCodes.first;

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
    _name.dispose();
    _phoneNumber.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.4,
            maxChildSize: 0.75,
            expand: false,
            builder:
                (_, scrollCtrl) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Column(
                          children: [
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Código de país',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Divider(color: Colors.grey.shade100, height: 1),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: _kCountryCodes.length,
                          itemBuilder: (_, i) {
                            final c = _kCountryCodes[i];
                            final selected = c.code == _selectedCountry.code;
                            return InkWell(
                              onTap: () {
                                setState(() => _selectedCountry = c);
                                Navigator.pop(ctx);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      selected
                                          ? AppColors.headerBottom.withOpacity(
                                            0.07,
                                          )
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        selected
                                            ? AppColors.headerBottom
                                                .withOpacity(0.25)
                                            : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      c.flag,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        c.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              selected
                                                  ? AppColors.headerBottom
                                                  : const Color(0xFF3D4554),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      c.code,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            selected
                                                ? AppColors.headerBottom
                                                : const Color(0xFF6B7280),
                                      ),
                                    ),
                                    if (selected) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.check_rounded,
                                        color: AppColors.headerBottom,
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _signUp() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final auth = ref.read(authActionsProvider);
    setState(() => _loading = true);

    try {
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
      _showError(e.message ?? 'No se pudo crear la cuenta.');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('network') ||
          msg.contains('socket') ||
          msg.contains('timeout')) {
        AppNoConnection.snack(context, onRetry: _signUp);
      } else {
        _showError('Error inesperado: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
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
      ),
    );
  }

  // ── Validators ──────────────────────────────────────────────────────────────
  String? _validateEmail(String? v) {
    final email = (v ?? '').trim();
    if (email.isEmpty) return 'Ingresa tu correo.';
    if (!RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$').hasMatch(email)) {
      return 'Correo inválido.';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Ingresa tu contraseña.';
    if (text.length < 8) return 'Mínimo 8 caracteres.';
    return null;
  }

  String? _validateConfirm(String? v) {
    if ((v ?? '').trim() != _password.text.trim()) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        top: false,
        child: SizedBox(
          height: screen.height,
          child: Stack(
            children: [
              // ── Gradient background ──
              Container(
                height: screen.height * 0.38,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.headerTop, AppColors.headerBottom],
                  ),
                ),
              ),

              // Decorative circles
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

              // Back button
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

              // Hero icon
              Positioned(
                top: screen.height * 0.10,
                left: 28,
                right: 28,
                child: Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.22),
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

              // ── Content sheet ──
              Positioned(
                top: screen.height * 0.24,
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
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Title
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
                            const Text(
                              'Confirmarás tu email y completarás tu perfil.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF8A94A6),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── Account section ──
                            _SectionHeader(
                              icon: Icons.mail_outline_rounded,
                              title: 'Datos de acceso',
                            ),
                            const SizedBox(height: 14),

                            _FieldLabel(
                              label: 'Correo electrónico',
                              hint: 'Usa un correo al que tengas acceso',
                            ),
                            const SizedBox(height: 6),
                            _FormField(
                              controller: _email,
                              hint: 'ejemplo@correo.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                            ),

                            const SizedBox(height: 16),
                            _FieldLabel(
                              label: 'Contraseña',
                              hint: 'Mínimo 8 caracteres',
                            ),
                            const SizedBox(height: 6),
                            _FormField(
                              controller: _password,
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePass,
                              validator: _validatePassword,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18,
                                  color: AppColors.headerBottom,
                                ),
                                onPressed:
                                    () => setState(
                                      () => _obscurePass = !_obscurePass,
                                    ),
                              ),
                            ),

                            const SizedBox(height: 16),
                            _FieldLabel(
                              label: 'Confirmar contraseña',
                              hint: 'Repite tu contraseña',
                            ),
                            const SizedBox(height: 6),
                            _FormField(
                              controller: _confirm,
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscureConfirm,
                              validator: _validateConfirm,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18,
                                  color: AppColors.headerBottom,
                                ),
                                onPressed:
                                    () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Optional phone section ──
                            _SectionHeader(
                              icon: Icons.phone_outlined,
                              title: 'Teléfono (opcional)',
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Puedes completarlo después en tu perfil.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8A94A6),
                              ),
                            ),
                            const SizedBox(height: 12),

                            _PhoneField(
                              numberCtrl: _phoneNumber,
                              selectedCountry: _selectedCountry,
                              onPickCountry: _showCountryPicker,
                            ),

                            const SizedBox(height: 32),

                            // Register button
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

                            // Back to login
                            Center(
                              child: GestureDetector(
                                onTap: _loading ? null : widget.onBackToLogin,
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF8A94A6),
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
}

// ═════════════════════════════════════════════════════════════════════════════
//  Shared helpers (mirrors configure_profile_page style)
// ═════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.headerBottom.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: AppColors.headerBottom),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final String hint;
  const _FieldLabel({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
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
        Text(
          hint,
          style: const TextStyle(fontSize: 11, color: Color(0xFF8A94A6)),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  const _FormField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8A94A6)),
        prefixIcon: Icon(icon, size: 18, color: AppColors.headerBottom),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderSoft),
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

class _PhoneField extends StatelessWidget {
  final TextEditingController numberCtrl;
  final _CountryCode selectedCountry;
  final VoidCallback onPickCountry;

  const _PhoneField({
    required this.numberCtrl,
    required this.selectedCountry,
    required this.onPickCountry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          // Country code button
          GestureDetector(
            onTap: onPickCountry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.borderSoft)),
              ),
              child: Row(
                children: [
                  Text(
                    selectedCountry.flag,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selectedCountry.code,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headerBottom,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.headerBottom.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
          // Number input
          Expanded(
            child: TextField(
              controller: numberCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\s\-]')),
              ],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              decoration: const InputDecoration(
                hintText: '5555 1234',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
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
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}
