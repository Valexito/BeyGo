// lib/features/reservations/components/reservation_details_sheet.dart
//
// ✅ ADDED: Rating dialog shown to USER after exit is approved (reservation completes)
// ✅ Listens to reservation stream — when state → 'completed', show rating popup
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/reservations/reservations.dart';

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
    final controlAsync = ref.watch(userReservationControlProvider);

    final reservationAsync = ref.watch(
      _reservationStreamProvider(widget.reservation.id),
    );

    final reservation = reservationAsync.maybeWhen(
      data: (r) => r,
      orElse: () => widget.reservation,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      decoration: BoxDecoration(
        color: context.appSectionBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
    final isApproved = reservation.providerApprovalStatus == 'approved';

    final canCancel =
        reservation.state == 'active' &&
        reservation.exitStatus == 'none' &&
        !limitReached &&
        isApproved;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        Container(
          width: 42,
          height: 5,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: context.appBorderColor,
            borderRadius: BorderRadius.circular(999),
          ),
        ),

        // Header icon
        Container(
          width: 64,
          height: 64,
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
                color: AppColors.headerBottom.withValues(alpha: 0.18),
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
            color:
                context.isDarkMode
                    ? context.appBrandIconColor.withValues(alpha: 0.14)
                    : AppColors.primarySoft.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(999),
          ),
          child: MyText(
            text: 'Espacio ${reservation.spaceNumber}',
            variant: MyTextVariant.bodyMuted,
            fontSize: 12,
            customColor:
                context.isDarkMode
                    ? context.appBrandTextColor
                    : AppColors.headerBottom,
          ),
        ),
        const SizedBox(height: 18),

        // Info box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appCardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appBorderColor),
          ),
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.info_outline,
                label: 'Estado',
                value: _displayStatus(reservation),
              ),
              if ((reservation.state == 'active' ||
                      reservation.state == 'completed') &&
                  reservation.providerApprovalStatus == 'approved' &&
                  reservation.reservationNumber != null) ...[
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'No. de reservación',
                  value: reservation.reservationNumber!,
                ),
              ],
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
              if (reservation.state == 'completed') ...[
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.stop_circle_outlined,
                  label: 'Salida',
                  value:
                      reservation.endedAt != null
                          ? _formatDateTime(reservation.endedAt!)
                          : 'Pendiente',
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.timelapse_outlined,
                  label: 'Duración',
                  value:
                      reservation.durationMinutes != null
                          ? _formatDuration(reservation.durationMinutes!)
                          : 'Pendiente',
                ),
              ],
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.receipt_long_outlined,
                label: 'Monto',
                value: _displayAmount(reservation),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Action buttons ─────────────────────────────────────────────
        if (reservation.state == 'pending')
          MyButton(
            text: 'Esperando aprobación del dueño...',
            onTap: null,
            margin: EdgeInsets.zero,
          ),

        if (reservation.state == 'active' &&
            reservation.providerApprovalStatus != 'approved')
          MyButton(
            text: 'Pendiente de aprobación...',
            onTap: null,
            margin: EdgeInsets.zero,
          ),

        if (reservation.state == 'active' &&
            reservation.exitStatus == 'none' &&
            isApproved)
          Row(
            children: [
              if (canCancel) ...[
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
                                  if (mounted) Navigator.pop(context);
                                } catch (e, st) {
                                  debugPrint('CANCEL ERROR: $e');
                                  debugPrintStack(stackTrace: st);
                                  if (mounted)
                                    _showError(context, e.toString());
                                } finally {
                                  if (mounted)
                                    setState(() => _isProcessing = false);
                                }
                              },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: context.appBrandIconColor.withValues(
                            alpha: 0.35,
                          ),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDims.radiusLg,
                          ),
                        ),
                        backgroundColor: context.appCardBackground,
                      ),
                      child: const MyText(
                        text: 'Cancelar reserva',
                        variant: MyTextVariant.normalBold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: MyButton(
                  text: _isProcessing ? 'Procesando...' : 'Solicitar salida',
                  onTap:
                      _isProcessing
                          ? null
                          : () async {
                            final now = DateTime.now();
                            final dur =
                                now
                                    .difference(reservation.reservedAt)
                                    .inMinutes;
                            final ph = reservation.pricePerHour ?? 0;
                            final est = (ph / 60.0) * dur;

                            final updated = reservation.copyWith(
                              estimatedAmount: est.toInt(),
                              estimatedDurationMinutes: dur,
                              exitLockedAt: now,
                            );

                            final confirm =
                                await ReservationDialogs.showExitDialog(
                                  context,
                                  reservation: updated,
                                );
                            if (confirm != true || !mounted) return;

                            setState(() => _isProcessing = true);
                            try {
                              await requestExit(reservation: updated);
                              if (mounted) Navigator.pop(context);
                            } catch (e, st) {
                              debugPrint('EXIT ERROR: $e');
                              debugPrintStack(stackTrace: st);
                              if (mounted) _showError(context, e.toString());
                            } finally {
                              if (mounted)
                                setState(() => _isProcessing = false);
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
            text: 'Esperando aprobación de salida...',
            onTap: null,
            margin: EdgeInsets.zero,
          ),

        // ✅ "Finalizar y pagar" — triggers rating dialog via stream
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
                        // Rating dialog is triggered by the stream listener above
                        // when state changes to 'completed'
                      } catch (e, st) {
                        debugPrint('COMPLETE ERROR: $e');
                        debugPrintStack(stackTrace: st);
                        if (mounted) _showError(context, e.toString());
                        if (mounted) setState(() => _isProcessing = false);
                      }
                    },
            margin: EdgeInsets.zero,
          ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool?> _showCancelConfirmationDialog(
    BuildContext context, {
    required int usedStrikes,
    required int maxStrikes,
    required bool freeWindow,
  }) {
    final previewStrike = freeWindow ? usedStrikes : usedStrikes + 1;

    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: ctx.appCardBackground,
                borderRadius: BorderRadius.circular(AppDims.radiusXl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: ctx.isDarkMode ? 0.24 : 0.10,
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
                              ctx.isDarkMode
                                  ? const [Color(0xFF1E3A5F), Color(0xFF0F172A)]
                                  : const [
                                    AppColors.headerTop,
                                    AppColors.headerBottom,
                                  ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.headerBottom.withValues(
                              alpha: 0.22,
                            ),
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
                        color:
                            ctx.isDarkMode
                                ? ctx.appBrandIconColor.withValues(
                                  alpha: 0.14,
                                )
                                : AppColors.primarySoft.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: MyText(
                        text: 'Confirmar cancelación',
                        variant: MyTextVariant.normalBold,
                        customColor:
                            ctx.isDarkMode
                                ? ctx.appBrandTextColor
                                : AppColors.headerBottom,
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
                              ? 'Estás dentro del tiempo permitido. No se agregará penalización.'
                              : 'Esta cancelación agregará una penalización a tu cuenta.',
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
                        color: ctx.appCardBackgroundSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const MyText(
                            text: 'Penalizaciones',
                            variant: MyTextVariant.bodyMuted,
                            fontSize: 12,
                          ),
                          const SizedBox(height: 4),
                          MyText(
                            text: '$previewStrike/$maxStrikes',
                            variant: MyTextVariant.bodyBold,
                            fontSize: 18,
                            customColor:
                                ctx.isDarkMode
                                    ? ctx.appBrandTextColor
                                    : AppColors.headerBottom,
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
                                  color: ctx.appBrandIconColor.withValues(
                                    alpha: 0.35,
                                  ),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppDims.radiusLg,
                                  ),
                                ),
                                backgroundColor: ctx.appCardBackground,
                              ),
                              child: MyText(
                                text: 'No',
                                variant: MyTextVariant.normalBold,
                                customColor:
                                    ctx.isDarkMode
                                        ? ctx.appBrandTextColor
                                        : AppColors.headerBottom,
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
          ),
    );
  }

  bool _isWithinFreeCancellationWindowLocal(Reservation reservation) {
    final now = DateTime.now();
    if (reservation.freeCancellationUntil != null) {
      return now.isBefore(reservation.freeCancellationUntil!) ||
          now.isAtSameMomentAs(reservation.freeCancellationUntil!);
    }
    final elapsedMinutes = now.difference(reservation.reservedAt).inMinutes;
    return elapsedMinutes <= reservation.freeCancellationMinutes;
  }

  String _displayStatus(Reservation r) {
    if (r.providerApprovalStatus == 'rejected') return 'Rechazada';
    final cancelledByOwner =
        r.state == 'cancelled' && _isOwnerInitiatedCancellation(r);
    if (r.state == 'pending') return 'Pendiente';
    if (r.state == 'completed') return 'Completada';
    if (cancelledByOwner) return 'Cancelada por propietario';
    if (r.state == 'cancelled') return 'Cancelada por usuario';
    if (r.state == 'cancellation_requested') return 'Cancelación pendiente';
    if (r.state == 'active' && r.exitStatus == 'approved')
      return 'Salida aprobada';
    if (r.state == 'active' && r.exitStatus == 'requested')
      return 'Salida solicitada';
    return 'Activa';
  }

  String _displayAmount(Reservation r) {
    if (r.isRejectedByProvider) {
      return 'Solicitud rechazada';
    }
    final cancelledByOwner =
        r.state == 'cancelled' && _isOwnerInitiatedCancellation(r);

    if (cancelledByOwner) {
      return 'Cancelada por propietario';
    }
    if (r.state == 'cancelled') {
      return 'Cancelada por usuario';
    }
    if (r.amount != null) return 'Q ${r.amount}';
    if (r.estimatedAmount != null) return 'Q ${r.estimatedAmount}';
    if (r.exitStatus == 'requested' || r.exitStatus == 'approved') {
      return 'Calculando...';
    }
    if (r.state == 'completed') return 'Pendiente';
    return 'Pendiente de salida';
  }

  bool _isOwnerInitiatedCancellation(Reservation reservation) {
    if (reservation.cancelledBy == 'owner') return true;
    if (reservation.cancelledBy == 'user') return false;
    final reason =
        (reservation.cancellationReason ?? '').trim().toLowerCase();
    return reason == 'cancelado por el propietario' ||
        reason == 'cancelada por el propietario' ||
        reason == 'cancelado por propietario' ||
        reason == 'cancelada por propietario';
  }

  String _formatDateTime(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ─── Stream provider for a single reservation (live updates) ──────────────
final _reservationStreamProvider = StreamProvider.autoDispose
    .family<Reservation, String>((ref, id) {
      return FirebaseFirestore.instance
          .collection('reservations')
          .doc(id)
          .snapshots()
          .map((snap) => Reservation.fromDoc(snap));
    });

// ─── InfoRow widget ───────────────────────────────────────────────────────
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
          decoration: BoxDecoration(
            color: context.appIconCircleColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: context.appBrandIconColor),
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
