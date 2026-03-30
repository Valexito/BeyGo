import 'package:flutter/material.dart';
import 'app_styles.dart';

enum MyTextVariant {
  title,
  subtitle,
  normal,
  normalBold,
  body,
  bodyBold,
  bodyMuted,
}

class MyText extends StatelessWidget {
  final String text;
  final MyTextVariant variant;
  final TextAlign? textAlign;
  final TextDecoration? decoration;
  final double? fontSize;
  final Color? customColor;
  final int? maxLines;
  final TextOverflow? overflow;

  const MyText({
    super.key,
    required this.text,
    this.variant = MyTextVariant.normal,
    this.textAlign,
    this.decoration,
    this.fontSize,
    this.customColor,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle style;

    switch (variant) {
      case MyTextVariant.title:
        style = TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: fontSize ?? 22,
          letterSpacing: 0.2,
        );
        break;
      case MyTextVariant.subtitle:
        style = TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: fontSize ?? 14,
          height: 1.4,
        );
        break;
      case MyTextVariant.normal:
        style = TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: fontSize ?? 14,
        );
        break;
      case MyTextVariant.normalBold:
        style = TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: fontSize ?? 14,
        );
        break;
      case MyTextVariant.body:
        style = TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: fontSize ?? 15,
        );
        break;
      case MyTextVariant.bodyBold:
        style = TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: fontSize ?? 15,
        );
        break;
      case MyTextVariant.bodyMuted:
        style = TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w400,
          fontSize: fontSize ?? 13,
        );
        break;
    }

    return Text(
      text,
      textAlign: textAlign,
      style: style.copyWith(
        color: customColor ?? style.color,
        decoration: decoration ?? TextDecoration.none,
      ),
    );
  }
}
