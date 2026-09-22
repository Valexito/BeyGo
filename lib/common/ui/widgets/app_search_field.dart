// lib/common/ui/widgets/app_search_field.dart
//
// Barra de búsqueda reutilizable — mismo estilo/comportamiento que el
// buscador de "Mis Reservaciones" (usuario), para reutilizarlo en otras
// pantallas (por ejemplo, Solicitudes y Reservas del proveedor).
import 'package:flutter/material.dart';
import 'package:beygo/common/ui/components/app_styles.dart';

class AppSearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Buscar por No., nombre, placa...',
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.appInputBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _hasFocus
              ? AppColors.headerBottom.withValues(alpha: 0.55)
              : context.appBorderColor,
          width: _hasFocus ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _hasFocus
                ? AppColors.headerBottom.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: context.isDarkMode ? 0.06 : 0.03),
            blurRadius: _hasFocus ? 16 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        textInputAction: TextInputAction.search,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.isDarkMode ? Colors.white : context.appTextPrimaryColor,
        ),
        decoration: InputDecoration(
          filled: false,
          hintText: widget.hintText,
          hintStyle: TextStyle(
            fontSize: 13,
            color: context.appTextSecondaryColor,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(13),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: _hasFocus
                  ? (context.isDarkMode ? Colors.white : AppColors.headerBottom)
                  : context.appTextSecondaryColor,
            ),
          ),
          suffixIcon: widget.controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    widget.controller.clear();
                    widget.onChanged('');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: context.appBorderColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 12,
                        color: context.appTextSecondaryColor,
                      ),
                    ),
                  ),
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
