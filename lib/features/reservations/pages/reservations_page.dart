import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/reservations/reservations.dart';

enum _ReservationsPeriodFilter { week, month, all, custom }

extension _ReservationsPeriodFilterLabel on _ReservationsPeriodFilter {
  String get label {
    switch (this) {
      case _ReservationsPeriodFilter.week:
        return 'Esta semana';
      case _ReservationsPeriodFilter.month:
        return 'Este mes';
      case _ReservationsPeriodFilter.all:
        return 'Todo';
      case _ReservationsPeriodFilter.custom:
        return 'Rango';
    }
  }
}

class ReservationsPage extends ConsumerStatefulWidget {
  final String? initialReservationId;

  const ReservationsPage({super.key, this.initialReservationId});

  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends ConsumerState<ReservationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);
  final Set<String> _ratingPromptInFlight = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  _ReservationsPeriodFilter _periodFilter = _ReservationsPeriodFilter.week;
  DateTimeRange? _dateRange;
  bool _handledInitialReservation = false;
  bool _searchHasFocus = false;

  bool get _isActiveTab => _tab.index == 0;

  @override
  void initState() {
    super.initState();
    _tab.addListener(() {
      if (!_tab.indexIsChanging) return;
      FocusManager.instance.primaryFocus?.unfocus();
      if (mounted) setState(() {});
    });
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      setState(() => _searchHasFocus = _searchFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
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

    if (picked != null) {
      setState(() {
        _periodFilter = _ReservationsPeriodFilter.custom;
        _dateRange = picked;
      });
    }
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
              ..._ReservationsPeriodFilter.values.map((filter) {
                final selected = _periodFilter == filter;
                return ListTile(
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (filter == _ReservationsPeriodFilter.custom) {
                      await _pickDateRange();
                      return;
                    }
                    setState(() {
                      _periodFilter = filter;
                      _dateRange = null;
                    });
                  },
                  tileColor:
                      selected
                          ? (ctx.isDarkMode
                              ? ctx.appBrandIconColor.withValues(alpha: 0.10)
                              : AppColors.headerBottom.withValues(alpha: 0.10))
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
                                  ? ctx.appBrandTextColor
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
                                    ? ctx.appBrandIconColor
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

  List<Reservation> _applyFilters(List<Reservation> items, String stateLabel) {
    var filtered = [...items];

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered =
          filtered.where((r) {
            return r.parkingName.toLowerCase().contains(q) ||
                (r.reservationNumber ?? '').toLowerCase().contains(q) ||
                (r.plate ?? '').toLowerCase().contains(q) ||
                (r.userName ?? '').toLowerCase().contains(q);
          }).toList();
    }

    if (stateLabel == 'active') {
      filtered.sort((a, b) => b.reservedAt.compareTo(a.reservedAt));
      return filtered;
    }

    final now = DateTime.now();
    final startOfWeek = _startOfWeek(now);
    final startOfMonth = DateTime(now.year, now.month, 1);

    if (_periodFilter == _ReservationsPeriodFilter.week) {
      filtered =
          filtered.where((r) => !r.reservedAt.isBefore(startOfWeek)).toList();
    } else if (_periodFilter == _ReservationsPeriodFilter.month) {
      filtered =
          filtered.where((r) => !r.reservedAt.isBefore(startOfMonth)).toList();
    } else if (_periodFilter == _ReservationsPeriodFilter.custom &&
        _dateRange != null) {
      filtered =
          filtered.where((r) {
            final d = r.reservedAt;
            return !d.isBefore(_dateRange!.start) &&
                !d.isAfter(_dateRange!.end.add(const Duration(days: 1)));
          }).toList();
    }

    filtered.sort((a, b) => b.reservedAt.compareTo(a.reservedAt));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(firebaseAuthProvider);

    if (auth.currentUser == null) {
      return Scaffold(
        backgroundColor: context.appPageBackground,
        body: Center(
          child: MyText(
            text: 'Inicia sesión para ver tus reservaciones',
            variant: MyTextVariant.body,
          ),
        ),
      );
    }

    final asyncList = ref.watch(userReservationsProvider);
    final controlAsync = ref.watch(userReservationControlProvider);

    asyncList.whenData((all) {
      if (!_handledInitialReservation &&
          widget.initialReservationId != null &&
          widget.initialReservationId!.isNotEmpty) {
        final target = all.cast<Reservation?>().firstWhere(
          (reservation) => reservation?.id == widget.initialReservationId,
          orElse: () => null,
        );

        if (target != null) {
          _handledInitialReservation = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => ReservationDetailsSheet(reservation: target),
            );
          });
        }
      }

      final pendingPrompt = all.cast<Reservation?>().firstWhere(
        (reservation) => reservation?.needsRatingPrompt == true,
        orElse: () => null,
      );

      if (pendingPrompt == null) return;
      if (_ratingPromptInFlight.contains(pendingPrompt.id)) return;

      _ratingPromptInFlight.add(pendingPrompt.id);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showRatingDialog(context, reservation: pendingPrompt);
        _ratingPromptInFlight.remove(pendingPrompt.id);
      });
    });

    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 175,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors:
                          context.isDarkMode
                              ? const [
                                Color(0xFF111827),
                                Color(0xFF0F172A),
                                Color(0xFF0B1220),
                              ]
                              : const [
                                AppColors.headerTop,
                                AppColors.headerBottom,
                              ],
                    ),
                  ),
                ),
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: context.isDarkMode ? 0.04 : 0.09,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: 64,
                  left: -18,
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: context.isDarkMode ? 0.03 : 0.07,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                      child: Column(
                        children: [
                          const MyText(
                            text: 'MIS RESERVACIONES',
                            variant: MyTextVariant.title,
                            textAlign: TextAlign.center,
                            customColor: Colors.white,
                          ),
                          const SizedBox(height: 10),
                          controlAsync.when(
                            loading: () => const SizedBox(height: 18),
                            error: (_, __) => const SizedBox(height: 18),
                            data: (control) {
                              final used =
                                  (control?['cancelAttempts'] as num?)
                                      ?.toInt() ??
                                  0;
                              final max =
                                  Reservation.maxCancellationAttemptsLimit;
                              final limitReached = used >= max;

                              if (limitReached) {
                                return _HeaderLimitMessage(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => const ReportProblemPage(),
                                      ),
                                    );
                                  },
                                );
                              }

                              return MyText(
                                text: 'Cancelaciones usadas: $used/$max',
                                variant: MyTextVariant.bodyMuted,
                                textAlign: TextAlign.center,
                                customColor: Colors.white70,
                                fontSize: 13,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  top: 14,
                  child: SafeArea(
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                      ),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                      ),
                      label: const Text('Regresar'),
                    ),
                  ),
                ),
              ],
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _SegmentTabs(controller: _tab),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    Container(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: context.appInputBackground,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color:
                                _searchHasFocus
                                    ? AppColors.headerBottom.withValues(
                                      alpha: 0.55,
                                    )
                                    : context.appBorderColor,
                            width: _searchHasFocus ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  _searchHasFocus
                                      ? AppColors.headerBottom.withValues(
                                        alpha: 0.10,
                                      )
                                      : Colors.black.withValues(
                                        alpha: context.isDarkMode ? 0.06 : 0.03,
                                      ),
                              blurRadius: _searchHasFocus ? 16 : 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          onTapOutside:
                              (_) => FocusManager.instance.primaryFocus
                                  ?.unfocus(),
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimaryColor,
                          ),
                          decoration: InputDecoration(
                            filled: false,
                            hintText: 'Buscar por No., nombre, placa...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: context.appTextSecondaryColor,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(13),
                              child: Icon(
                                Icons.search_rounded,
                                size: 20,
                                color:
                                    _searchHasFocus
                                        ? AppColors.headerBottom
                                        : context.appTextSecondaryColor,
                              ),
                            ),
                            suffixIcon:
                                _searchQuery.isNotEmpty
                                    ? GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: context.appBorderColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 12,
                                            color: context.appTextSecondaryColor,
                                          ),
                                        ),
                                      ),
                                    )
                                    : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!_isActiveTab) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _ReservationsFilterChip(
                          icon: Icons.calendar_today_rounded,
                          label:
                              _periodFilter ==
                                          _ReservationsPeriodFilter.custom &&
                                      _dateRange != null
                                  ? '${_formatDate(_dateRange!.start)} – ${_formatDate(_dateRange!.end)}'
                                  : _periodFilter.label,
                          active:
                              _periodFilter != _ReservationsPeriodFilter.week ||
                              _dateRange != null,
                          activeColor: AppColors.headerBottom,
                          onTap: _showPeriodFilterSheet,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -4),
                child: asyncList.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (e, __) => Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: MyText(
                            text: 'Error cargando reservaciones: $e',
                            variant: MyTextVariant.bodyBold,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  data: (all) {
                    String norm(String? s) => (s ?? '').toLowerCase().trim();

                    final active =
                        all.where((r) {
                          final state = norm(r.state);
                          final providerApproval = norm(
                            r.providerApprovalStatus,
                          );

                          return state == 'active' ||
                              state == 'pending' ||
                              state == 'cancellation_requested' ||
                              providerApproval == 'pending';
                        }).toList();

                    final completed =
                        all.where((r) => norm(r.state) == 'completed').toList();

                    final cancelled =
                        all.where((r) => norm(r.state) == 'cancelled').toList();

                    return TabBarView(
                      controller: _tab,
                      children: [
                        _ResList(
                          items: _applyFilters(active, 'active'),
                          stateLabel: 'active',
                        ),
                        _ResList(
                          items: _applyFilters(completed, 'completed'),
                          stateLabel: 'completed',
                        ),
                        _ResList(
                          items: _applyFilters(cancelled, 'cancelled'),
                          stateLabel: 'cancelled',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderLimitMessage extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderLimitMessage({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          const Text(
            'Has superado el límite de cancelaciones.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: onTap,
            child: const Text(
              'Reporta el problema aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFD6E8FF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFFD6E8FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: context.isDarkMode ? 0 : 8,
      color: context.appCardBackground,
      borderRadius: BorderRadius.circular(24),
      shadowColor: Colors.black.withValues(
        alpha: context.isDarkMode ? 0.18 : 0.10,
      ),
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.appBorderColor),
        ),
        child: TabBar(
          controller: controller,
          labelPadding: EdgeInsets.zero,
          indicator: BoxDecoration(
            color:
                context.isDarkMode
                    ? context.appCardBackgroundSoft
                    : const Color(0xFFEAF0F7),
            borderRadius: BorderRadius.circular(18),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor:
              context.isDarkMode ? Colors.white : const Color(0xFF1B3A57),
          unselectedLabelColor: context.appTextSecondaryColor,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Activo'),
            Tab(text: 'Completado'),
            Tab(text: 'Cancelado'),
          ],
        ),
      ),
    );
  }
}

class _ResList extends StatelessWidget {
  final List<Reservation> items;
  final String stateLabel;

  const _ResList({required this.items, required this.stateLabel});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyReservationsState(stateLabel: stateLabel);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => ReservationCard(reservation: items[i]),
    );
  }
}

class _EmptyReservationsState extends StatelessWidget {
  final String stateLabel;

  const _EmptyReservationsState({required this.stateLabel});

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    IconData icon;

    switch (stateLabel) {
      case 'active':
        title = 'No hay reservaciones activas';
        subtitle = 'Tus reservaciones activas o pendientes aparecerán aquí.';
        icon = Icons.local_parking_outlined;
        break;
      case 'completed':
        title = 'No hay reservaciones completadas';
        subtitle =
            'Tus reservaciones finalizadas de esta semana aparecerán aquí.';
        icon = Icons.task_alt_outlined;
        break;
      default:
        title = 'No hay reservaciones canceladas';
        subtitle =
            'Tus reservaciones canceladas de esta semana aparecerán aquí.';
        icon = Icons.cancel_outlined;
    }

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
                    width: 86,
                    height: 86,
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
                      size: 34,
                      color:
                          context.isDarkMode
                              ? context.appBrandIconColor
                              : AppColors.headerBottom,
                    ),
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
          ),
        );
      },
    );
  }
}

class _ReservationsFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _ReservationsFilterChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeContentColor =
        context.isDarkMode ? context.appBrandTextColor : activeColor;
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
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color:
                  active ? activeContentColor : context.appTextSecondaryColor,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      active ? activeContentColor : context.appTextPrimaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
