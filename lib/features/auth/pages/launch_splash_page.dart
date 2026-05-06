import 'dart:async';

import 'package:flutter/material.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/auth/auth.dart';

class LaunchSplashPage extends StatefulWidget {
  const LaunchSplashPage({super.key});

  @override
  State<LaunchSplashPage> createState() => _LaunchSplashPageState();
}

class _LaunchSplashPageState extends State<LaunchSplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          pageBuilder: (_, __, ___) => const AuthGate(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.headerTop,
      body: Stack(
        children: [
          AuthHeaderBackground(height: screen.height, width: screen.width),
          const AuthHeaderBlobs(),
          Align(
            alignment: const Alignment(0, 0.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: const AuthBrandHero(
                logoSize: 82,
                titleSize: 29,
                subtitleSize: 13,
                titleGap: 18,
                badgeRadius: 22,
                badgePadding: 7,
                premiumSplashDecor: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
