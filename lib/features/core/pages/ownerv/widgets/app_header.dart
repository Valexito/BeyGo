import 'package:flutter/material.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/common/utils/components/ui/navy_header.dart';
import 'package:mapbox_api/features/core/pages/ownerv/owner_home_page.dart';

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
    return Stack(
      children: [
        NavyHeader(
          height: 175,
          roundedBottom: false,
          children: [
            const SizedBox(height: 10),
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

        if (showBack)
          Positioned(
            left: 10,
            top: 14,
            child: SafeArea(
              child: TextButton.icon(
                onPressed:
                    onBack ??
                    () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OwnerHomePage(),
                        ),
                        (route) => false,
                      );
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
