import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_button.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';

class OwnerRequestsPage extends ConsumerStatefulWidget {
  const OwnerRequestsPage({super.key});

  @override
  ConsumerState<OwnerRequestsPage> createState() => _OwnerRequestsPageState();
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
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: AppColors.headerBottom),
            const SizedBox(height: 12),
            MyText(
              text: title,
              variant: MyTextVariant.bodyBold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            MyText(
              text: subtitle,
              variant: MyTextVariant.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerRequestsPageState extends ConsumerState<OwnerRequestsPage>
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
    final exitAsync = ref.watch(ownerExitRequestsProvider);
    final cancelAsync = ref.watch(ownerCancellationRequestsProvider);

    return OwnerOnly(
      builder: (_) {
        return Column(
          children: [
            const SizedBox(height: 14),

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
                      Tab(text: 'Salidas'),
                      Tab(text: 'Cancelaciones'),
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
                  /// EXIT
                  exitAsync.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                    data: (items) {
                      if (items.isEmpty) {
                        return const _OwnerEmptyState(
                          icon: Icons.logout,
                          title: 'Sin salidas',
                          subtitle: 'No hay solicitudes de salida',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder:
                            (_, i) => _RequestCard(
                              reservation: items[i],
                              isExit: true,
                            ),
                      );
                    },
                  ),

                  /// CANCEL
                  cancelAsync.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                    data: (items) {
                      if (items.isEmpty) {
                        return const _OwnerEmptyState(
                          icon: Icons.cancel,
                          title: 'Sin cancelaciones',
                          subtitle: 'No hay solicitudes',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder:
                            (_, i) => _RequestCard(
                              reservation: items[i],
                              isExit: false,
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

/// ================= CARD =================
class _RequestCard extends ConsumerStatefulWidget {
  final Reservation reservation;
  final bool isExit;

  const _RequestCard({required this.reservation, required this.isExit});

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final confirmExit = ref.read(ownerConfirmExitProvider);
    final confirmCancel = ref.read(ownerConfirmCancellationProvider);

    final accent =
        widget.isExit ? const Color(0xFF0EA5E9) : const Color(0xFFF59E0B);

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
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isExit ? Icons.logout : Icons.cancel,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: widget.reservation.parkingName,
                      variant: MyTextVariant.bodyBold,
                    ),
                    const SizedBox(height: 4),
                    MyText(
                      text:
                          widget.isExit
                              ? 'Solicitud de salida'
                              : 'Solicitud de cancelación',
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
          const SizedBox(height: 10),

          _InfoRow(
            icon: Icons.payments_outlined,
            label: 'Precio',
            value:
                widget.reservation.pricePerHour != null
                    ? 'Q ${widget.reservation.pricePerHour}'
                    : 'Pendiente',
          ),
          const SizedBox(height: 10),

          _InfoRow(
            icon: Icons.login,
            label: 'Entrada',
            value: _format(widget.reservation.reservedAt),
          ),
          if (widget.isExit && widget.reservation.estimatedAmount != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.receipt_long_outlined,
              label: 'Monto a cobrar',
              value: 'Q ${widget.reservation.estimatedAmount}',
            ),
          ],

          const SizedBox(height: 16),

          MyButton(
            text: _processing ? 'Procesando...' : 'Confirmar',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: Text(
                      widget.isExit
                          ? 'Confirmar salida'
                          : 'Confirmar cancelación',
                    ),
                    content: Text(
                      widget.isExit
                          ? '¿Seguro que deseas aprobar esta salida?'
                          : '¿Seguro que deseas aprobar esta cancelación?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Confirmar'),
                      ),
                    ],
                  );
                },
              );

              if (confirm != true) return;

              setState(() => _processing = true);
              try {
                if (widget.isExit) {
                  await confirmExit(reservation: widget.reservation);
                } else {
                  await confirmCancel(reservation: widget.reservation);
                }
              } finally {
                if (mounted) {
                  setState(() => _processing = false);
                }
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
