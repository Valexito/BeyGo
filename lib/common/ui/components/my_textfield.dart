// lib/common/utils/components/ui/my_textfield.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_styles.dart';

class MyTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;

  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  final IconData? prefixIcon;
  final bool circularPrefix;
  final Widget? suffix;
  final EdgeInsetsGeometry? margin;
  final String? labelText;
  final String? helperText;
  final String? errorText;

  final String? Function(String?)? validator;

  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;

  const MyTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.prefixIcon,
    this.circularPrefix = false,
    this.suffix,
    this.margin,
    this.labelText,
    this.helperText,
    this.errorText,
    this.validator,
    this.focusNode,
    this.onFocusChange,
  });

  @override
  State<MyTextField> createState() => _MyTextFieldState();
}

class _MyTextFieldState extends State<MyTextField> {
  late final FocusNode _focusNode;
  bool _ownsFocus = false;

  bool get _active =>
      _focusNode.hasFocus || widget.controller.text.trim().isNotEmpty;

  void _onFocus() {
    setState(() {});
    widget.onFocusChange?.call(_focusNode.hasFocus);
  }

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _ownsFocus = widget.focusNode == null;
    _focusNode.addListener(_onFocus);
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    if (_ownsFocus) _focusNode.dispose();
    super.dispose();
  }

  Widget? _buildPrefix() {
    if (widget.prefixIcon == null) return null;

    final color = _active ? AppColors.headerBottom : AppColors.primary;

    if (!widget.circularPrefix) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 4),
        child: Icon(widget.prefixIcon, color: color),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8, end: 6),
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.iconCircle,
          shape: BoxShape.circle,
        ),
        child: Icon(widget.prefixIcon, size: 16, color: color),
      ),
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
      suffixIcon: widget.suffix,
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
    );

    final field =
        (widget.validator == null)
            ? TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onTap: widget.onTap,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onChanged: widget.onChanged,
              readOnly: widget.readOnly,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              inputFormatters: widget.inputFormatters,
              style: textStyle,
              cursorColor: AppColors.headerBottom,
              decoration: decoration,
            )
            : TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              onTap: widget.onTap,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onChanged: widget.onChanged,
              readOnly: widget.readOnly,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              inputFormatters: widget.inputFormatters,
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
