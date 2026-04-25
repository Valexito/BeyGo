import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'login_page.dart';
import 'sign_up.dart';

class AuthFlowPage extends ConsumerStatefulWidget {
  const AuthFlowPage({super.key});

  @override
  ConsumerState<AuthFlowPage> createState() => _AuthFlowPageState();
}

class _AuthFlowPageState extends ConsumerState<AuthFlowPage> {
  bool showRegister = false;

  @override
  Widget build(BuildContext context) {
    return showRegister
        ? SignUpPage(onBackToLogin: () => setState(() => showRegister = false))
        : LoginPage(onShowRegister: () => setState(() => showRegister = true));
  }
}
