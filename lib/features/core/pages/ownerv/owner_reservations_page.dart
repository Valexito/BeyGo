import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_button.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/features/core/pages/ownerv/widgets/app_header.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart'
    as reservations;
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';

class OwnerReservationsPage extends ConsumerStatefulWidget {
  const OwnerReservationsPage({super.key});

  @override
  ConsumerState<OwnerReservationsPage> createState() =>
      _OwnerReservationsPageState();
}

class _OwnerReservationsPageState extends ConsumerState<OwnerReservationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(reservations.ownerAllReservationsProvider);

    return OwnerOnly(
      builder: (_) {
        return Column(
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
                  color: const Color.fromARGB(255, 255, 255, 255),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.all(6),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: const Color(0xFFEAF0F7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      labelColor: AppColors.headerBottom,
                      unselectedLabelColor: Colors.black54,
                      tabs: const [
                        Tab(text: 'Activas'),
                        Tab(text: 'Solicitadas'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            /// CONTENT
            Expanded(
              child: ClipRect(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    /// ACTIVES
                    allAsync.when(
                      loading:
                          () =>
                              const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('$e')),
                      data: (items) {
                        final active =
                            items.where((r) => r.state == 'active').toList();

                        if (active.isEmpty) {
                          return const _OwnerEmptyState(
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
                              (_, i) =>
                                  _OwnerActiveCard(reservation: active[i]),
                        );
                      },
                    ),

                    /// PENDING APPROVAL
                    allAsync.when(
                      loading:
                          () =>
                              const Center(child: CircularProgressIndicator()),
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
                          return const _OwnerEmptyState(
                            icon: Icons.hourglass_empty,
                            title: 'Sin solicitudes',
                            subtitle: 'Las reservas pendientes aparecerán aquí',
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: pending.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 14),
                          itemBuilder:
                              (_, i) =>
                                  _OwnerApproveCard(reservation: pending[i]),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// ================= ACTIVE =================
class _OwnerActiveCard extends ConsumerWidget {
  final Reservation reservation;

  const _OwnerActiveCard({required this.reservation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.headerTop, AppColors.headerBottom],
              ),
            ),
            child: MyText(
              text: 'Reservation No. ${reservation.reservationNumber ?? 'N/A'}',
              variant: MyTextVariant.bodyBold,
              customColor: Colors.white,
              textAlign: TextAlign.center,
              fontSize: 15,
            ),
          ),

          // ── Info rows ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.info_outline,
                  label: 'Estado',
                  value: 'Activa',
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.access_time,
                  label: 'Inicio',
                  value: _format(reservation.reservedAt),
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Usuario',
                  value: reservation.userName ?? 'N/A',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.directions_car_outlined,
                  label: 'Placa',
                  value: reservation.plate ?? 'N/A',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.local_parking_outlined,
                  label: 'Espacio',
                  value: '${reservation.spaceNumber}',
                ),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 180,
                    child: MyButton(
                      text: 'Finalizar',
                      height: 42,
                      margin: EdgeInsets.zero,
                      onTap: () async {
                        final reasonController = TextEditingController();
                        final result = await showDialog<bool>(
                          context: context,
                          barrierDismissible: true,
                          builder: (ctx) {
                            return Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.symmetric(
                                horizontal: 28,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.headerBottom.withOpacity(
                                        0.16,
                                      ),
                                      blurRadius: 28,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ── Gradient header ──
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        22,
                                        20,
                                        22,
                                      ),
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            AppColors.headerTop,
                                            AppColors.headerBottom,
                                          ],
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
                                              color: Colors.white.withOpacity(
                                                0.16,
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.24,
                                                ),
                                                width: 1.2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.flag_rounded,
                                              color: Colors.white,
                                              size: 26,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          const MyText(
                                            text: 'Forzar finalización',
                                            variant: MyTextVariant.bodyBold,
                                            customColor: Colors.white,
                                            textAlign: TextAlign.center,
                                            fontSize: 17,
                                          ),
                                          const SizedBox(height: 4),
                                          const MyText(
                                            text:
                                                'Esto liberará el espacio y cancelará la reserva',
                                            variant: MyTextVariant.bodyMuted,
                                            customColor: Colors.white70,
                                            textAlign: TextAlign.center,
                                            fontSize: 11,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // ── Body ──
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        20,
                                        20,
                                        20,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const MyText(
                                            text: 'Motivo de cancelación',
                                            variant: MyTextVariant.bodyBold,
                                            fontSize: 13,
                                            customColor: Color(0xFF3D4554),
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: reasonController,
                                            maxLines: 3,
                                            maxLength: 200,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF3D4554),
                                            ),
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Ej: Usuario no llegó, espacio necesario...',
                                              hintStyle: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade400,
                                              ),
                                              filled: true,
                                              fillColor: const Color(
                                                0xFFF1F5F9,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.all(12),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                borderSide: BorderSide.none,
                                              ),
                                              counterStyle: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: SizedBox(
                                                  height: 46,
                                                  child: OutlinedButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          ctx,
                                                          false,
                                                        ),
                                                    style: OutlinedButton.styleFrom(
                                                      side: BorderSide(
                                                        color: AppColors
                                                            .headerBottom
                                                            .withOpacity(0.35),
                                                        width: 1.2,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                      ),
                                                      backgroundColor:
                                                          Colors.white,
                                                    ),
                                                    child: const MyText(
                                                      text: 'Cancelar',
                                                      variant:
                                                          MyTextVariant
                                                              .normalBold,
                                                      customColor:
                                                          AppColors
                                                              .headerBottom,
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
                                                  onTap:
                                                      () => Navigator.pop(
                                                        ctx,
                                                        true,
                                                      ),
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

                        if (result != true) {
                          reasonController.dispose();
                          return;
                        }

                        try {
                          final forceCancel = ref.read(
                            ownerForceCancelProvider,
                          );
                          await forceCancel(
                            reservation: reservation,
                            reason: reasonController.text,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        } finally {
                          reasonController.dispose();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _format(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  }
}

/// ================= APPROVE =================
class _OwnerApproveCard extends ConsumerStatefulWidget {
  final Reservation reservation;

  const _OwnerApproveCard({required this.reservation});

  @override
  ConsumerState<_OwnerApproveCard> createState() => _OwnerApproveCardState();
}

class _OwnerApproveCardState extends ConsumerState<_OwnerApproveCard> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final approve = ref.read(ownerApproveReservationProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.headerTop, AppColors.headerBottom],
              ),
            ),
            child: MyText(
              text:
                  'Reservation No. ${widget.reservation.reservationNumber ?? 'N/A'}',
              variant: MyTextVariant.bodyBold,
              customColor: Colors.white,
              textAlign: TextAlign.center,
              fontSize: 15,
            ),
          ),

          // ── Info rows ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.hourglass_top,
                  label: 'Estado',
                  value: 'Pendiente',
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Usuario',
                  value: widget.reservation.userName ?? 'N/A',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.directions_car_outlined,
                  label: 'Placa',
                  value: widget.reservation.plate ?? 'N/A',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.local_parking_outlined,
                  label: 'Espacio',
                  value: '${widget.reservation.spaceNumber}',
                ),
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 180,
                    child: MyButton(
                      text: _processing ? 'Aprobando...' : 'Aprobar',
                      height: 42,
                      onTap:
                          _processing
                              ? null
                              : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (ctx) {
                                    return Dialog(
                                      backgroundColor: Colors.transparent,
                                      insetPadding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.headerBottom
                                                  .withOpacity(0.16),
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
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    20,
                                                    22,
                                                    20,
                                                    22,
                                                  ),
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    AppColors.headerTop,
                                                    AppColors.headerBottom,
                                                  ],
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
                                                      color: Colors.white
                                                          .withOpacity(0.16),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors.white
                                                            .withOpacity(0.24),
                                                        width: 1.2,
                                                      ),
                                                    ),
                                                    child: const Icon(
                                                      Icons
                                                          .check_circle_outline_rounded,
                                                      color: Colors.white,
                                                      size: 26,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  const MyText(
                                                    text: 'Aprobar reserva',
                                                    variant:
                                                        MyTextVariant.bodyBold,
                                                    customColor: Colors.white,
                                                    textAlign: TextAlign.center,
                                                    fontSize: 17,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    20,
                                                    20,
                                                    20,
                                                    20,
                                                  ),
                                              child: Column(
                                                children: [
                                                  const MyText(
                                                    text:
                                                        '¿Deseas aprobar esta solicitud de reserva?',
                                                    variant:
                                                        MyTextVariant.bodyMuted,
                                                    textAlign: TextAlign.center,
                                                    fontSize: 13,
                                                    customColor: Color(
                                                      0xFF5A6478,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 20),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: SizedBox(
                                                          height: 46,
                                                          child: OutlinedButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.pop(
                                                                      ctx,
                                                                      false,
                                                                    ),
                                                            style: OutlinedButton.styleFrom(
                                                              side: BorderSide(
                                                                color: AppColors
                                                                    .headerBottom
                                                                    .withOpacity(
                                                                      0.35,
                                                                    ),
                                                                width: 1.2,
                                                              ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      16,
                                                                    ),
                                                              ),
                                                              backgroundColor:
                                                                  Colors.white,
                                                            ),
                                                            child: const MyText(
                                                              text: 'Cancelar',
                                                              variant:
                                                                  MyTextVariant
                                                                      .normalBold,
                                                              customColor:
                                                                  AppColors
                                                                      .headerBottom,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: MyButton(
                                                          text: 'Aprobar',
                                                          height: 46,
                                                          onTap:
                                                              () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    true,
                                                                  ),
                                                          margin:
                                                              EdgeInsets.zero,
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
                                if (confirm != true) return;
                                setState(() => _processing = true);
                                try {
                                  await approve(
                                    reservation: widget.reservation,
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() => _processing = false);
                                  }
                                }
                              },
                      margin: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ================= EMPTY =================
class _OwnerEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OwnerEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
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
}

/// ================ REUSABLE INFO ROW ================
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
          child: Icon(
            icon,
            size: 16,
            color:
                label == 'Estado'
                    ? (value == 'Activa'
                        ? Colors.green
                        : value == 'Pendiente'
                        ? Colors.orange
                        : AppColors.headerBottom)
                    : AppColors.headerBottom,
          ),
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
}
