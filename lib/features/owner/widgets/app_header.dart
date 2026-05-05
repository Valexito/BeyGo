import 'package:flutter/material.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/owner/owner.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final headerGradient =
        isDark
            ? const [Color(0xFF111827), Color(0xFF0F172A), Color(0xFF0B1220)]
            : const [AppColors.headerTop, AppColors.headerBottom];

    return Stack(
      children: [
        SizedBox(
          height: 175,
          width: double.infinity,
          child: Stack(
            children: [
              Container(
                height: 175,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: headerGradient,
                  ),
                ),
              ),
              Positioned(
                top: -40,
                right: -20,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.10),
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
                    color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(width: 40, height: 32),
                          SizedBox(width: 40, height: 32),
                          SizedBox(width: 40, height: 32),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const BeygoLogo(
                        size: 42,
                        padding: 4,
                        borderRadius: 14,
                        backgroundColor: Color(0xFF102648),
                      ),
                      const SizedBox(height: 12),
                      MyText(
                        text: title.toUpperCase(),
                        variant: MyTextVariant.title,
                        textAlign: TextAlign.center,
                        customColor: Colors.white,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 10),
                        MyText(
                          text: subtitle!,
                          variant: MyTextVariant.bodyMuted,
                          textAlign: TextAlign.center,
                          customColor: Colors.white70,
                          fontSize: 13,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showBack)
          Positioned(
            left: 10,
            top: 14,
            child: SafeArea(
              child: TextButton.icon(
                onPressed:
                    onBack ??
                    () async {
                      final popped = await Navigator.maybePop(context);
                      if (!popped && context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OwnerHomePage(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                ),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                label: const Text('Regresar'),
              ),
            ),
          ),
      ],
    );
  }
}
