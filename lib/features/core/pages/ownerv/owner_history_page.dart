import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/features/core/pages/ownerv/widgets/app_header.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';

class OwnerHistoryPage extends ConsumerWidget {
  const OwnerHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(ownerAllReservationsProvider);

    return OwnerOnly(
      builder: (_) {
        return Column(
          children: [
            const AppHeader(
              title: 'Historial',
              subtitle: 'Reservas completadas y canceladas',
              showBack: true,
            ),

            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Material(
                  elevation: 8,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    child: MyText(
                      text: 'Historial',
                      variant: MyTextVariant.bodyBold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: reservationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
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
                      title: 'No hay historial',
                      subtitle: 'Las reservas completadas aparecerán aquí',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder:
                        (_, i) => _OwnerHistoryCard(reservation: history[i]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// ================= CARD =================
class _OwnerHistoryCard extends StatelessWidget {
  final Reservation reservation;

  const _OwnerHistoryCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(reservation.state);

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

/// ================= INFO ROW =================
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
