import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_button.dart';

class AppDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool danger;
  final bool showCancel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Widget? extraContent;

  const AppDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.subtitle,
    this.confirmText = 'Confirmar',
    this.cancelText = 'Cancelar',
    this.danger = false,
    this.showCancel = true,
    this.onConfirm,
    this.onCancel,
    this.extraContent,
  });

  static Future<bool?> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    String? subtitle,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool danger = false,
    bool showCancel = true,
    Widget? extraContent,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => AppDialog(
            icon: icon,
            title: title,
            message: message,
            subtitle: subtitle,
            confirmText: confirmText,
            cancelText: cancelText,
            danger: danger,
            showCancel: showCancel,
            extraContent: extraContent,
            onConfirm: () => Navigator.pop(ctx, true),
            onCancel: () => Navigator.pop(ctx, false),
          ),
    );
  }

  List<Color> get _gradientColors =>
      danger
          ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
          : [AppColors.headerTop, AppColors.headerBottom];

  @override
  Widget build(BuildContext context) {
    final headerColor =
        danger ? const Color(0xFFDC2626) : AppColors.headerBottom;
    final isDark = context.isDarkMode;
    final cardColor = context.appCardBackground;
    final bodyTextColor = context.appTextSecondaryColor;
    final headerGradient =
        danger
            ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
            : isDark
            ? const [Color(0xFF111827), Color(0xFF0F172A), Color(0xFF0B1220)]
            : _gradientColors;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.appBorderColor),
          boxShadow: [
            BoxShadow(
              color: headerColor.withValues(alpha: isDark ? 0.20 : 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: headerGradient,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.26),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: bodyTextColor,
                      height: 1.5,
                    ),
                  ),
                  if (extraContent != null) ...[
                    const SizedBox(height: 14),
                    extraContent!,
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (showCancel) ...[
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: onCancel,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.headerBottom.withValues(
                                    alpha: 0.28,
                                  ),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: context.appCardBackgroundSoft,
                              ),
                              child: Text(
                                cancelText,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.headerBottom,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child:
                            danger
                                ? SizedBox(
                                  height: 46,
                                  child: ElevatedButton(
                                    onPressed: onConfirm,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      confirmText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                )
                                : MyButton(
                                  text: confirmText,
                                  height: 46,
                                  onTap: onConfirm,
                                  margin: EdgeInsets.zero,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  AppInputDialog
// ════════════════════════════════════════════════════════════════════════════
//
//  Usage:
//  final reason = await AppInputDialog.show(
//    context,
//    icon: Icons.flag_outlined,
//    title: 'Motivo de cancelación',
//    hintText: 'Ej: Cambio de planes...',
//    confirmText: 'Enviar',
//  );
//  if (reason != null && reason.isNotEmpty) { ... }

class AppInputDialog extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String hintText;
  final String confirmText;
  final int maxLines;
  final int maxLength;

  const AppInputDialog({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.hintText = '',
    this.confirmText = 'Confirmar',
    this.maxLines = 3,
    this.maxLength = 200,
  });

  static Future<String?> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    String hintText = '',
    String confirmText = 'Confirmar',
    int maxLines = 3,
    int maxLength = 200,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => AppInputDialog(
            icon: icon,
            title: title,
            subtitle: subtitle,
            hintText: hintText,
            confirmText: confirmText,
            maxLines: maxLines,
            maxLength: maxLength,
          ),
    );
  }

  @override
  State<AppInputDialog> createState() => _AppInputDialogState();
}

class _AppInputDialogState extends State<AppInputDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.headerBottom.withOpacity(0.16),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.headerTop, AppColors.headerBottom],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.26),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                children: [
                  TextField(
                    controller: _ctrl,
                    maxLines: widget.maxLines,
                    maxLength: widget.maxLength,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF3D4554),
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColors.headerBottom.withOpacity(0.4),
                          width: 1.2,
                        ),
                      ),
                      counterStyle: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, null),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.headerBottom.withOpacity(0.28),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.headerBottom,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MyButton(
                          text: widget.confirmText,
                          height: 46,
                          onTap:
                              () => Navigator.pop(context, _ctrl.text.trim()),
                          margin: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  AppBottomNav
// ════════════════════════════════════════════════════════════════════════════
//
//  Usage:
//  AppBottomNav(
//    currentIndex: _index,
//    onTap: (i) => setState(() => _index = i),
//    items: const [
//      AppNavItem(icon: Icons.home_rounded, label: 'Inicio'),
//      AppNavItem(icon: Icons.receipt_long_outlined, label: 'Reservas', badge: 2),
//      AppNavItem(icon: Icons.history_rounded, label: 'Historial'),
//      AppNavItem(icon: Icons.settings_outlined, label: 'Ajustes'),
//    ],
//  )

class AppNavItem {
  final IconData icon;
  final String label;
  final int? badge;
  const AppNavItem({required this.icon, required this.label, this.badge});
}

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onTap,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.iconCircle,
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color:
                  selected ? AppColors.headerBottom : AppColors.textSecondary,
            );
          }),
          destinations:
              items.map((item) {
                return NavigationDestination(
                  icon: _NavIcon(
                    icon: item.icon,
                    selected: false,
                    badge: item.badge,
                  ),
                  selectedIcon: _NavIcon(
                    icon: item.icon,
                    selected: true,
                    badge: item.badge,
                  ),
                  label: item.label,
                );
              }).toList(),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final int? badge;
  const _NavIcon({required this.icon, required this.selected, this.badge});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          icon,
          color: selected ? AppColors.headerBottom : AppColors.textSecondary,
        ),
        if (badge != null && badge! > 0)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              child: Text(
                badge! > 9 ? '9+' : '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Map controls — AppMapZoomControls, AppMapCenterButton, AppHamburgerButton
// ════════════════════════════════════════════════════════════════════════════
//
//  Usage in a GoogleMap Stack:
//
//  Positioned(
//    right: 12, bottom: 160,
//    child: AppMapZoomControls(controller: _mapController),
//  ),
//  Positioned(
//    right: 12, bottom: 110,
//    child: AppMapCenterButton(onTap: _goToMyLocation),
//  ),
//  Positioned(
//    top: 56, left: 12,
//    child: AppHamburgerButton(
//      onTap: () => Scaffold.of(context).openDrawer(),
//      badgeCount: pendingCount,
//    ),
//  ),

class AppMapZoomControls extends StatelessWidget {
  final GoogleMapController? controller;
  final double zoomStep;

  const AppMapZoomControls({
    super.key,
    required this.controller,
    this.zoomStep = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _MapControlTile(
            icon: Icons.add_rounded,
            onTap: () => controller?.animateCamera(CameraUpdate.zoomIn()),
            topRadius: true,
          ),
          Container(height: 1, color: AppColors.borderSoft),
          _MapControlTile(
            icon: Icons.remove_rounded,
            onTap: () => controller?.animateCamera(CameraUpdate.zoomOut()),
            bottomRadius: true,
          ),
        ],
      ),
    );
  }
}

class AppMapCenterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;

  const AppMapCenterButton({
    super.key,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: _MapControlTile(
        icon: Icons.my_location_rounded,
        onTap: loading ? () {} : onTap,
        topRadius: true,
        bottomRadius: true,
        iconColor: AppColors.headerBottom,
        child:
            loading
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.headerBottom,
                  ),
                )
                : null,
      ),
    );
  }
}

class AppHamburgerButton extends StatelessWidget {
  final VoidCallback onTap;
  final int? badgeCount;

  const AppHamburgerButton({super.key, required this.onTap, this.badgeCount});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.headerBottom.withOpacity(0.14),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.menu_rounded,
              color: AppColors.headerBottom,
              size: 22,
            ),
            if (badgeCount != null && badgeCount! > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MapControlTile extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool topRadius;
  final bool bottomRadius;
  final Color? iconColor;
  final Widget? child;

  const _MapControlTile({
    required this.icon,
    required this.onTap,
    this.topRadius = false,
    this.bottomRadius = false,
    this.iconColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.only(
      topLeft: topRadius ? const Radius.circular(14) : Radius.zero,
      topRight: topRadius ? const Radius.circular(14) : Radius.zero,
      bottomLeft: bottomRadius ? const Radius.circular(14) : Radius.zero,
      bottomRight: bottomRadius ? const Radius.circular(14) : Radius.zero,
    );

    return Material(
      color: Colors.white,
      borderRadius: r,
      child: InkWell(
        onTap: onTap,
        borderRadius: r,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child:
                child ??
                Icon(icon, size: 20, color: iconColor ?? AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  AppSectionCard
// ════════════════════════════════════════════════════════════════════════════
//
//  Usage:
//  AppSectionCard(
//    title: 'Información personal',
//    titleIcon: Icons.person_outline_rounded,
//    dividers: true,
//    children: [
//      AppInfoRow(icon: Icons.person_outline, label: 'Nombre', value: 'Alex'),
//      AppInfoRowSpacer(),
//      AppInfoRow(icon: Icons.phone_outlined, label: 'Teléfono', value: '+502...'),
//    ],
//  )

class AppSectionCard extends StatelessWidget {
  final String? title;
  final IconData? titleIcon;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final bool dividers;

  const AppSectionCard({
    super.key,
    this.title,
    this.titleIcon,
    required this.children,
    this.padding,
    this.dividers = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Row(
            children: [
              if (titleIcon != null) ...[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.headerBottom.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    titleIcon,
                    size: 16,
                    color: AppColors.headerBottom,
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: [
              BoxShadow(
                color: AppColors.headerBottom.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child:
              dividers
                  ? Column(
                    children: List.generate(children.length, (i) {
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: children[i],
                          ),
                          if (i < children.length - 1)
                            Divider(
                              height: 1,
                              color: AppColors.borderSoft,
                              indent: 54,
                            ),
                        ],
                      );
                    }),
                  )
                  : Padding(
                    padding: padding ?? const EdgeInsets.all(16),
                    child: Column(children: children),
                  ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  AppInfoRow
// ════════════════════════════════════════════════════════════════════════════
//
//  Usage:
//  AppInfoRow(icon: Icons.person_outline, label: 'Nombre', value: 'Alex')
//  AppInfoRow.status(label: 'Estado', value: 'Activa', status: AppStatus.active)
//  AppInfoRowSpacer() // vertical gap between rows

enum AppStatus { active, pending, cancelled, completed, warning }

extension AppStatusStyle on AppStatus {
  Color get color {
    switch (this) {
      case AppStatus.active:
        return const Color(0xFF16A34A);
      case AppStatus.pending:
        return const Color(0xFFF59E0B);
      case AppStatus.cancelled:
        return const Color(0xFFDC2626);
      case AppStatus.completed:
        return const Color(0xFF2563EB);
      case AppStatus.warning:
        return const Color(0xFFF59E0B);
    }
  }

  IconData get icon {
    switch (this) {
      case AppStatus.active:
        return Icons.check_circle_outline_rounded;
      case AppStatus.pending:
        return Icons.hourglass_top_rounded;
      case AppStatus.cancelled:
        return Icons.cancel_outlined;
      case AppStatus.completed:
        return Icons.task_alt_rounded;
      case AppStatus.warning:
        return Icons.warning_amber_rounded;
    }
  }
}

class AppInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final AppStatus? status;

  const AppInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.status,
  });

  const AppInfoRow.status({
    super.key,
    required this.label,
    required this.value,
    required AppStatus this.status,
  }) : icon = Icons.info_outline,
       valueColor = null;

  @override
  Widget build(BuildContext context) {
    final effectiveIcon = status?.icon ?? icon;
    final effectiveIconColor = status?.color ?? AppColors.headerBottom;
    final effectiveValueColor =
        status?.color ?? valueColor ?? const Color(0xFF6B7280);

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: AppColors.iconCircle,
            shape: BoxShape.circle,
          ),
          child: Icon(effectiveIcon, size: 15, color: effectiveIconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.headerBottom,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: effectiveValueColor,
          ),
        ),
      ],
    );
  }
}

class AppInfoRowSpacer extends StatelessWidget {
  final double height;
  const AppInfoRowSpacer({super.key, this.height = 10});

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

// ════════════════════════════════════════════════════════════════════════════
//  AppBadge
// ════════════════════════════════════════════════════════════════════════════
//
//  AppBadge(label: 'ACTIVA', color: AppColors.success)
//  AppBadge(label: 'PRINCIPAL', color: AppColors.headerBottom)
//  AppBadge(label: 'PENDIENTE', color: AppColors.warning, icon: Icons.hourglass_top_rounded)

class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final double fontSize;

  const AppBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon != null ? 8 : 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  AppEmptyState
// ════════════════════════════════════════════════════════════════════════════
//
//  AppEmptyState(
//    icon: Icons.receipt_long_outlined,
//    title: 'Sin reservas',
//    subtitle: 'Tus reservas activas aparecerán aquí',
//    action: MyButton(text: 'Reservar ahora', onTap: () {}),
//  )

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.headerBottom.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, size: 34, color: AppColors.headerBottom),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A94A6)),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  AppConfirmSheet  — bottom sheet (lighter than full dialog)
// ════════════════════════════════════════════════════════════════════════════
//
//  final ok = await AppConfirmSheet.show(
//    context,
//    icon: Icons.logout_rounded,
//    title: 'Cerrar sesión',
//    message: '¿Deseas salir de tu cuenta?',
//    confirmText: 'Salir',
//    danger: true,
//  );

class AppConfirmSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool danger;

  const AppConfirmSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.confirmText = 'Confirmar',
    this.cancelText = 'Cancelar',
    this.danger = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool danger = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (_) => AppConfirmSheet(
            icon: icon,
            title: title,
            message: message,
            confirmText: confirmText,
            cancelText: cancelText,
            danger: danger,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionColor =
        danger ? const Color(0xFFDC2626) : AppColors.headerBottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: actionColor.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: actionColor),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8A94A6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.headerBottom.withOpacity(0.25),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    child: Text(
                      cancelText,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.headerBottom,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
