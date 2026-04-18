// lib/common/utils/components/ui/my_password_field.dart
import 'package:flutter/material.dart';
import 'app_styles.dart';

class MyPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final EdgeInsetsGeometry? margin;

  final String? labelText;
  final String? helperText;
  final String? errorText;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;

  const MyPasswordField({
    super.key,
    required this.controller,
    required this.hintText,
    this.margin,
    this.labelText,
    this.helperText,
    this.errorText,
    this.validator,
    this.prefixIcon,
  });

  @override
  State<MyPasswordField> createState() => _MyPasswordFieldState();
}

class _MyPasswordFieldState extends State<MyPasswordField> {
  final FocusNode _focusNode = FocusNode();
  bool _obscure = true;

  bool get _active =>
      _focusNode.hasFocus || widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Widget? _buildPrefix() {
    final icon = widget.prefixIcon ?? Icons.lock_outline;
    final color = _active ? AppColors.headerBottom : AppColors.primary;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
      child: Icon(icon, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDims.radiusLg);

    final textStyle = TextStyle(
      color: _active ? AppColors.textPrimary : AppColors.textSecondary,
      fontWeight: FontWeight.w600,
      fontSize: 15,
    );

    final baseBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide.none,
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: AppColors.headerBottom.withOpacity(0.45),
        width: 1,
      ),
    );

    final decoration = InputDecoration(
      labelText: widget.labelText,
      helperText: widget.helperText,
      errorText: widget.errorText,
      hintText: widget.hintText,
      filled: true,
      fillColor: _active ? Colors.white : AppColors.formFieldBg,
      prefixIcon: _buildPrefix(),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      border: baseBorder,
      enabledBorder: baseBorder,
      disabledBorder: baseBorder,
      focusedBorder: focusedBorder,
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.danger, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
      ),
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: _active ? AppColors.headerBottom : AppColors.textSecondary,
        ),
      ),
    );

    final field =
        (widget.validator == null)
            ? TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              obscureText: _obscure,
              style: textStyle,
              cursorColor: AppColors.headerBottom,
              decoration: decoration,
            )
            : TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              obscureText: _obscure,
              validator: widget.validator,
              style: textStyle,
              cursorColor: AppColors.headerBottom,
              decoration: decoration,
            );

    return Padding(
      padding: widget.margin ?? const EdgeInsets.symmetric(horizontal: 25),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow:
              _active
                  ? [
                    BoxShadow(
                      color: AppColors.headerBottom.withOpacity(0.18),
                      blurRadius: 18,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 6),
                    ),
                  ]
                  : [],
        ),
        child: ClipRRect(borderRadius: radius, child: field),
      ),
    );
  }
}
