import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_button.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/features/reservations/components/reservation_dialogs.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';

class ReservationDetailsSheet extends ConsumerStatefulWidget {
  final Reservation reservation;

  const ReservationDetailsSheet({super.key, required this.reservation});

  @override
  ConsumerState<ReservationDetailsSheet> createState() =>
      _ReservationDetailsSheetState();
}

class _ReservationDetailsSheetState
    extends ConsumerState<ReservationDetailsSheet> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final requestExit = ref.read(requestExitProvider);
    final complete = ref.read(completeReservationWithBillingProvider);
    final cancel = ref.read(cancelReservationProvider);
    final reservation = widget.reservation;
    final controlAsync = ref.watch(userReservationControlProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: controlAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (_, __) => _buildContent(
                context: context,
                reservation: reservation,
                requestExit: requestExit,
                complete: complete,
                cancel: cancel,
                usedStrikes: 0,
                maxStrikes: Reservation.maxCancellationAttemptsLimit,
                limitReached: false,
              ),
          data: (control) {
            final used = (control?['cancelAttempts'] as num?)?.toInt() ?? 0;
            final max = Reservation.maxCancellationAttemptsLimit;
            final limitReached = used >= max;

            return _buildContent(
              context: context,
              reservation: reservation,
              requestExit: requestExit,
              complete: complete,
              cancel: cancel,
              usedStrikes: used,
              maxStrikes: max,
              limitReached: limitReached,
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required Reservation reservation,
    required Future<void> Function({required Reservation reservation})
    requestExit,
    required Future<void> Function({required Reservation r}) complete,
    required Future<void> Function({required Reservation reservation}) cancel,
    required int usedStrikes,
    required int maxStrikes,
    required bool limitReached,
  }) {
    final canCancel =
        reservation.state == 'active' &&
        reservation.exitStatus == 'none' &&
        !limitReached;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 5,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.borderSoft,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.headerTop, AppColors.headerBottom],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.headerBottom.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_parking_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 14),
        MyText(
          text: reservation.parkingName,
          variant: MyTextVariant.bodyBold,
          fontSize: 20,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primarySoft.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
          ),
          child: MyText(
            text: 'Espacio ${reservation.spaceNumber}',
            variant: MyTextVariant.bodyMuted,
            fontSize: 12,
            customColor: AppColors.headerBottom,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.info_outline,
                label: 'Estado',
                value: _displayStatus(reservation),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.access_time_rounded,
                label: 'Inicio',
                value: _formatDateTime(reservation.reservedAt),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.payments_outlined,
                label: 'Tarifa',
                value:
                    reservation.pricePerHour != null
                        ? 'Q ${reservation.pricePerHour}/hora'
                        : 'Pendiente',
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.receipt_long_outlined,
                label: 'Monto',
                value:
                    reservation.amount != null
                        ? 'Q ${reservation.amount}'
                        : 'Pendiente',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (reservation.state == 'active' && reservation.exitStatus == 'none')
          Row(
            children: [
              if (canCancel)
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed:
                          _isProcessing
                              ? null
                              : () async {
                                final confirm =
                                    await _showCancelConfirmationDialog(
                                      context,
                                      usedStrikes: usedStrikes,
                                      maxStrikes: maxStrikes,
                                      freeWindow:
                                          _isWithinFreeCancellationWindowLocal(
                                            reservation,
                                          ),
                                    );

                                if (confirm != true || !mounted) return;

                                setState(() => _isProcessing = true);
                                try {
                                  await cancel(reservation: reservation);
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                } catch (e, st) {
                                  debugPrint('CANCEL ERROR: $e');
                                  debugPrintStack(stackTrace: st);
                                  if (!mounted) return;
                                  _showError(context, e.toString());
                                } finally {
                                  if (mounted) {
                                    setState(() => _isProcessing = false);
                                  }
                                }
                              },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.headerBottom.withOpacity(0.35),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.white,
                      ),
                      child: const MyText(
                        text: 'Cancelar reserva',
                        variant: MyTextVariant.normalBold,
                        customColor: AppColors.headerBottom,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              if (canCancel) const SizedBox(width: 12),
              Expanded(
                child: MyButton(
                  text: _isProcessing ? 'Procesando...' : 'Solicitar salida',
                  onTap:
                      _isProcessing
                          ? null
                          : () async {
                            final confirm =
                                await ReservationDialogs.showExitDialog(
                                  context,
                                  reservation: reservation,
                                );

                            if (confirm != true || !mounted) return;

                            setState(() => _isProcessing = true);
                            try {
                              await requestExit(reservation: reservation);
                              if (!mounted) return;
                              Navigator.pop(context);
                            } catch (e, st) {
                              debugPrint('EXIT ERROR: $e');
                              debugPrintStack(stackTrace: st);
                              if (!mounted) return;
                              _showError(context, e.toString());
                            } finally {
                              if (mounted) {
                                setState(() => _isProcessing = false);
                              }
                            }
                          },
                  margin: EdgeInsets.zero,
                  height: 48,
                ),
              ),
            ],
          ),
        if (reservation.state == 'active' &&
            reservation.exitStatus == 'requested')
          MyButton(
            text: 'Esperando aprobación...',
            onTap: null,
            margin: EdgeInsets.zero,
          ),
        if (reservation.state == 'active' &&
            reservation.exitStatus == 'approved')
          MyButton(
            text: _isProcessing ? 'Procesando...' : 'Finalizar y pagar',
            onTap:
                _isProcessing
                    ? null
                    : () async {
                      setState(() => _isProcessing = true);
                      try {
                        await complete(r: reservation);
                        if (!mounted) return;
                        Navigator.pop(context);
                      } catch (e, st) {
                        debugPrint('COMPLETE ERROR: $e');
                        debugPrintStack(stackTrace: st);
                        if (!mounted) return;
                        _showError(context, e.toString());
                      } finally {
                        if (mounted) {
                          setState(() => _isProcessing = false);
                        }
                      }
                    },
            margin: EdgeInsets.zero,
          ),
      ],
    );
  }

  Future<bool?> _showCancelConfirmationDialog(
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
                  Container(
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
                    child: const Icon(
                      Icons.warning_amber_rounded,
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
                      color: AppColors.primarySoft.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const MyText(
                      text: 'Confirmar cancelación',
                      variant: MyTextVariant.normalBold,
                      customColor: AppColors.headerBottom,
                      fontSize: 16,
                    ),
                  ),
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                          text: '$previewStrike/$maxStrikes',
                          variant: MyTextVariant.bodyBold,
                          fontSize: 18,
                          customColor: AppColors.headerBottom,
                        ),
                      ],
                    ),
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
                                color: AppColors.headerBottom.withOpacity(0.35),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDims.radiusLg,
                                ),
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
                          onTap: () => Navigator.pop(ctx, true),
                          text: 'Aceptar',
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

  bool _isWithinFreeCancellationWindowLocal(Reservation reservation) {
    final now = DateTime.now();

    if (reservation.freeCancellationUntil != null) {
      return now.isBefore(reservation.freeCancellationUntil!) ||
          now.isAtSameMomentAs(reservation.freeCancellationUntil!);
    }

    final elapsedMinutes = now.difference(reservation.reservedAt).inMinutes;
    return elapsedMinutes <= Reservation.freeCancellationWindowMinutesLimit;
  }

  String _displayStatus(Reservation r) {
    if (r.state == 'completed') return 'Completada';
    if (r.state == 'cancelled') return 'Cancelada';
    if (r.state == 'cancellation_requested') return 'Cancelación pendiente';
    if (r.state == 'active' && r.exitStatus == 'approved') {
      return 'Salida aprobada';
    }
    if (r.state == 'active' && r.exitStatus == 'requested') {
      return 'Salida solicitada';
    }
    return 'Activa';
  }

  String _formatDateTime(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

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
