import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/components/ui/app_styles.dart';
import 'package:mapbox_api/common/components/ui/my_button.dart';
import 'package:mapbox_api/common/components/ui/my_text.dart';
import 'package:mapbox_api/features/owner/widgets/app_header.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';
import 'package:mapbox_api/features/owner/owner_home_page.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';
import 'package:mapbox_api/features/owner/widgets/owner_dialogs.dart';

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
        return MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Column(
            children: [
              const AppHeader(
                title: 'Solicitudes',
                subtitle: 'Gestiona salidas y cancelaciones',
                showBack: true,
              ),

              Transform.translate(
                offset: const Offset(0, -24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Material(
                    elevation: 12,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelPadding: EdgeInsets.zero,
                        indicator: BoxDecoration(
                          color: const Color(0xFFEAF0F7),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
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
              ),

              /// CONTENT
              Expanded(
                child: ClipRect(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      /// EXIT
                      exitAsync.when(
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
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
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 14),
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
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
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
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 14),
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
              ),
            ],
          ),
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

    // ── Duration calculation ──
    final start = widget.reservation.reservedAt;
    final end = widget.reservation.exitLockedAt ?? DateTime.now();
    final totalMinutes = end.difference(start).inMinutes.clamp(0, 9999);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final durationText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.headerTop, AppColors.headerBottom],
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: MyText(
                    text:
                        'No. ${widget.reservation.reservationNumber ?? 'N/A'}',
                    variant: MyTextVariant.bodyBold,
                    customColor: Colors.white,
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: MyText(
                    text: widget.isExit ? 'SALIDA' : 'CANCELACIÓN',
                    variant: MyTextVariant.bodyBold,
                    customColor: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // ── Info rows ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  icon: Icons.login,
                  label: 'Entrada',
                  value: _format(widget.reservation.reservedAt),
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.timelapse_rounded,
                  label: 'Duración',
                  value: durationText,
                ),
                if (widget.isExit &&
                    widget.reservation.estimatedAmount != null) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Monto a cobrar',
                    value:
                        'Q ${widget.reservation.estimatedAmount!.toDouble().toStringAsFixed(2)}',
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    width: 180,
                    child: MyButton(
                      text: _processing ? 'Procesando...' : 'Confirmar',
                      height: 42,
                      margin: EdgeInsets.zero,
                      onTap:
                          _processing
                              ? null
                              : () async {
                                final confirm =
                                    await OwnerDialogs.showConfirmationDialog(
                                      context,
                                      isExit: widget.isExit,
                                    );

                                if (confirm != true || !mounted) return;

                                setState(() => _processing = true);
                                try {
                                  if (widget.isExit) {
                                    await confirmExit(
                                      reservation: widget.reservation,
                                    );
                                  } else {
                                    await confirmCancel(
                                      reservation: widget.reservation,
                                    );
                                  }
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
