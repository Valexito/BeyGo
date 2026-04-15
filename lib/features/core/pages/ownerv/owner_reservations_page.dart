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
              child: const SizedBox(height: 14),
            ),

            /// TABS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                elevation: 6,
                color: Colors.white,
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

            const SizedBox(height: 12),

            /// CONTENT
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  /// ACTIVES
                  allAsync.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
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
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder:
                            (_, i) => _OwnerActiveCard(reservation: active[i]),
                      );
                    },
                  ),

                  /// PENDING APPROVAL
                  allAsync.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
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
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder:
                            (_, i) =>
                                _OwnerApproveCard(reservation: pending[i]),
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

/// ================= ACTIVE =================
class _OwnerActiveCard extends ConsumerWidget {
  final Reservation reservation;

  const _OwnerActiveCard({required this.reservation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_parking, color: AppColors.headerBottom),
              const SizedBox(width: 10),
              Expanded(
                child: MyText(
                  text: reservation.parkingName,
                  variant: MyTextVariant.bodyBold,
                ),
              ),
              const Text(
                'ACTIVA',
                style: TextStyle(color: Colors.green, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.login,
            label: 'Entrada',
            value: _format(reservation.reservedAt),
          ),
          const SizedBox(height: 16),
          MyButton(
            text: 'Finalizar',
            margin: EdgeInsets.zero,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Finalizar reserva'),
                    content: const Text(
                      '¿Seguro que deseas finalizar esta reserva?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Confirmar'),
                      ),
                    ],
                  );
                },
              );

              if (confirm != true) return;

              try {
                final complete = ref.read(
                  completeReservationWithBillingProvider,
                );
                await complete(r: reservation);
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pending_actions, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: MyText(
                  text: widget.reservation.parkingName,
                  variant: MyTextVariant.bodyBold,
                ),
              ),
              const Text(
                'PENDIENTE',
                style: TextStyle(color: Colors.orange, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
          MyButton(
            text: _processing ? 'Aprobando...' : 'Aprobar',
            onTap:
                _processing
                    ? null
                    : () async {
                      setState(() => _processing = true);
                      try {
                        await approve(reservation: widget.reservation);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
