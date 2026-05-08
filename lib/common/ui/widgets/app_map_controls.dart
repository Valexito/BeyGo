import 'package:flutter/material.dart';
import 'package:beygo/common/common.dart';

class AppMapControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback? onMyLocation;
  final bool loadingMyLocation;
  final Color? accentColor;

  const AppMapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    this.onMyLocation,
    this.loadingMyLocation = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? context.appBrandIconColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapCtrlBtn(icon: Icons.add, onTap: onZoomIn),
        const SizedBox(height: 6),
        _MapCtrlBtn(icon: Icons.remove, onTap: onZoomOut),
        if (onMyLocation != null) ...[
          const SizedBox(height: 10),
          _MapCtrlBtn(
            icon:
                loadingMyLocation
                    ? Icons.location_searching_rounded
                    : Icons.my_location_rounded,
            onTap: onMyLocation,
            loading: loadingMyLocation,
            accent: false,
            accentColor: accent,
          ),
        ],
      ],
    );
  }
}

class _MapCtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  final bool accent;
  final Color accentColor;

  const _MapCtrlBtn({
    required this.icon,
    required this.onTap,
    this.loading = false,
    this.accent = false,
    this.accentColor = AppColors.headerBottom,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent ? accentColor : context.appCardBackground,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child:
          loading
              ? Padding(
                padding: const EdgeInsets.all(11),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accent ? Colors.white : accentColor,
                ),
              )
              : Icon(
                icon,
                size: 20,
                color:
                    accent
                        ? Colors.white
                        : (context.isDarkMode
                            ? Colors.white
                            : accentColor),
              ),
    ),
  );
}
