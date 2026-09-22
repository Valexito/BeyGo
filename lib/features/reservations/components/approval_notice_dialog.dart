// lib/features/reservations/components/approval_notice_dialog.dart
//
// One-time notice shown the first time a reservation's provider approval
// is seen by the user, explaining the free-cancellation window and the
// strike policy for late cancellations. Marks itself handled so it never
// shows again for the same reservation (see Reservation.needsApprovalNotice).
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/reservations/reservations.dart';

Future<void> showApprovalNoticeDialog(
  BuildContext context, {
  required Reservation reservation,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ApprovalNoticeDialog(reservation: reservation),
  );

  try {
    await FirebaseFirestore.instance
        .collection('reservations')
        .doc(reservation.id)
        .set({'approvalNoticeHandled': true}, SetOptions(merge: true));
  } catch (_) {
    // Best-effort: if this fails the notice may show again next time, which
    // is a much smaller problem than crashing the flow over it.
  }
}

class _ApprovalNoticeDialog extends StatelessWidget {
  final Reservation reservation;
  const _ApprovalNoticeDialog({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final minutes = reservation.freeCancellationMinutes;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(AppDims.radiusXl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDarkMode ? 0.24 : 0.10,
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
                  gradient: LinearGradient(
                    colors:
                        context.isDarkMode
                            ? const [Color(0xFF1E3A5F), Color(0xFF0F172A)]
                            : const [AppColors.headerTop, AppColors.headerBottom],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.headerBottom.withValues(alpha: 0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
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
                  color:
                      context.isDarkMode
                          ? context.appBrandIconColor.withValues(alpha: 0.14)
                          : AppColors.primarySoft.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: MyText(
                  text: '¡Solicitud aprobada!',
                  variant: MyTextVariant.normalBold,
                  customColor:
                      context.isDarkMode
                          ? context.appBrandTextColor
                          : AppColors.headerBottom,
                  fontSize: 16,
                ),
              ),
              if (reservation.reservationNumber != null) ...[
                const SizedBox(height: 8),
                MyText(
                  text: 'Reservación No. ${reservation.reservationNumber}',
                  variant: MyTextVariant.bodyMuted,
                  fontSize: 13,
                ),
              ],
              const SizedBox(height: 14),
              MyText(
                text:
                    'Tienes $minutes minutos para cancelar gratis. '
                    'Después de ese tiempo, cancelar sumará una falta '
                    '(strike) a tu cuenta.',
                variant: MyTextVariant.subtitle,
                textAlign: TextAlign.center,
                fontSize: 13,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: MyButton(
                  text: 'Entendido',
                  onTap: () => Navigator.pop(context),
                  margin: EdgeInsets.zero,
                  height: 48,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => const FrequentQuestionsPage(),
                    ),
                  );
                },
                child: Text(
                  'Más información: preguntas frecuentes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        context.isDarkMode
                            ? context.appBrandTextColor
                            : AppColors.headerBottom,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
