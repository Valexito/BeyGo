// lib/features/auth/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_textfield.dart';
import 'package:mapbox_api/common/utils/components/ui/my_password_field.dart';
import 'package:mapbox_api/common/utils/components/ui/my_button.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';

import 'package:mapbox_api/features/auth/components/square_tile.dart';
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

class _LoginPageState extends ConsumerState<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _goToCompleteProfile(User user) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => CompleteProfilePage(user: user, isNewUser: false),
      ),
      (_) => false,
    );
  }

  Future<void> _routeAfterAuth(User user) async {
    await user.reload();
    final current = FirebaseAuth.instance.currentUser;
    if (current == null || !mounted) return;

    final isPasswordUser = current.providerData.any(
      (p) => p.providerId == 'password',
    );

    if (isPasswordUser && !current.emailVerified) {
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
      _goToCompleteProfile(current);
    }
  }

  Future<void> _signInWithGoogle() async {
    final signInGoogle = ref.read(signInWithGoogleProvider);
    setState(() => _loading = true);
    try {
      final cred = await signInGoogle();
      final user = (cred as UserCredential).user;
      if (!mounted || user == null) return;
      await _routeAfterAuth(user);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInEmailPassword() async {
    final auth = ref.read(authActionsProvider);
    setState(() => _loading = true);
    try {
      final cred = await auth.signInWithEmailPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final user = cred.user;
      if (!mounted || user == null) return;
      await _routeAfterAuth(user);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFD8F3EE),
      body: SafeArea(
        top: false,
        child: SizedBox(
          height: screen.height,
          child: Stack(
            children: [
              Container(
                height: screen.height * 0.42,
                width: double.infinity,
                decoration: BoxDecoration(
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
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                top: -10,
                right: -10,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                top: 60,
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
                    const SizedBox(height: 18),
                    const MyText(
                      text: "Parking App",
                      variant: MyTextVariant.title,
                      customColor: Colors.white,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: MyText(
                        text:
                            "¡Bienvenido! Inicia sesión para reservar tu lugar de estacionamiento de forma rápida y sencilla.",
                        variant: MyTextVariant.subtitle,
                        customColor: Colors.white70,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: screen.height * 0.26,
                left: 0,
                right: 0,
                bottom: 0,
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
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            child: const MyText(
                              text: "Iniciar Sesión",
                              variant: MyTextVariant.normalBold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        const SizedBox(height: 22),
                        MyTextField(
                          controller: emailController,
                          hintText: 'Correo electrónico',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          prefixIcon: Icons.email_outlined,
                          margin: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 14),
                        MyPasswordField(
                          controller: passwordController,
                          hintText: 'Contraseña',
                          prefixIcon: Icons.lock_outline,
                          margin: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged:
                                  (v) =>
                                      setState(() => _rememberMe = v ?? false),
                              activeColor: AppColors.headerBottom,
                            ),
                            const Expanded(
                              child: MyText(
                                text: "Recordarme",
                                variant: MyTextVariant.bodyMuted,
                                fontSize: 13,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const ForgotPasswordDialog(),
                                );
                              },
                              child: const MyText(
                                text: 'Olvidé mi contraseña',
                                variant: MyTextVariant.normalBold,
                                customColor: AppColors.headerBottom,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.headerTop,
                                AppColors.headerBottom,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.headerBottom.withOpacity(0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: MyButton(
                            text:
                                _loading
                                    ? "Iniciando sesión..."
                                    : "Iniciar Sesión",
                            loading: _loading,
                            onTap: _loading ? null : _signInEmailPassword,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: MyText(
                                text: "O iniciar sesión con",
                                variant: MyTextVariant.bodyMuted,
                                fontSize: 12,
                              ),
                            ),
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SquareTile(
                              imagePath: 'assets/images/google.png',
                              onTap: _loading ? null : _signInWithGoogle,
                            ),
                            const SizedBox(width: 16),
                            const SquareTile(
                              imagePath: 'assets/images/apple.png',
                              onTap: null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const MyText(
                              text: "¿No tienes una cuenta? ",
                              variant: MyTextVariant.bodyMuted,
                              fontSize: 13,
                            ),
                            GestureDetector(
                              onTap: _loading ? null : widget.onShowRegister,
                              child: const MyText(
                                text: "Registrarme",
                                variant: MyTextVariant.normalBold,
                                customColor: AppColors.headerBottom,
                                fontSize: 13,
                              ),
                            ),
                          ],
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
    );
  }
}
