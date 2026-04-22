// lib/common/utils/components/ui/navy_header.dart
//
// ─── UPGRADE LOG ────────────────────────────────────────────────────────────
//  v2 — Unified gradient header used across ALL pages.
//  Fully backward-compatible: existing NavyHeader usage still compiles.
//  New recommended API: AppGradientHeader (same file, exported together).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'app_styles.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  AppGradientHeader  ← USE THIS in new pages
// ═════════════════════════════════════════════════════════════════════════════
//
//  Examples:
//
//  // Simple page header with back button
//  AppGradientHeader(title: 'Mis vehículos', showBack: true)
//
//  // With subtitle + custom actions
//  AppGradientHeader(
//    title: 'Reservaciones',
//    subtitle: 'Gestiona tus reservas',
//    showBack: true,
//    actions: [
//      IconButton(icon: Icon(Icons.filter_list_rounded), onPressed: ...),
//    ],
//  )
//
//  // Hero icon (login / onboarding style)
//  AppGradientHeader(
//    title: 'Parking App',
//    subtitle: '¡Bienvenido de vuelta!',
//    heroIcon: Icons.local_parking_rounded,
//  )
//
//  // With avatar (profile pages)
//  AppGradientHeader(
//    title: 'Mi Perfil',
//    showBack: true,
//    avatar: CircleAvatar(backgroundImage: NetworkImage(url)),
//  )
//
//  // With TabBar at bottom
//  AppGradientHeader(
//    title: 'Panel',
//    showBack: false,
//    bottom: TabBar(tabs: [...]),
//  )
// ─────────────────────────────────────────────────────────────────────────────

class AppGradientHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Widget? avatar;
  final IconData? heroIcon;
  final PreferredSizeWidget? bottom; // e.g. TabBar
  final bool centerTitle;

  const AppGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
    this.actions,
    this.avatar,
    this.heroIcon,
    this.bottom,
    this.centerTitle = false,
  });

  bool get _hasHero => heroIcon != null || avatar != null;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final headerGradient =
        isDark
            ? const [
              Color(0xFF111827),
              Color(0xFF0F172A),
              Color(0xFF0B1220),
            ]
            : const [AppColors.headerTop, AppColors.headerBottom];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: headerGradient,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles (matches configure_profile style)
          Positioned(
            top: -30,
            right: -16,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: -24,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    showBack ? 4 : 16,
                    10,
                    (actions?.isNotEmpty ?? false) ? 4 : 16,
                    _hasHero ? 6 : (bottom != null ? 2 : 18),
                  ),
                  child: Row(
                    children: [
                      // Back button
                      if (showBack)
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed:
                              onBack ?? () => Navigator.maybePop(context),
                        )
                      else
                        const SizedBox(width: 16),

                      // Title + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              centerTitle || !showBack
                                  ? CrossAxisAlignment.center
                                  : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Actions
                      if (actions != null)
                        Row(mainAxisSize: MainAxisSize.min, children: actions!)
                      else
                        const SizedBox(width: 16),
                    ],
                  ),
                ),

                // Hero icon / avatar
                if (_hasHero)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child:
                        avatar ??
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24),
                              width: 1.4,
                            ),
                          ),
                          child: Icon(heroIcon, size: 34, color: Colors.white),
                        ),
                  ),

                // Bottom slot (TabBar etc.)
                if (bottom != null) bottom!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  NavyHeader — KEPT for backward compatibility
//  Internally delegates to AppGradientHeader when possible.
// ═════════════════════════════════════════════════════════════════════════════
class NavyHeader extends StatelessWidget {
  const NavyHeader({
    super.key,
    required this.height,
    this.roundedBottom = false,
    this.leading,
    this.trailing,
    this.children = const <Widget>[],
  });

  final double height;
  final bool roundedBottom;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.headerTop, AppColors.headerBottom],
              ),
              borderRadius:
                  roundedBottom
                      ? const BorderRadius.only(
                        bottomLeft: Radius.circular(AppDims.radiusXl),
                        bottomRight: Radius.circular(AppDims.radiusXl),
                      )
                      : null,
            ),
          ),
          // Decorative circles
          Positioned(
            top: -40,
            right: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 70,
            left: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      leading ?? const SizedBox(width: 40, height: 32),
                      const SizedBox(width: 40, height: 32),
                      trailing ?? const SizedBox(width: 40, height: 32),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...children,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
