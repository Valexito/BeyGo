// lib/features/reservations/components/reservation_dialogs.dart
//
// ✅ FIXED: Added google_maps_flutter import → LatLng is now defined
//
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // ← ADDED — fixes "Undefined class 'LatLng'"

import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_button.dart';
import 'package:mapbox_api/common/ui/components/my_text.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';

class ReservationDialogs {
  static Future<bool?> showConfirmReservationDialog(
    BuildContext context, {
    required LatLng destination, // ✅ now resolves correctly
    required String parkingName,
    required int spaceNumber,
    required int pricePerHour,
  }) {
    debugPrint('[CONFIRM DIALOG] parkingName: $parkingName');
    debugPrint('[CONFIRM DIALOG] spaceNumber: $spaceNumber');
    debugPrint('[CONFIRM DIALOG] pricePerHour: $pricePerHour');
    debugPrint(
      '[CONFIRM DIALOG] destination: ${destination.latitude}, ${destination.longitude}',
    );
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
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
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.24),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.event_available_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const MyText(
                        text: 'Confirmar reserva',
                        variant: MyTextVariant.title,
                        customColor: Colors.white,
                        textAlign: TextAlign.center,
                        fontSize: 21,
                      ),
                      const SizedBox(height: 6),
                      const MyText(
                        text:
                            'Revisa los detalles antes de continuar con tu reservación.',
                        variant: MyTextVariant.bodyMuted,
                        customColor: Colors.white70,
                        textAlign: TextAlign.center,
                        fontSize: 12,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.headerBottom.withOpacity(0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const MyText(
                              text: 'Resumen de reserva',
                              variant: MyTextVariant.normalBold,
                              fontSize: 15,
                            ),
                            const SizedBox(height: 14),
                            _SummaryRow(
                              icon: Icons.local_parking_outlined,
                              title: 'Parqueo',
                              value: parkingName,
                            ),
                            const SizedBox(height: 12),
                            _SummaryRow(
                              icon: Icons.pin_outlined,
                              title: 'Espacio',
                              value: 'Espacio $spaceNumber',
                            ),
                            const SizedBox(height: 12),
                            _SummaryRow(
                              icon: Icons.access_time_rounded,
                              title: 'Inicio',
                              value: _format(DateTime.now()),
                            ),
                            const SizedBox(height: 12),
                            _SummaryRow(
                              icon: Icons.payments_outlined,
                              title: 'Precio por hora',
                              value:
                                  pricePerHour > 0
                                      ? 'Q $pricePerHour/h'
                                      : 'No disponible',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppColors.headerBottom.withOpacity(
                                      0.35,
                                    ),
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                                child: const MyText(
                                  text: 'Cancelar',
                                  variant: MyTextVariant.normalBold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MyButton(
                              text: 'Confirmar',
                              onTap: () => Navigator.of(ctx).pop(true),
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
      },
    );
  }

  static Future<bool?> showCancelDialog(
    BuildContext context, {
    required int usedStrikes,
    required int maxStrikes,
    required bool freeWindow,
  }) {
    final previewStrike = freeWindow ? usedStrikes : usedStrikes + 1;

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppDims.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withOpacity(0.10),
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
                  _circleIcon(Icons.warning_amber_rounded),
                  const SizedBox(height: 16),
                  _title('Confirmar cancelación'),
                  const SizedBox(height: 12),
                  const MyText(
                    text: '¿Deseas cancelar esta reservación?',
                    variant: MyTextVariant.subtitle,
                    textAlign: TextAlign.center,
                    fontSize: 13,
                  ),
                  const SizedBox(height: 10),
                  MyText(
                    text:
                        freeWindow
                            ? 'Estás dentro del tiempo permitido. No se agregará strike.'
                            : 'Esta cancelación agregará un strike a tu cuenta.',
                    variant: MyTextVariant.bodyMuted,
                    textAlign: TextAlign.center,
                    fontSize: 12,
                  ),
                  const SizedBox(height: 12),
                  _strikeBox(previewStrike, maxStrikes),
                  const SizedBox(height: 20),
                  _actions(ctx, 'Aceptar'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<bool?> showExitDialog(
    BuildContext context, {
    required Reservation reservation,
  }) {
    final start = reservation.reservedAt;
    final lockedAt = reservation.exitLockedAt ?? reservation.reservedAt;
    final duration = lockedAt.difference(start);

    final totalMinutes = duration.inMinutes < 0 ? 0 : duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final durationText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    final rate = reservation.pricePerHour ?? 0;
    final estimated = reservation.estimatedAmount;

    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(AppDims.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withOpacity(0.10),
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
                  _circleIcon(Icons.exit_to_app_rounded),
                  const SizedBox(height: 16),
                  _title('Confirmar solicitud de salida'),
                  const SizedBox(height: 12),
                  const MyText(
                    text: '¿Deseas solicitar tu salida?',
                    variant: MyTextVariant.subtitle,
                    textAlign: TextAlign.center,
                    fontSize: 13,
                  ),
                  const SizedBox(height: 10),
                  const MyText(
                    text:
                        'Se notificará al propietario para aprobar tu salida.',
                    variant: MyTextVariant.bodyMuted,
                    textAlign: TextAlign.center,
                    fontSize: 12,
                  ),
                  const SizedBox(height: 16),
                  _infoBox([
                    _Row(
                      Icons.local_parking_rounded,
                      'Parqueo',
                      reservation.parkingName,
                    ),
                    _Row(
                      Icons.confirmation_number_outlined,
                      'Espacio',
                      '${reservation.spaceNumber}',
                    ),
                    _Row(
                      Icons.play_circle_outline_rounded,
                      'Inicio',
                      _format(start),
                    ),
                    _Row(
                      Icons.lock_clock_rounded,
                      'Salida registrada',
                      _format(lockedAt),
                    ),
                    _Row(Icons.timelapse_rounded, 'Duración', durationText),
                    _Row(
                      Icons.payments_outlined,
                      'Tarifa',
                      rate > 0 ? 'Q $rate/hora' : 'Pendiente',
                    ),
                    _Row(
                      Icons.receipt_long_outlined,
                      'Monto estimado',
                      estimated != null ? 'Q $estimated' : 'Pendiente',
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _actions(ctx, 'Confirmar salida'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _circleIcon(IconData icon) => Container(
    width: 62,
    height: 62,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.headerTop, AppColors.headerBottom],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: AppColors.headerBottom.withOpacity(0.22),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: 30),
  );

  static Widget _title(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.primarySoft.withOpacity(0.25),
      borderRadius: BorderRadius.circular(20),
    ),
    child: MyText(
      text: text,
      variant: MyTextVariant.normalBold,
      customColor: AppColors.headerBottom,
      fontSize: 16,
    ),
  );

  static Widget _strikeBox(int used, int max) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F7F9),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        const MyText(
          text: 'Strikes',
          variant: MyTextVariant.bodyMuted,
          fontSize: 12,
        ),
        const SizedBox(height: 4),
        MyText(
          text: '$used/$max',
          variant: MyTextVariant.bodyBold,
          fontSize: 18,
          customColor: AppColors.headerBottom,
        ),
      ],
    ),
  );

  static Widget _infoBox(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F7F9),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: List.generate(children.length, (index) {
        final isLast = index == children.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: children[index],
        );
      }),
    ),
  );

  static Widget _actions(BuildContext ctx, String confirmText) => Row(
    children: [
      Expanded(
        child: SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppColors.headerBottom.withOpacity(0.35),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDims.radiusLg),
              ),
              backgroundColor: Colors.white,
            ),
            child: const MyText(
              text: 'No',
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
          text: confirmText,
          onTap: () => Navigator.pop(ctx, true),
          margin: EdgeInsets.zero,
          height: 48,
        ),
      ),
    ],
  );

  static String _format(DateTime v) {
    final y = v.year.toString().padLeft(4, '0');
    final m = v.month.toString().padLeft(2, '0');
    final d = v.day.toString().padLeft(2, '0');
    final h = v.hour.toString().padLeft(2, '0');
    final min = v.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: AppColors.iconCircle,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppColors.headerBottom),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MyText(
            text: label,
            variant: MyTextVariant.bodyMuted,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: MyText(
            text: value,
            variant: MyTextVariant.bodyBold,
            fontSize: 13,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: AppColors.iconCircle,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: AppColors.headerBottom),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyText(
                text: title,
                variant: MyTextVariant.bodyMuted,
                fontSize: 12,
              ),
              const SizedBox(height: 2),
              MyText(text: value, variant: MyTextVariant.body, fontSize: 13),
            ],
          ),
        ),
      ],
    );
  }
}
