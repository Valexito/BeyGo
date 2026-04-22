import 'package:flutter/material.dart';
import 'app_styles.dart';

enum MyButtonVariant { filled, soft }

class MyButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String text;
  final bool loading;
  final EdgeInsetsGeometry? margin;
  final double? height;
  final MyButtonVariant variant;
  final IconData? icon;
  final double? fontSize;
  final Color? color;

  const MyButton({
    super.key,
    required this.onTap,
    this.text = "Continue",
    this.loading = false,
    this.margin,
    this.height,
    this.variant = MyButtonVariant.filled,
    this.icon,
    this.fontSize,
    this.color,
  });

  bool get _enabled => onTap != null && !loading;
  bool get _isFilled => variant == MyButtonVariant.filled;

  @override
  Widget build(BuildContext context) {
    final textColor = _isFilled ? Colors.white : AppColors.headerBottom;

    final child = Center(
      child:
          loading
              ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: _isFilled ? Colors.white : AppColors.headerBottom,
                ),
              )
              : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: textColor),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: fontSize ?? 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
    );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Opacity(
        opacity: _enabled ? 1 : 0.65,
        child: IgnorePointer(
          ignoring: !_enabled,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: height ?? AppDims.buttonHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDims.radiusLg),
                gradient:
                    _isFilled && color == null
                        ? const LinearGradient(
                          colors: [AppColors.headerTop, AppColors.headerBottom],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                        : null,
                color:
                    _isFilled
                        ? (color ?? null)
                        : (color ?? context.appCardBackgroundSoft),
                border: Border.all(
                  color:
                      _isFilled
                          ? Colors.transparent
                          : (context.isDarkMode
                              ? context.appBorderColor
                              : AppColors.headerBottom.withOpacity(0.18)),
                  width: _isFilled ? 0 : 1.1,
                ),
                boxShadow:
                    _isFilled
                        ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ]
                        : [],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
