import 'package:flutter/material.dart';
import 'package:beygo/common/common.dart';
class OwnerDialogs {
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required bool isExit,
  }) {
    final accent = isExit ? const Color(0xFF0EA5E9) : const Color(0xFFF59E0B);

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: ctx.appCardBackground,
              borderRadius: BorderRadius.circular(AppDims.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: ctx.isDarkMode ? 0.28 : 0.10,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      isExit ? Icons.logout_rounded : Icons.cancel_rounded,
                      color: accent,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: MyText(
                      text:
                          isExit ? 'Confirmar salida' : 'Confirmar cancelación',
                      variant: MyTextVariant.normalBold,
                      customColor: accent,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  MyText(
                    text:
                        isExit
                            ? '¿Seguro que deseas aprobar esta salida?'
                            : '¿Seguro que deseas aprobar esta cancelación?',
                    variant: MyTextVariant.subtitle,
                    textAlign: TextAlign.center,
                    fontSize: 13,
                    customColor: ctx.appTextPrimaryColor,
                  ),
                  const SizedBox(height: 10),
                  MyText(
                    text:
                        'Esta acción actualizará el estado de la reservación.',
                    variant: MyTextVariant.bodyMuted,
                    textAlign: TextAlign.center,
                    fontSize: 12,
                    customColor: ctx.appTextSecondaryColor,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.headerBottom.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDims.radiusLg,
                                ),
                              ),
                              backgroundColor: ctx.appCardBackground,
                            ),
                            child: const MyText(
                              text: 'Cancelar',
                              variant: MyTextVariant.normalBold,
                              customColor: AppColors.headerBottom,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MyButton(
                          text: 'Confirmar',
                          onTap: () {
                            Navigator.of(ctx, rootNavigator: true).pop(true);
                          },
                          margin: EdgeInsets.zero,
                          height: 48,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
