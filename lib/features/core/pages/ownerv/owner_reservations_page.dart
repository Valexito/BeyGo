import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_button.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';

class OwnerReservationsPage extends ConsumerStatefulWidget {
  final bool showOnlyHistory;

  const OwnerReservationsPage({super.key, this.showOnlyHistory = false});

  @override
  ConsumerState<OwnerReservationsPage> createState() =>
      _OwnerReservationsPageState();
}

class _OwnerReservationsPageState extends ConsumerState<OwnerReservationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: widget.showOnlyHistory ? 1 : 2,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OwnerOnly(
      builder: (_) {
        if (widget.showOnlyHistory) {
          final reservationsAsync = ref.watch(ownerAllReservationsProvider);

          return reservationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: MyText(
                      text: 'Error cargando reservas: $e',
                      variant: MyTextVariant.bodyBold,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            data: (items) {
              final history =
                  items.where((r) {
                    return r.state == 'completed' ||
                        r.state == 'cancelled' ||
                        r.state == 'cancellation_requested';
                  }).toList();

              if (history.isEmpty) {
                return const _OwnerEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No hay reservas registradas',
                  subtitle: 'Las reservas de tus parqueos aparecerán aquí.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder:
                    (_, i) =>
                        _OwnerReservationHistoryCard(reservation: history[i]),
              );
            },
          );
        }

        final exitAsync = ref.watch(ownerExitRequestsProvider);
        final cancelAsync = ref.watch(ownerCancellationRequestsProvider);

        return Column(
          children: [
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                elevation: 6,
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                shadowColor: AppColors.headerBottom.withOpacity(0.10),
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelPadding: EdgeInsets.zero,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: const Color(0xFFEAF0F7),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.headerBottom,
                    unselectedLabelColor: Colors.black54,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Salidas'),
                      Tab(text: 'Cancelaciones'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  exitAsync.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error:
                        (e, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: MyText(
                              text: 'Error cargando solicitudes: $e',
                              variant: MyTextVariant.bodyBold,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    data: (items) {
                      if (items.isEmpty) {
                        return const _OwnerEmptyState(
                          icon: Icons.logout_rounded,
                          title: 'No hay salidas pendientes',
                          subtitle:
                              'Las solicitudes de salida aparecerán aquí.',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder:
                            (_, i) => _OwnerActionCard(
                              reservation: items[i],
                              requestType: _OwnerRequestType.exit,
                            ),
                      );
                    },
                  ),
                  cancelAsync.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error:
                        (e, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: MyText(
                              text: 'Error cargando solicitudes: $e',
                              variant: MyTextVariant.bodyBold,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    data: (items) {
                      if (items.isEmpty) {
                        return const _OwnerEmptyState(
                          icon: Icons.cancel_outlined,
                          title: 'No hay cancelaciones pendientes',
                          subtitle:
                              'Las solicitudes de cancelación aparecerán aquí.',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder:
                            (_, i) => _OwnerActionCard(
                              reservation: items[i],
                              requestType: _OwnerRequestType.cancellation,
                            ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _OwnerRequestType { exit, cancellation }

class _OwnerActionCard extends ConsumerStatefulWidget {
  final Reservation reservation;
  final _OwnerRequestType requestType;

  const _OwnerActionCard({
    required this.reservation,
    required this.requestType,
  });

  @override
  ConsumerState<_OwnerActionCard> createState() => _OwnerActionCardState();
}

class _OwnerActionCardState extends ConsumerState<_OwnerActionCard> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final confirmExit = ref.read(ownerConfirmExitProvider);
    final confirmCancellation = ref.read(ownerConfirmCancellationProvider);

    final isExit = widget.requestType == _OwnerRequestType.exit;
    final title = isExit ? 'Solicitud de salida' : 'Solicitud de cancelación';
    final icon = isExit ? Icons.logout_rounded : Icons.cancel_schedule_send;
    final accent = isExit ? const Color(0xFF0EA5E9) : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: widget.reservation.parkingName,
                      variant: MyTextVariant.bodyBold,
                      fontSize: 15,
                    ),
                    const SizedBox(height: 4),
                    MyText(
                      text: title,
                      variant: MyTextVariant.bodyMuted,
                      fontSize: 12,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'PENDIENTE',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _OwnerInfoRow(
            icon: Icons.local_parking_outlined,
            label: 'Espacio',
            value: '${widget.reservation.spaceNumber}',
          ),
          const SizedBox(height: 10),
          _OwnerInfoRow(
            icon: Icons.access_time_rounded,
            label: 'Inicio',
            value: _formatDateTime(widget.reservation.reservedAt),
          ),
          const SizedBox(height: 10),
          _OwnerInfoRow(
            icon: Icons.payments_outlined,
            label: 'Tarifa',
            value:
                widget.reservation.pricePerHour != null
                    ? 'Q ${widget.reservation.pricePerHour}/hora'
                    : 'Pendiente',
          ),
          const SizedBox(height: 16),
          MyButton(
            text: _processing ? 'Confirmando...' : 'Confirmar',
            onTap:
                _processing
                    ? null
                    : () async {
                      setState(() => _processing = true);
                      try {
                        if (isExit) {
                          await confirmExit(reservation: widget.reservation);
                        } else {
                          await confirmCancellation(
                            reservation: widget.reservation,
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      } finally {
                        if (mounted) {
                          setState(() => _processing = false);
                        }
                      }
                    },
            margin: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }
}

class _OwnerReservationHistoryCard extends StatelessWidget {
  final Reservation reservation;

  const _OwnerReservationHistoryCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(reservation.state);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.iconCircle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_parking_rounded,
                  color: AppColors.headerBottom,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MyText(
                  text: reservation.parkingName,
                  variant: MyTextVariant.bodyBold,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  reservation.state.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _OwnerInfoRow(
            icon: Icons.local_parking_outlined,
            label: 'Espacio',
            value: '${reservation.spaceNumber}',
          ),
        ],
      ),
    );
  }

  Color _statusColor(String state) {
    switch (state) {
      case 'completed':
        return const Color(0xFF2563EB);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'cancellation_requested':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF16A34A);
    }
  }
}

class _OwnerInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _OwnerInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
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
        MyText(text: value, variant: MyTextVariant.bodyBold, fontSize: 13),
      ],
    );
  }
}

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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
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
            MyText(
              text: title,
              variant: MyTextVariant.bodyBold,
              fontSize: 17,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            MyText(
              text: subtitle,
              variant: MyTextVariant.bodyMuted,
              fontSize: 14,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
