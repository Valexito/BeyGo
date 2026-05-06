import 'package:flutter/material.dart';
import 'package:beygo/common/common.dart';

class AuthBrandHero extends StatelessWidget {
  const AuthBrandHero({
    super.key,
    this.logoSize = 88,
    this.titleSize = 28,
    this.subtitleSize = 13,
    this.titleGap = 14,
    this.badgeRadius = 24,
    this.badgePadding = 8,
    this.premiumSplashDecor = false,
    this.subtitle = 'Encuentra y reserva tu espacio de parqueo fácil y rápido.',
  });

  final double logoSize;
  final double titleSize;
  final double subtitleSize;
  final double titleGap;
  final double badgeRadius;
  final double badgePadding;
  final bool premiumSplashDecor;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (premiumSplashDecor)
              Container(
                width: logoSize + 32,
                height: logoSize + 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.52, 1.0],
                  ),
                ),
              ),
            Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(badgeRadius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: premiumSplashDecor ? 26 : 18,
                    offset: Offset(0, premiumSplashDecor ? 14 : 10),
                  ),
                  if (premiumSplashDecor)
                    BoxShadow(
                      color: const Color(0xFF9FC0FF).withValues(alpha: 0.12),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                ],
              ),
              padding: EdgeInsets.all(badgePadding),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(badgeRadius - 6),
                child: Image.asset(
                  'assets/branding/BEYGO_icon_master_1024.png',
                  fit: BoxFit.contain,
                  errorBuilder:
                      (_, __, ___) => Icon(
                        Icons.local_parking_rounded,
                        size: logoSize * 0.48,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: titleGap),
        Text(
          'BeyGo',
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: subtitleSize,
              color: Colors.white.withValues(alpha: 0.84),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class AuthHeaderBlobs extends StatelessWidget {
  const AuthHeaderBlobs({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(top: 40, left: -20, child: _Blob(size: 90, opacity: 0.12)),
        Positioned(
          top: -10,
          right: -10,
          child: _Blob(size: 120, opacity: 0.10),
        ),
      ],
    );
  }
}

class AuthHeaderBackground extends StatelessWidget {
  const AuthHeaderBackground({
    super.key,
    required this.height,
    this.width = double.infinity,
  });

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final headerGradient =
        context.isDarkMode
            ? const [Color(0xFF111827), Color(0xFF0F172A), Color(0xFF0B1220)]
            : const [AppColors.headerTop, AppColors.headerBottom];

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: headerGradient,
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.opacity});

  final double size;
  final double opacity;

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
