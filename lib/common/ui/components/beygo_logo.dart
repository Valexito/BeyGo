import 'package:flutter/material.dart';

import 'app_styles.dart';

class BeygoLogo extends StatelessWidget {
  const BeygoLogo({
    super.key,
    this.size = 36,
    this.padding = 4,
    this.borderRadius,
    this.backgroundColor = AppColors.headerBottom,
    this.monogramOnly = false,
  });

  final double size;
  final double padding;
  final double? borderRadius;
  final Color backgroundColor;
  final bool monogramOnly;

  static const String _fullLogoAssetPath =
      'assets/branding/ic_launcher_foreground_432.png';
  static const String _masterAssetPath =
      'assets/branding/BEYGO_icon_master_1024.png';

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.32);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((radius - padding).clamp(0, radius)),
        child:
            monogramOnly
                ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: size,
                    height: size * 0.68,
                    child: Align(
                      alignment: const Alignment(0, -0.92),
                      child: Image.asset(_masterAssetPath, fit: BoxFit.cover),
                    ),
                  ),
                )
                : Image.asset(_fullLogoAssetPath, fit: BoxFit.contain),
      ),
    );
  }
}
