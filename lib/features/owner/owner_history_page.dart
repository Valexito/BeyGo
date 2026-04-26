import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/owner/providers/dashboard_providers.dart';
import 'package:beygo/features/owner/widgets/app_header.dart';
import 'package:beygo/features/core/roles/role_utils.dart';
import 'package:beygo/features/reservations/reservations.dart';
// ─── Filter options ───────────────────────────────────────────────────────────
enum _StateFilter {
  all,
  completed,
  cancelled,
  cancelledPenalty,
  cancellationRequested,
  manual,
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
      case _StateFilter.manual:
        return 'Presenciales';
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
      case _StateFilter.manual:
        return const Color(0xFF16A34A);
    }
  }
}

enum _SourceFilter { all, online, manual }

extension _SourceFilterLabel on _SourceFilter {
  String get label {
    switch (this) {
      case _SourceFilter.all:
        return 'Todas';
      case _SourceFilter.online:
        return 'En línea';
      case _SourceFilter.manual:
        return 'Presencial';
    }
  }
}

enum _PeriodFilter { week, month, all, custom }

extension _PeriodFilterLabel on _PeriodFilter {
  String get label {
    switch (this) {
      case _PeriodFilter.week:
        return 'Esta semana';
      case _PeriodFilter.month:
        return 'Este mes';
      case _PeriodFilter.all:
        return 'Todo';
      case _PeriodFilter.custom:
        return 'Rango';
    }
  }
}

class _HistoryRecord {
  final String id;
  final bool isManual;
  final String reservationNumber;
  final String customerName;
  final String plate;
  final int spaceNumber;
  final DateTime reservedAt;
  final DateTime? endedAt;
  final String state;
  final bool cancellationPenaltyApplied;
  final String? cancellationReason;
  final double? amount;
  final String? parkingName;

  const _HistoryRecord({
    required this.id,
    required this.isManual,
    required this.reservationNumber,
    required this.customerName,
    required this.plate,
    required this.spaceNumber,
    required this.reservedAt,
    required this.endedAt,
    required this.state,
    required this.cancellationPenaltyApplied,
    required this.cancellationReason,
    required this.amount,
    this.parkingName,
  });

  factory _HistoryRecord.fromReservation(Reservation r) {
    return _HistoryRecord(
      id: r.id,
      isManual: false,
      reservationNumber: r.reservationNumber ?? 'N/A',
      customerName: r.userName ?? 'N/A',
      plate: r.plate ?? 'N/A',
      spaceNumber: r.spaceNumber,
      reservedAt: r.reservedAt,
      endedAt: r.endedAt ?? r.exitApprovedAt,
      state: r.state,
      cancellationPenaltyApplied: r.cancellationPenaltyApplied,
      cancellationReason: r.cancellationReason,
      amount: (r.amount ?? r.estimatedAmount)?.toDouble(),
      parkingName: r.parkingName,
    );
  }

  factory _HistoryRecord.fromWalkInDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final enteredAt =
        (data['enteredAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final exitAt = (data['exitAt'] as Timestamp?)?.toDate();
    return _HistoryRecord(
      id: doc.id,
      isManual: true,
      reservationNumber:
          data['reservationNumber'] as String? ?? 'MAN-SIN-NUMERO',
      customerName: data['customerName'] as String? ?? 'Cliente',
      plate: data['plate'] as String? ?? 'N/A',
      spaceNumber: (data['spaceNumber'] as num?)?.toInt() ?? 0,
      reservedAt: enteredAt,
      endedAt: exitAt,
      state: 'manual_completed',
      cancellationPenaltyApplied: false,
      cancellationReason: null,
      amount: (data['amount'] as num?)?.toDouble(),
    );
  }
}

final ownerWalkInHistoryProvider =
    StreamProvider.family<List<_HistoryRecord>, String>((ref, parkingId) {
      return FirebaseFirestore.instance
          .collection('parkings')
          .doc(parkingId)
          .collection('walk_ins')
          .where('status', isEqualTo: 'completed')
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map(_HistoryRecord.fromWalkInDoc).toList()
                  ..sort((a, b) => b.reservedAt.compareTo(a.reservedAt)),
          );
    });

class OwnerHistoryPage extends ConsumerStatefulWidget {
  const OwnerHistoryPage({super.key});

  @override
  ConsumerState<OwnerHistoryPage> createState() => _OwnerHistoryPageState();
}

class _OwnerHistoryPageState extends ConsumerState<OwnerHistoryPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _StateFilter _stateFilter = _StateFilter.all;
  _SourceFilter _sourceFilter = _SourceFilter.all;
  _PeriodFilter _periodFilter = _PeriodFilter.week;
  DateTimeRange? _dateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_HistoryRecord> _applyFilters(List<_HistoryRecord> all) {
    var items = [...all];

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
              case _StateFilter.manual:
                return r.isManual;
              default:
                return true;
            }
          }).toList();
    }

    if (_sourceFilter != _SourceFilter.all) {
      items =
          items.where((r) {
            switch (_sourceFilter) {
              case _SourceFilter.online:
                return !r.isManual;
              case _SourceFilter.manual:
                return r.isManual;
              case _SourceFilter.all:
                return true;
            }
          }).toList();
    }

    final now = DateTime.now();
    final startOfWeek = _startOfWeek(now);
    final startOfMonth = DateTime(now.year, now.month, 1);

    if (_periodFilter == _PeriodFilter.week) {
      items = items.where((r) => !r.reservedAt.isBefore(startOfWeek)).toList();
    } else if (_periodFilter == _PeriodFilter.month) {
      items = items.where((r) => !r.reservedAt.isBefore(startOfMonth)).toList();
    }

    // Date range filter
    if (_periodFilter == _PeriodFilter.custom && _dateRange != null) {
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
            return r.reservationNumber.toLowerCase().contains(q) ||
                r.customerName.toLowerCase().contains(q) ||
                r.plate.toLowerCase().contains(q) ||
                (r.parkingName ?? '').toLowerCase().contains(q);
          }).toList();
    }

    // Sort by most recent
    items.sort((a, b) => b.reservedAt.compareTo(a.reservedAt));
    return items;
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  String _weekLabel(DateTime weekStart) {
    final end = weekStart.add(const Duration(days: 6));
    final nowWeek = _startOfWeek(DateTime.now());
    if (weekStart == nowWeek) return 'Esta semana';
    return '${_formatDate(weekStart)} – ${_formatDate(end)}';
  }

  Map<DateTime, List<_HistoryRecord>> _groupByWeek(List<_HistoryRecord> items) {
    final grouped = <DateTime, List<_HistoryRecord>>{};
    for (final item in items) {
      final weekStart = _startOfWeek(item.reservedAt);
      grouped.putIfAbsent(weekStart, () => []).add(item);
    }
    final orderedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final key in orderedKeys) key: grouped[key]!};
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (ctx, child) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: (isDark
                    ? const ColorScheme.dark()
                    : const ColorScheme.light())
                .copyWith(
                  primary: AppColors.headerBottom,
                  onPrimary: Colors.white,
                  surface: isDark ? const Color(0xFF111827) : Colors.white,
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
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.72,
            ),
            decoration: BoxDecoration(
              color: ctx.appCardBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.appBorderColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                MyText(
                  text: 'Filtrar por estado',
                  variant: MyTextVariant.bodyBold,
                  fontSize: 16,
                  customColor: ctx.appTextPrimaryColor,
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children:
                          _StateFilter.values.map((f) {
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
                                          ? f.color.withValues(alpha: 0.10)
                                          : ctx.appCardBackgroundSoft,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color:
                                        selected
                                            ? f.color.withValues(alpha: 0.35)
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
                                            selected
                                                ? f.color
                                                : ctx.appTextPrimaryColor,
                                      ),
                                    ),
                                    if (selected)
                                      Icon(
                                        Icons.check_rounded,
                                        color: f.color,
                                        size: 18,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSourceFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.appCardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.appBorderColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              MyText(
                text: 'Filtrar por origen',
                variant: MyTextVariant.bodyBold,
                fontSize: 16,
                customColor: ctx.appTextPrimaryColor,
              ),
              const SizedBox(height: 14),
              ..._SourceFilter.values.map((filter) {
                final selected = _sourceFilter == filter;
                return ListTile(
                  onTap: () {
                    setState(() => _sourceFilter = filter);
                    Navigator.pop(ctx);
                  },
                  tileColor:
                      selected
                          ? AppColors.headerBottom.withValues(alpha: 0.10)
                          : ctx.appCardBackgroundSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: Text(
                    filter.label,
                    style: TextStyle(
                      color:
                          selected
                              ? AppColors.headerBottom
                              : ctx.appTextPrimaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing:
                      selected
                          ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.headerBottom,
                          )
                          : null,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPeriodFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.appCardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.appBorderColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              MyText(
                text: 'Filtrar por periodo',
                variant: MyTextVariant.bodyBold,
                fontSize: 16,
                customColor: ctx.appTextPrimaryColor,
              ),
              const SizedBox(height: 14),
              ..._PeriodFilter.values.map((filter) {
                final selected = _periodFilter == filter;
                return ListTile(
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (filter == _PeriodFilter.custom) {
                      setState(() => _periodFilter = filter);
                      await _pickDateRange();
                      return;
                    }
                    setState(() {
                      _periodFilter = filter;
                      if (filter != _PeriodFilter.custom) {
                        _dateRange = null;
                      }
                    });
                  },
                  tileColor:
                      selected
                          ? AppColors.headerBottom.withValues(alpha: 0.10)
                          : ctx.appCardBackgroundSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  title: Text(
                    filter.label,
                    style: TextStyle(
                      color:
                          selected
                              ? AppColors.headerBottom
                              : ctx.appTextPrimaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing:
                      selected
                          ? const Icon(
                            Icons.check_rounded,
                            color: AppColors.headerBottom,
                          )
                          : null,
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
    final parkingAsync = ref.watch(ownerParkingProvider);
    final hasActiveFilters =
        _stateFilter != _StateFilter.all ||
        _sourceFilter != _SourceFilter.all ||
        _periodFilter != _PeriodFilter.week ||
        _dateRange != null ||
        _searchQuery.isNotEmpty;
    final isDark = context.isDarkMode;

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
                        color: context.appCardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.appBorderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.18 : 0.10,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: TextStyle(
                          fontSize: 14,
                          color: context.appTextPrimaryColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar por No., usuario, placa...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: context.appTextSecondaryColor,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: AppColors.headerBottom.withValues(
                              alpha: 0.6,
                            ),
                            size: 20,
                          ),
                          suffixIcon:
                              _searchQuery.isNotEmpty
                                  ? IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: context.appTextSecondaryColor,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                  : null,
                          filled: true,
                          fillColor: context.appCardBackground,
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

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
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
                          _FilterChip(
                            icon: Icons.category_outlined,
                            label:
                                _sourceFilter == _SourceFilter.all
                                    ? 'Origen'
                                    : _sourceFilter.label,
                            active: _sourceFilter != _SourceFilter.all,
                            activeColor: AppColors.headerBottom,
                            onTap: _showSourceFilterSheet,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            icon: Icons.calendar_today_rounded,
                            label:
                                _periodFilter == _PeriodFilter.custom &&
                                        _dateRange != null
                                    ? '${_formatDate(_dateRange!.start)} – ${_formatDate(_dateRange!.end)}'
                                    : _periodFilter.label,
                            active:
                                _periodFilter != _PeriodFilter.week ||
                                _dateRange != null,
                            activeColor: AppColors.headerBottom,
                            onTap: _showPeriodFilterSheet,
                          ),
                          if (hasActiveFilters) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _stateFilter = _StateFilter.all;
                                  _sourceFilter = _SourceFilter.all;
                                  _periodFilter = _PeriodFilter.week;
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
                                  ).withValues(alpha: 0.08),
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── List ──
            Expanded(
              child: parkingAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (parking) {
                  final walkInsAsync =
                      parking == null
                          ? const AsyncValue.data(<_HistoryRecord>[])
                          : ref.watch(ownerWalkInHistoryProvider(parking.id));

                  return reservationsAsync.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (allReservations) {
                      return walkInsAsync.when(
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (walkIns) {
                          final onlineHistory =
                              allReservations
                                  .where(
                                    (r) =>
                                        r.state == 'completed' ||
                                        r.state == 'cancelled' ||
                                        r.state == 'cancellation_requested',
                                  )
                                  .map(_HistoryRecord.fromReservation)
                                  .toList();

                          final items = _applyFilters([
                            ...onlineHistory,
                            ...walkIns,
                          ]);

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
                                      : 'Las reservas recientes de esta semana aparecerán aquí',
                            );
                          }

                          final grouped = _groupByWeek(items);
                          final children = <Widget>[];

                          grouped.forEach((weekStart, records) {
                            children.add(
                              Padding(
                                padding: EdgeInsets.only(
                                  top: children.isEmpty ? 0 : 8,
                                  bottom: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.date_range_rounded,
                                      size: 15,
                                      color: AppColors.headerBottom,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: MyText(
                                        text: _weekLabel(weekStart),
                                        variant: MyTextVariant.bodyBold,
                                        fontSize: 14,
                                        customColor:
                                            context.appTextPrimaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );

                            for (final record in records) {
                              children.add(
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _OwnerHistoryCard(record: record),
                                ),
                              );
                            }
                          });

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            children: children,
                          );
                        },
                      );
                    },
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
          color:
              active
                  ? activeColor.withValues(alpha: 0.10)
                  : context.appCardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                active
                    ? activeColor.withValues(alpha: 0.40)
                    : context.appBorderColor,
            width: 1.4,
          ),
          boxShadow:
              active
                  ? []
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: context.isDarkMode ? 0.14 : 0.04,
                      ),
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
              color: active ? activeColor : context.appTextSecondaryColor,
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
                  color: active ? activeColor : context.appTextPrimaryColor,
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
  final _HistoryRecord record;

  const _OwnerHistoryCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final stateColor = _statusColor(record.state);
    final stateLabel = _statusLabel(
      record.state,
      record.cancellationPenaltyApplied,
    );
    final stateIcon = _statusIcon(record.state);

    final start = record.reservedAt;
    final end = record.endedAt ?? start;
    final totalMinutes = end.difference(start).inMinutes.clamp(0, 9999);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final durationText =
        totalMinutes == 0
            ? '—'
            : hours > 0
            ? '${hours}h ${minutes}m'
            : '${minutes}m';

    final amountText =
        record.amount != null ? 'Q ${record.amount!.toStringAsFixed(2)}' : '—';

    return Container(
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.18 : 0.05,
            ),
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
                    text: 'No. ${record.reservationNumber}',
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
                    color: stateColor.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30),
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
                        value: record.customerName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniInfo(
                        icon: Icons.directions_car_outlined,
                        label: 'Placa',
                        value: record.plate,
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
                        value: '${record.spaceNumber}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniInfo(
                        icon: Icons.access_time_rounded,
                        label: 'Inicio',
                        value: _format(record.reservedAt),
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
                            record.state == 'completed' ||
                                    record.state == 'manual_completed'
                                ? const Color(0xFF2563EB)
                                : null,
                      ),
                    ),
                  ],
                ),
                if ((record.cancellationReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: stateColor.withValues(alpha: 0.15),
                      ),
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
                            record.cancellationReason!,
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
      case 'manual_completed':
        return const Color(0xFF16A34A);
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
      case 'manual_completed':
        return 'PRESENCIAL';
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
      case 'manual_completed':
        return Icons.directions_car_filled_rounded;
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
          decoration: BoxDecoration(
            color: context.appIconCircleColor,
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
                style: TextStyle(
                  fontSize: 10,
                  color: context.appTextSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? context.appTextPrimaryColor,
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
                color: context.appCardBackground,
                shape: BoxShape.circle,
                border: Border.all(color: context.appBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: context.isDarkMode ? 0.18 : 0.08,
                    ),
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
