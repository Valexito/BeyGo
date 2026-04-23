// lib/features/owner/pages/owner_reservations_page.dart
//
// ✅ ADDED: Reject button in _OwnerApproveCard (alongside Approve)
// ✅ Uses ownerRejectReservationProvider from reservations_providers.dart
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_button.dart';
import 'package:mapbox_api/common/ui/components/my_text.dart';
import 'package:mapbox_api/features/owner/widgets/app_header.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';

class OwnerReservationsPage extends ConsumerStatefulWidget {
  const OwnerReservationsPage({super.key});

  @override
  ConsumerState<OwnerReservationsPage> createState() =>
      _OwnerReservationsPageState();
}

class _OwnerReservationsPageState extends ConsumerState<OwnerReservationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(ownerAllReservationsProvider);
    final isDark = context.isDarkMode;

    return OwnerOnly(
      builder:
          (_) => Column(
            children: [
              const AppHeader(
                title: 'Reservaciones',
                subtitle: 'Gestiona tus reservas y solicitudes',
                showBack: true,
              ),
              Transform.translate(
                offset: const Offset(0, -24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    elevation: 12,
                    color: context.appCardBackground,
                    borderRadius: BorderRadius.circular(24),
                    shadowColor: Colors.black.withValues(
                      alpha: isDark ? 0.24 : 0.10,
                    ),
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.appCardBackground,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.appBorderColor),
                      ),
                      child: TabBar(
                        controller: _tab,
                        indicator: BoxDecoration(
                          color:
                              isDark
                                  ? AppColors.headerBottom.withValues(
                                    alpha: 0.22,
                                  )
                                  : const Color(0xFFEAF0F7),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        labelColor: AppColors.headerBottom,
                        unselectedLabelColor:
                            isDark
                                ? Colors.white.withValues(alpha: 0.88)
                                : Colors.black54,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: 'Activas'),
                          Tab(text: 'Solicitadas'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ClipRect(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      // Active
                      allAsync.when(
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        error: (e, _) => Center(child: Text('$e')),
                        data: (items) {
                          final active =
                              items.where((r) => r.state == 'active').toList();
                          if (active.isEmpty) {
                            return const _EmptyState(
                              icon: Icons.local_parking,
                              title: 'Sin reservas activas',
                              subtitle: 'Las reservas activas aparecerán aquí',
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: active.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 14),
                            itemBuilder:
                                (_, i) => _ActiveCard(reservation: active[i]),
                          );
                        },
                      ),

                      // Pending
                      allAsync.when(
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        error: (e, _) => Center(child: Text('$e')),
                        data: (items) {
                          final pending =
                              items
                                  .where(
                                    (r) =>
                                        r.state == 'pending' &&
                                        r.providerApprovalStatus == 'pending',
                                  )
                                  .toList();
                          if (pending.isEmpty) {
                            return const _EmptyState(
                              icon: Icons.hourglass_empty,
                              title: 'Sin solicitudes',
                              subtitle:
                                  'Las reservas pendientes aparecerán aquí',
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: pending.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 14),
                            itemBuilder:
                                (_, i) => _ApproveCard(reservation: pending[i]),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

// ─── Active card ─────────────────────────────────────────────────────────
class _ActiveCard extends ConsumerWidget {
  final Reservation reservation;
  const _ActiveCard({required this.reservation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      header: 'No. ${reservation.reservationNumber ?? "N/A"}',
      rows: [
        _Row(Icons.info_outline, 'Estado', 'Activa'),
        _Row(Icons.access_time, 'Inicio', _fmt(reservation.reservedAt)),
        _Row(Icons.person_outline, 'Usuario', reservation.userName ?? 'N/A'),
        _Row(
          Icons.directions_car_outlined,
          'Placa',
          reservation.plate ?? 'N/A',
        ),
        _Row(
          Icons.local_parking_outlined,
          'Espacio',
          '${reservation.spaceNumber}',
        ),
      ],
      actions: Center(
        child: SizedBox(
          width: 180,
          child: MyButton(
            text: 'Finalizar',
            height: 42,
            margin: EdgeInsets.zero,
            onTap: () async {
              final ctrl = TextEditingController();
              final ok = await _forceCancelDialog(context, ctrl);
              if (ok != true) {
                ctrl.dispose();
                return;
              }
              try {
                await ref.read(ownerForceCancelProvider)(
                  reservation: reservation,
                  reason: ctrl.text,
                );
              } catch (e) {
                if (context.mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$e')));
              } finally {
                ctrl.dispose();
              }
            },
          ),
        ),
      ),
    );
  }

  Future<bool?> _forceCancelDialog(
    BuildContext context,
    TextEditingController ctrl,
  ) {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GradHeader('Forzar finalización', icon: Icons.flag_rounded),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MyText(
                          text: 'Motivo',
                          variant: MyTextVariant.bodyBold,
                          fontSize: 13,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: ctrl,
                          maxLines: 3,
                          maxLength: 200,
                          decoration: InputDecoration(
                            hintText: 'Ej: Usuario no llegó...',
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
                            contentPadding: const EdgeInsets.all(12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: AppColors.headerBottom.withValues(
                                        alpha: .35,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    backgroundColor: Colors.white,
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
                                height: 46,
                                onTap: () => Navigator.pop(ctx, true),
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
          ),
    );
  }

  String _fmt(DateTime v) {
    return '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')} '
        '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Pending approval card — Approve + Reject ─────────────────────────────
class _ApproveCard extends ConsumerStatefulWidget {
  final Reservation reservation;
  const _ApproveCard({required this.reservation});

  @override
  ConsumerState<_ApproveCard> createState() => _ApproveCardState();
}

class _ApproveCardState extends ConsumerState<_ApproveCard> {
  bool _approving = false;
  bool _rejecting = false;
  bool get _busy => _approving || _rejecting;

  @override
  Widget build(BuildContext context) {
    final approve = ref.read(ownerApproveReservationProvider);
    final reject = ref.read(ownerRejectReservationProvider);

    return _Card(
      header: 'No. ${widget.reservation.reservationNumber ?? "N/A"}',
      rows: [
        _Row(Icons.hourglass_top, 'Estado', 'Pendiente'),
        _Row(
          Icons.person_outline,
          'Usuario',
          widget.reservation.userName ?? 'N/A',
        ),
        _Row(
          Icons.directions_car_outlined,
          'Placa',
          widget.reservation.plate ?? 'N/A',
        ),
        _Row(
          Icons.local_parking_outlined,
          'Espacio',
          '${widget.reservation.spaceNumber}',
        ),
      ],
      actions: Row(
        children: [
          // ── Reject ──────────────────────────────────────────────────────
          Expanded(
            child: SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed:
                    _busy
                        ? null
                        : () async {
                          final ok = await _confirmDialog(
                            context,
                            icon: Icons.cancel_outlined,
                            title: 'Rechazar reserva',
                            message: '¿Rechazar esta solicitud?',
                            confirmText: 'Rechazar',
                            confirmColor: const Color(0xFFDC2626),
                          );
                          if (ok != true || !mounted) return;
                          setState(() => _rejecting = true);
                          try {
                            await reject(reservation: widget.reservation);
                          } catch (e) {
                            if (mounted)
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$e')));
                          } finally {
                            if (mounted) setState(() => _rejecting = false);
                          }
                        },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: const Color(0xFFFEF2F2),
                ),
                child:
                    _rejecting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFDC2626),
                          ),
                        )
                        : const Text(
                          'Rechazar',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Approve ─────────────────────────────────────────────────────
          Expanded(
            child: MyButton(
              text: _approving ? 'Aprobando...' : 'Aprobar',
              height: 44,
              margin: EdgeInsets.zero,
              onTap:
                  _busy
                      ? null
                      : () async {
                        final ok = await _confirmDialog(
                          context,
                          icon: Icons.check_circle_outline_rounded,
                          title: 'Aprobar reserva',
                          message: '¿Aprobar esta solicitud?',
                          confirmText: 'Aprobar',
                        );
                        if (ok != true || !mounted) return;
                        setState(() => _approving = true);
                        try {
                          await approve(reservation: widget.reservation);
                        } catch (e) {
                          if (mounted)
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('$e')));
                        } finally {
                          if (mounted) setState(() => _approving = false);
                        }
                      },
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String confirmText,
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GradHeader(title, icon: icon),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        MyText(
                          text: message,
                          variant: MyTextVariant.bodyMuted,
                          textAlign: TextAlign.center,
                          fontSize: 13,
                          customColor: const Color(0xFF5A6478),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: AppColors.headerBottom.withValues(
                                        alpha: .35,
                                      ),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    backgroundColor: Colors.white,
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
                              child:
                                  confirmColor != null
                                      ? SizedBox(
                                        height: 46,
                                        child: ElevatedButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: confirmColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: Text(
                                            confirmText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      )
                                      : MyButton(
                                        text: confirmText,
                                        height: 46,
                                        onTap: () => Navigator.pop(ctx, true),
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
          ),
    );
  }
}

// ─── Reusable card shell ──────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String header;
  final List<_Row> rows;
  final Widget actions;
  const _Card({
    required this.header,
    required this.rows,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.borderSoft),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        _GradHeader(header),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ...rows.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: r,
                ),
              ),
              const SizedBox(height: 6),
              actions,
            ],
          ),
        ),
      ],
    ),
  );
}

class _GradHeader extends StatelessWidget {
  final String label;
  final IconData? icon;
  const _GradHeader(this.label, {this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.headerTop, AppColors.headerBottom],
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: MyText(
            text: label,
            variant: MyTextVariant.bodyBold,
            customColor: Colors.white,
            textAlign: TextAlign.center,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
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
          customColor: AppColors.headerBottom,
        ),
      ),
      MyText(
        text: value,
        variant: MyTextVariant.bodyBold,
        fontSize: 13,
        customColor: const Color(0xFF6B7280),
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 40, color: AppColors.headerBottom),
        const SizedBox(height: 12),
        MyText(text: title, variant: MyTextVariant.bodyBold),
        const SizedBox(height: 6),
        MyText(text: subtitle, variant: MyTextVariant.bodyMuted),
      ],
    ),
  );
}
