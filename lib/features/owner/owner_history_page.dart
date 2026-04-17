import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/components/ui/app_styles.dart';
import 'package:mapbox_api/common/components/ui/my_text.dart';
import 'package:mapbox_api/features/owner/widgets/app_header.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';

// ─── Filter options ───────────────────────────────────────────────────────────
enum _StateFilter {
  all,
  completed,
  cancelled,
  cancelledPenalty,
  cancellationRequested,
}

extension _StateFilterLabel on _StateFilter {
  String get label {
    switch (this) {
      case _StateFilter.all:
        return 'Todos';
      case _StateFilter.completed:
        return 'Completadas';
      case _StateFilter.cancelled:
        return 'Canceladas';
      case _StateFilter.cancelledPenalty:
        return 'Canceladas c/ penalización';
      case _StateFilter.cancellationRequested:
        return 'Solicitud cancelación';
    }
  }

  Color get color {
    switch (this) {
      case _StateFilter.all:
        return AppColors.headerBottom;
      case _StateFilter.completed:
        return const Color(0xFF2563EB);
      case _StateFilter.cancelled:
        return const Color(0xFFDC2626);
      case _StateFilter.cancelledPenalty:
        return const Color(0xFF7C3AED);
      case _StateFilter.cancellationRequested:
        return const Color(0xFFF59E0B);
    }
  }
}

class OwnerHistoryPage extends ConsumerStatefulWidget {
  const OwnerHistoryPage({super.key});

  @override
  ConsumerState<OwnerHistoryPage> createState() => _OwnerHistoryPageState();
}

class _OwnerHistoryPageState extends ConsumerState<OwnerHistoryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _StateFilter _stateFilter = _StateFilter.all;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Reservation> _applyFilters(List<Reservation> all) {
    var items =
        all.where((r) {
          return r.state == 'completed' ||
              r.state == 'cancelled' ||
              r.state == 'cancellation_requested';
        }).toList();

    // State filter
    if (_stateFilter != _StateFilter.all) {
      items =
          items.where((r) {
            switch (_stateFilter) {
              case _StateFilter.completed:
                return r.state == 'completed';
              case _StateFilter.cancelled:
                return r.state == 'cancelled' && !r.cancellationPenaltyApplied;
              case _StateFilter.cancelledPenalty:
                return r.state == 'cancelled' && r.cancellationPenaltyApplied;
              case _StateFilter.cancellationRequested:
                return r.state == 'cancellation_requested';
              default:
                return true;
            }
          }).toList();
    }

    // Date range filter
    if (_dateRange != null) {
      items =
          items.where((r) {
            final d = r.reservedAt;
            return !d.isBefore(_dateRange!.start) &&
                !d.isAfter(_dateRange!.end.add(const Duration(days: 1)));
          }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items =
          items.where((r) {
            return (r.reservationNumber ?? '').toLowerCase().contains(q) ||
                (r.userName ?? '').toLowerCase().contains(q) ||
                (r.plate ?? '').toLowerCase().contains(q) ||
                r.parkingName.toLowerCase().contains(q);
          }).toList();
    }

    // Sort by most recent
    items.sort((a, b) => b.reservedAt.compareTo(a.reservedAt));
    return items;
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.headerBottom,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  void _showStateFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const MyText(
                text: 'Filtrar por estado',
                variant: MyTextVariant.bodyBold,
                fontSize: 16,
              ),
              const SizedBox(height: 14),
              ..._StateFilter.values.map((f) {
                final selected = _stateFilter == f;
                return GestureDetector(
                  onTap: () {
                    setState(() => _stateFilter = f);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? f.color.withOpacity(0.10)
                              : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            selected
                                ? f.color.withOpacity(0.35)
                                : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: f.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MyText(
                            text: f.label,
                            variant: MyTextVariant.bodyBold,
                            fontSize: 14,
                            customColor:
                                selected ? f.color : const Color(0xFF3D4554),
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_rounded, color: f.color, size: 18),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(ownerAllReservationsProvider);
    final hasActiveFilters =
        _stateFilter != _StateFilter.all ||
        _dateRange != null ||
        _searchQuery.isNotEmpty;

    return OwnerOnly(
      builder: (_) {
        return Column(
          children: [
            const AppHeader(
              title: 'Historial',
              subtitle: 'Reservas completadas y canceladas',
              showBack: true,
            ),

            // ── Search + Filter bar ──
            Transform.translate(
              offset: const Offset(0, -20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Search field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.headerBottom.withOpacity(0.10),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF3D4554),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar por No., usuario, placa...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: AppColors.headerBottom.withOpacity(0.6),
                            size: 20,
                          ),
                          suffixIcon:
                              _searchQuery.isNotEmpty
                                  ? IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: Colors.grey.shade400,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                  : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Filter chips row
                    Row(
                      children: [
                        // State filter
                        _FilterChip(
                          icon: Icons.tune_rounded,
                          label:
                              _stateFilter == _StateFilter.all
                                  ? 'Estado'
                                  : _stateFilter.label,
                          active: _stateFilter != _StateFilter.all,
                          activeColor: _stateFilter.color,
                          onTap: _showStateFilterSheet,
                        ),
                        const SizedBox(width: 8),

                        // Date range filter
                        _FilterChip(
                          icon: Icons.calendar_today_rounded,
                          label:
                              _dateRange == null
                                  ? 'Fecha'
                                  : '${_formatDate(_dateRange!.start)} – ${_formatDate(_dateRange!.end)}',
                          active: _dateRange != null,
                          activeColor: AppColors.headerBottom,
                          onTap: _pickDateRange,
                        ),

                        const Spacer(),

                        // Clear all
                        if (hasActiveFilters)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _stateFilter = _StateFilter.all;
                                _dateRange = null;
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFDC2626,
                                ).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const MyText(
                                text: 'Limpiar',
                                variant: MyTextVariant.bodyBold,
                                fontSize: 12,
                                customColor: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── List ──
            Expanded(
              child: reservationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (all) {
                  final items = _applyFilters(all);

                  if (items.isEmpty) {
                    return _OwnerEmptyState(
                      icon:
                          hasActiveFilters
                              ? Icons.filter_list_off_rounded
                              : Icons.receipt_long_outlined,
                      title:
                          hasActiveFilters
                              ? 'Sin resultados'
                              : 'No hay historial',
                      subtitle:
                          hasActiveFilters
                              ? 'Prueba con otros filtros o términos de búsqueda'
                              : 'Las reservas completadas aparecerán aquí',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder:
                        (_, i) => _OwnerHistoryCard(reservation: items[i]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

// ─── Filter chip widget ────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                active ? activeColor.withOpacity(0.40) : Colors.grey.shade200,
            width: 1.4,
          ),
          boxShadow:
              active
                  ? []
                  : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? activeColor : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? activeColor : const Color(0xFF5A6478),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── History card ──────────────────────────────────────────────────────────────
class _OwnerHistoryCard extends StatelessWidget {
  final Reservation reservation;

  const _OwnerHistoryCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final stateColor = _statusColor(reservation.state);
    final stateLabel = _statusLabel(
      reservation.state,
      reservation.cancellationPenaltyApplied,
    );
    final stateIcon = _statusIcon(reservation.state);

    // Duration
    final start = reservation.reservedAt;
    final end = reservation.endedAt ?? reservation.exitApprovedAt ?? start;
    final totalMinutes = end.difference(start).inMinutes.clamp(0, 9999);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final durationText =
        totalMinutes == 0
            ? '—'
            : hours > 0
            ? '${hours}h ${minutes}m'
            : '${minutes}m';

    // Amount
    final amount = reservation.amount ?? reservation.estimatedAmount;
    final amountText =
        amount != null ? 'Q ${amount.toDouble().toStringAsFixed(2)}' : '—';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Gradient header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
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
                    text: 'No. ${reservation.reservationNumber ?? 'N/A'}',
                    variant: MyTextVariant.bodyBold,
                    customColor: Colors.white,
                    fontSize: 13,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: stateColor.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.30),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(stateIcon, size: 11, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        stateLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Info rows ──
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MiniInfo(
                        icon: Icons.person_outline,
                        label: 'Usuario',
                        value: reservation.userName ?? 'N/A',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniInfo(
                        icon: Icons.directions_car_outlined,
                        label: 'Placa',
                        value: reservation.plate ?? 'N/A',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MiniInfo(
                        icon: Icons.local_parking_outlined,
                        label: 'Espacio',
                        value: '${reservation.spaceNumber}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniInfo(
                        icon: Icons.access_time_rounded,
                        label: 'Inicio',
                        value: _format(reservation.reservedAt),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MiniInfo(
                        icon: Icons.timelapse_rounded,
                        label: 'Duración',
                        value: durationText,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniInfo(
                        icon: Icons.receipt_long_outlined,
                        label: 'Monto',
                        value: amountText,
                        valueColor:
                            reservation.state == 'completed'
                                ? const Color(0xFF2563EB)
                                : null,
                      ),
                    ),
                  ],
                ),
                // Cancellation reason if present
                if ((reservation.cancellationReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: stateColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: stateColor.withOpacity(0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: stateColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reservation.cancellationReason!,
                            style: TextStyle(
                              fontSize: 11,
                              color: stateColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
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

  String _statusLabel(String state, bool penalty) {
    switch (state) {
      case 'completed':
        return 'COMPLETADA';
      case 'cancelled':
        return penalty ? 'CANCELADA •STRIKE' : 'CANCELADA';
      case 'cancellation_requested':
        return 'SOLICITUD CANCEL.';
      default:
        return state.toUpperCase();
    }
  }

  IconData _statusIcon(String state) {
    switch (state) {
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'cancellation_requested':
        return Icons.hourglass_top_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  String _format(DateTime v) {
    final d = v.day.toString().padLeft(2, '0');
    final m = v.month.toString().padLeft(2, '0');
    final h = v.hour.toString().padLeft(2, '0');
    final min = v.minute.toString().padLeft(2, '0');
    return '$d/$m $h:$min';
  }
}

// ─── Mini info cell (2-column grid layout) ────────────────────────────────────
class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _MiniInfo({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppColors.iconCircle,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: AppColors.headerBottom),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF8A94A6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────────
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
              width: 80,
              height: 80,
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
              child: Icon(icon, size: 32, color: AppColors.headerBottom),
            ),
            const SizedBox(height: 16),
            MyText(
              text: title,
              variant: MyTextVariant.bodyBold,
              fontSize: 16,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            MyText(
              text: subtitle,
              variant: MyTextVariant.bodyMuted,
              fontSize: 13,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
