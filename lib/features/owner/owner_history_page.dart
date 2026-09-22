import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/owner/owner.dart';
import 'package:beygo/features/core/core.dart';
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
    StreamProvider.autoDispose.family<List<_HistoryRecord>, String>((
      ref,
      parkingId,
    ) {
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
  bool _sendingReport = false;

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
    final picked = await showFormattedDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      accentColor: AppColors.headerBottom,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  Future<DateTimeRange?> _pickReportDateRange() async {
    final picked = await showFormattedDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      accentColor: AppColors.headerBottom,
    );
    return picked;
  }

  Future<void> _sendHistoryReport({
    required String periodType,
    DateTimeRange? range,
  }) async {
    if (_sendingReport) return;

    setState(() => _sendingReport = true);
    _showPreparingReportDialog();

    try {
      final payload = <String, dynamic>{'periodType': periodType};

      if (periodType == 'custom' && range != null) {
        payload['startDate'] = range.start.toIso8601String();
        payload['endDate'] = range.end.toIso8601String();
      }

      final result = await FirebaseFunctions.instance
          .httpsCallable('sendOwnerHistoryReport')
          .call(payload);

      final data = Map<String, dynamic>.from(result.data as Map);
      final email = '${data['email'] ?? ''}'.trim();
      final count = (data['recordCount'] as num?)?.toInt() ?? 0;
      final periodLabel = '${data['periodLabel'] ?? 'el período'}';

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Resumen de $periodLabel enviado a $email ($count movimiento(s)).',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final message =
          e.message?.trim().isNotEmpty == true
              ? e.message!.trim()
              : 'No se pudo enviar el resumen en este momento.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el resumen: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingReport = false);
    }
  }

  void _showPreparingReportDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              decoration: BoxDecoration(
                color: dialogContext.appCardBackground,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: dialogContext.appBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: dialogContext.appIconCircleColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: dialogContext.appBrandIconColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  MyText(
                    text: 'Estamos preparando tu reporte',
                    variant: MyTextVariant.bodyBold,
                    fontSize: 17,
                    customColor: dialogContext.appTextPrimaryColor,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  MyText(
                    text:
                        'Generando resumen y PDF para enviarlo a tu correo...',
                    variant: MyTextVariant.bodyMuted,
                    fontSize: 13,
                    customColor: dialogContext.appTextSecondaryColor,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReportSheet() async {
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
                text: 'Enviar resumen',
                variant: MyTextVariant.bodyBold,
                fontSize: 16,
                customColor: ctx.appTextPrimaryColor,
              ),
              const SizedBox(height: 8),
              MyText(
                text:
                    'Te enviaremos un correo con resumen ejecutivo y PDF adjunto.',
                variant: MyTextVariant.bodyMuted,
                fontSize: 12,
                customColor: ctx.appTextSecondaryColor,
              ),
              const SizedBox(height: 14),
              _ReportOptionTile(
                icon: Icons.calendar_month_rounded,
                title: 'Este mes',
                subtitle: 'Movimientos desde el inicio del mes actual.',
                onTap: () {
                  Navigator.pop(ctx);
                  _sendHistoryReport(periodType: 'current_month');
                },
              ),
              const SizedBox(height: 10),
              _ReportOptionTile(
                icon: Icons.history_toggle_off_rounded,
                title: 'Mes anterior',
                subtitle: 'Resumen completo del mes pasado.',
                onTap: () {
                  Navigator.pop(ctx);
                  _sendHistoryReport(periodType: 'previous_month');
                },
              ),
              const SizedBox(height: 10),
              _ReportOptionTile(
                icon: Icons.date_range_rounded,
                title: 'Rango personalizado',
                subtitle: 'Elegir fechas manualmente.',
                onTap: () async {
                  Navigator.pop(ctx);
                  final range = await _pickReportDateRange();
                  if (range == null || !mounted) return;
                  await _sendHistoryReport(periodType: 'custom', range: range);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleReportAction() async {
    if (_sendingReport) return;

    final preferences = ref.read(appPreferencesProvider);
    final expectedPin = preferences.ownerRevenuePin?.trim();

    if (expectedPin == null || expectedPin.length != 4) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configura primero tu PIN de ingresos en Ajustes para enviar reportes.',
          ),
        ),
      );
      return;
    }

    final valid = await _showRevenuePinVerifyDialog(expectedPin: expectedPin);
    if (valid != true || !mounted) return;
    await _showReportSheet();
  }

  Future<bool?> _showRevenuePinVerifyDialog({
    required String expectedPin,
  }) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _HistoryRevenuePinDialog(expectedPin: expectedPin),
    );
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
                                                ? (ctx.isDarkMode
                                                    ? Colors.white
                                                    : f.color)
                                                : ctx.appTextPrimaryColor,
                                      ),
                                    ),
                                    if (selected)
                                      Icon(
                                        Icons.check_rounded,
                                        color:
                                            ctx.isDarkMode
                                                ? Colors.white
                                                : f.color,
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
                              ? (ctx.isDarkMode
                                  ? Colors.white
                                  : AppColors.headerBottom)
                              : ctx.appTextPrimaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing:
                      selected
                          ? Icon(
                            Icons.check_rounded,
                            color:
                                ctx.isDarkMode
                                    ? Colors.white
                                    : AppColors.headerBottom,
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
                              ? (ctx.isDarkMode
                                  ? Colors.white
                                  : AppColors.headerBottom)
                              : ctx.appTextPrimaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing:
                      selected
                          ? Icon(
                            Icons.check_rounded,
                            color:
                                ctx.isDarkMode
                                    ? Colors.white
                                    : AppColors.headerBottom,
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
              offset: const Offset(0, -8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Search field
                    Container(
                      decoration: BoxDecoration(
                        color: context.appCardBackground,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.appBorderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.16 : 0.03,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
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
                            color: context.appBrandIconColor.withValues(
                              alpha: 0.85,
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
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
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
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _sendingReport ? null : _handleReportAction,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: context.appBrandIconColor.withValues(
                              alpha: 0.35,
                            ),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          backgroundColor: context.appCardBackground,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        icon: Icon(
                          _sendingReport
                              ? Icons.hourglass_top_rounded
                              : Icons.outbox_rounded,
                          size: 18,
                          color: context.appBrandIconColor,
                        ),
                        label: Text(
                          _sendingReport
                              ? 'Enviando resumen...'
                              : 'Enviar resumen',
                          style: TextStyle(
                            color: context.appBrandTextColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
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

class _ReportOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.appCardBackgroundSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appIconCircleColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: context.appBrandIconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    text: title,
                    variant: MyTextVariant.bodyBold,
                    fontSize: 14,
                    customColor: context.appTextPrimaryColor,
                  ),
                  const SizedBox(height: 3),
                  MyText(
                    text: subtitle,
                    variant: MyTextVariant.bodyMuted,
                    fontSize: 12,
                    customColor: context.appTextSecondaryColor,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.appTextSecondaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRevenuePinDialog extends StatefulWidget {
  const _HistoryRevenuePinDialog({required this.expectedPin});

  final String expectedPin;

  @override
  State<_HistoryRevenuePinDialog> createState() =>
      _HistoryRevenuePinDialogState();
}

class _HistoryRevenuePinDialogState extends State<_HistoryRevenuePinDialog> {
  final _pinCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinCtrl.text.trim();
    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _error = 'Ingresa tu PIN numérico de 4 dígitos.');
      return;
    }
    if (pin != widget.expectedPin) {
      setState(() => _error = 'PIN incorrecto.');
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.8),
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: context.appCardBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.appBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: context.isDarkMode ? 0.28 : 0.10,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.headerBottom.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.headerBottom.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: context.appBrandIconColor,
                      size: 27,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Verificar PIN de ingresos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.appTextPrimaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa tu PIN para poder solicitar el reporte por correo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.appTextSecondaryColor,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _pinCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  obscureText: true,
                  maxLength: 4,
                  style: TextStyle(color: context.appTextPrimaryColor),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'PIN de 4 dígitos',
                    hintStyle: TextStyle(color: context.appTextSecondaryColor),
                    prefixIcon: Icon(
                      Icons.pin_outlined,
                      size: 18,
                      color: context.appTextSecondaryColor,
                    ),
                    filled: true,
                    fillColor: context.appInputBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: context.appBorderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: context.appBorderColor),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                      borderSide: BorderSide(
                        color: AppColors.headerBottom,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: context.appBorderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(color: context.appTextPrimaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AppColors.headerBottom,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text('Continuar'),
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
              color:
                  active
                      ? (context.isDarkMode ? Colors.white : activeColor)
                      : context.appTextSecondaryColor,
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
                  color:
                      active
                          ? (context.isDarkMode ? Colors.white : activeColor)
                          : context.appTextPrimaryColor,
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
        return penalty ? 'CANCELADA •PENALIZADA' : 'CANCELADA';
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
          child: Icon(icon, size: 14, color: context.appBrandIconColor),
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
                  color:
                      valueColor ??
                      (context.isDarkMode
                          ? const Color(0xFFF8FAFC)
                          : context.appTextPrimaryColor),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            28,
            24,
            28,
            MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                    child: Icon(
                      icon,
                      size: 32,
                      color:
                          context.isDarkMode
                              ? Colors.white
                              : AppColors.headerBottom,
                    ),
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
          ),
        );
      },
    );
  }
}
