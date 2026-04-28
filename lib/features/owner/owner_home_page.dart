import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/owner/owner.dart';
import 'package:beygo/features/reservations/reservations.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  int _index = 0;

  final _tabs = const <_TabItem>[
    _TabItem('Inicio', Icons.home_rounded),
    _TabItem('Solicitudes', Icons.fact_check_outlined),
    _TabItem('Reservas', Icons.receipt_long_outlined),
    _TabItem('Presencial', Icons.directions_car_filled_rounded),
    _TabItem('Historial', Icons.history_rounded),
    _TabItem('Ajustes', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return OwnerOnly(
      builder: (_) {
        final pages = <Widget>[
          _OwnerDashboardView(onNavigate: (i) => setState(() => _index = i)),
          const OwnerRequestsPage(),
          const OwnerReservationsPage(),
          const OwnerWalkInPage(),
          const OwnerHistoryPage(),
          const OwnerSettingsPage(),
        ];

        final unselectedNavColor =
            context.isDarkMode
                ? Colors.white.withValues(alpha: 0.88)
                : context.appTextSecondaryColor;

        return Scaffold(
          backgroundColor: context.appPageBackground,
          body: pages[_index],
          bottomNavigationBar: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: context.isDarkMode ? 0.22 : 0.06,
                  ),
                  blurRadius: context.isDarkMode ? 18 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: context.appBorderColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                height: 76,
                backgroundColor: context.appCardBackground,
                indicatorColor:
                    context.isDarkMode
                        ? AppColors.headerBottom.withValues(alpha: 0.22)
                        : AppColors.primarySoft.withValues(alpha: 0.25),
                labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                  states,
                ) {
                  final isSelected = states.contains(WidgetState.selected);
                  return TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color:
                        isSelected
                            ? AppColors.headerBottom
                            : unselectedNavColor,
                  );
                }),
                destinations:
                    _tabs.map((t) {
                      return NavigationDestination(
                        icon: Icon(t.icon, color: unselectedNavColor),
                        selectedIcon: Icon(
                          t.icon,
                          color: AppColors.headerBottom,
                        ),
                        label: t.label,
                      );
                    }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  const _TabItem(this.label, this.icon);
}

// ─── Dashboard View ────────────────────────────────────────────────────────────
class _OwnerDashboardView extends ConsumerWidget {
  const _OwnerDashboardView({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(ownerDashboardStatsProvider);
    final parkingAsync = ref.watch(ownerParkingProvider);
    final preferences = ref.watch(appPreferencesProvider);

    final parking = parkingAsync.asData?.value;
    final parkingName = parking?.name ?? 'Mi Parqueo';

    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: SafeArea(
        bottom: false,
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data:
              (stats) => CustomScrollView(
                slivers: [
                  // ── Hero header ──
                  SliverToBoxAdapter(
                    child: _DashboardHeader(
                      parkingName: parkingName,
                      businessHours: parking?.businessHours,
                      totalSpaces: stats.totalSpaces,
                      occupiedSpaces: stats.occupiedSpaces,
                      stats: stats,
                    ),
                  ),

                  // ── Alert badges (only show if > 0) ──
                  if (stats.pendingApproval > 0 ||
                      stats.exitRequests > 0 ||
                      stats.cancellationRequests > 0)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: _AlertsRow(stats: stats),
                      ),
                    ),

                  // ── Occupancy ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _SectionTitle(
                        icon: Icons.local_parking_rounded,
                        title: 'Ocupación en tiempo real',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: _OccupancyCard(stats: stats),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: _SectionTitle(
                        icon: Icons.show_chart_rounded,
                        title: 'Tendencia de hoy',
                        trailing: _PeakHourLabel(
                          reservations: stats.recentActivity,
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: _TodayTrendCard(
                        reservations: stats.recentActivity,
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: _SectionTitle(
                        icon: Icons.bolt_rounded,
                        title: 'Acciones rápidas',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: _QuickActionsRow(onNavigate: onNavigate),
                    ),
                  ),

                  if (preferences.ownerRevenueVisible) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: _SectionTitle(
                          icon: Icons.attach_money_rounded,
                          title: 'Ingresos',
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: _RevenueRow(stats: stats),
                      ),
                    ),
                  ],

                  // ── Stats grid ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: _SectionTitle(
                        icon: Icons.bar_chart_rounded,
                        title: 'Resumen operativo',
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    sliver: SliverGrid(
                      delegate: SliverChildListDelegate([
                        _StatCard(
                          icon: Icons.check_circle_outline_rounded,
                          iconColor: const Color(0xFF16A34A),
                          label: 'Completadas hoy',
                          value: '${stats.completedToday}',
                        ),
                        _StatCard(
                          icon: Icons.calendar_month_outlined,
                          iconColor: const Color(0xFF2563EB),
                          label: 'Completadas mes',
                          value: '${stats.completedThisMonth}',
                        ),
                        _StatCard(
                          icon: Icons.local_parking_rounded,
                          iconColor: AppColors.headerBottom,
                          label: 'Activas ahora',
                          value: '${stats.activeReservations}',
                        ),
                        _StatCard(
                          icon: Icons.cancel_outlined,
                          iconColor: const Color(0xFFDC2626),
                          label: 'Canceladas',
                          value: '${stats.cancelledTotal}',
                        ),
                      ]),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.42,
                          ),
                    ),
                  ),

                  // ── Recent activity ──
                  if (stats.recentActivity.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: _SectionTitle(
                          icon: Icons.history_rounded,
                          title: 'Actividad reciente',
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ActivityTile(
                              reservation: stats.recentActivity[i],
                            ),
                          ),
                          childCount: stats.recentActivity.length,
                        ),
                      ),
                    ),
                  ] else
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
        ),
      ),
    );
  }
}

// ─── Hero header ───────────────────────────────────────────────────────────────
class _DashboardHeader extends StatelessWidget {
  final String parkingName;
  final OwnerDashboardStats stats;
  final Map<String, String>? businessHours;
  final int totalSpaces;
  final int occupiedSpaces;

  const _DashboardHeader({
    required this.parkingName,
    required this.stats,
    required this.businessHours,
    required this.totalSpaces,
    required this.occupiedSpaces,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting =
        hour < 12
            ? 'Buenos días'
            : hour < 18
            ? 'Buenas tardes'
            : 'Buenas noches';
    final status = _parkingStatus(now, businessHours);
    final freeSpaces = totalSpaces - occupiedSpaces;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              context.isDarkMode
                  ? const [Color(0xFF122033), Color(0xFF0F172A)]
                  : const [AppColors.headerTop, AppColors.headerBottom],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting row
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/branding/icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      parkingName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'BeyGo Owner',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              // Live dot
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color:
                            status.isOpen
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFF87171),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      status.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                _HeaderStat(
                  label: 'Activas',
                  value: '${stats.activeReservations}',
                ),
                _HeaderDivider(),
                _HeaderStat(
                  label: 'Pendientes',
                  value: '${stats.pendingApproval}',
                ),
                _HeaderDivider(),
                _HeaderStat(
                  label: 'Solicitudes',
                  value: '${stats.exitRequests + stats.cancellationRequests}',
                ),
                _HeaderDivider(),
                _HeaderStat(label: 'Libres', value: '$freeSpaces/$totalSpaces'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _ParkingStatus _parkingStatus(DateTime now, Map<String, String>? hours) {
    TimeOfDay? parse(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      final parts = raw.split(':');
      if (parts.length != 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      return TimeOfDay(hour: hour, minute: minute);
    }

    final open = parse(hours?['open']);
    final close = parse(hours?['close']);
    if (open == null || close == null) {
      return const _ParkingStatus(label: 'ABIERTO', isOpen: true);
    }

    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;

    final isOpen =
        openMinutes <= closeMinutes
            ? nowMinutes >= openMinutes && nowMinutes <= closeMinutes
            : nowMinutes >= openMinutes || nowMinutes <= closeMinutes;

    return _ParkingStatus(
      label: isOpen ? 'ABIERTO' : 'CERRADO',
      isOpen: isOpen,
    );
  }
}

class _ParkingStatus {
  final String label;
  final bool isOpen;

  const _ParkingStatus({required this.label, required this.isOpen});
}

class _PeakHourLabel extends StatelessWidget {
  final List<Reservation> reservations;

  const _PeakHourLabel({required this.reservations});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayItems =
        reservations.where((r) {
          final d = r.reservedAt;
          return d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
        }).toList();

    final byHour = <int, int>{};
    for (final item in todayItems) {
      byHour.update(item.reservedAt.hour, (v) => v + 1, ifAbsent: () => 1);
    }
    if (byHour.isEmpty) return const SizedBox.shrink();

    final peak = byHour.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return Text(
      'Hora pico ${peak.key.toString().padLeft(2, '0')}:00',
      style: TextStyle(
        color: context.appTextSecondaryColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _TodayTrendCard extends StatelessWidget {
  final List<Reservation> reservations;

  const _TodayTrendCard({required this.reservations});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final counts = List<int>.filled(8, 0);

    for (final item in reservations) {
      final d = item.reservedAt;
      if (d.year != now.year || d.month != now.month || d.day != now.day) {
        continue;
      }
      final index = (((d.hour - 8) / 2).floor()).clamp(0, 7);
      counts[index] += 1;
    }

    final maxValue = counts.fold<int>(0, (prev, e) => e > prev ? e : prev);
    final labels = const [
      '8a',
      '10a',
      '12a',
      '14h',
      '16h',
      '18h',
      '20h',
      '22h',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.16 : 0.06,
            ),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < counts.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      children: [
                        Container(
                          height:
                              maxValue == 0
                                  ? 10
                                  : 18 + (counts[i] / maxValue) * 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors:
                                  i == 3
                                      ? const [
                                        AppColors.headerTop,
                                        AppColors.headerBottom,
                                      ]
                                      : [
                                        AppColors.headerBottom.withValues(
                                          alpha: 0.65,
                                        ),
                                        AppColors.headerBottom.withValues(
                                          alpha: 0.92,
                                        ),
                                      ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.appTextSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const _QuickActionsRow({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.fact_check_outlined,
            label: 'Aprobar',
            color: const Color(0xFF2563EB),
            onTap: () => onNavigate(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.directions_car_filled_rounded,
            label: 'Presencial',
            color: const Color(0xFF16A34A),
            onTap: () => onNavigate(3),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.receipt_long_outlined,
            label: 'Reservas',
            color: const Color(0xFF8B5CF6),
            onTap: () => onNavigate(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.history_rounded,
            label: 'Historial',
            color: const Color(0xFFF59E0B),
            onTap: () => onNavigate(4),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appCardBackground,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.appBorderColor),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withValues(alpha: 0.20),
    );
  }
}

// ─── Alerts row ────────────────────────────────────────────────────────────────
class _AlertsRow extends StatelessWidget {
  final OwnerDashboardStats stats;

  const _AlertsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Requiere atención',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimaryColor,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (stats.pendingApproval > 0)
                _AlertChip(
                  icon: Icons.hourglass_top_rounded,
                  label: '${stats.pendingApproval} por aprobar',
                  color: const Color(0xFF2563EB),
                ),
              if (stats.exitRequests > 0) ...[
                if (stats.pendingApproval > 0) const SizedBox(width: 8),
                _AlertChip(
                  icon: Icons.exit_to_app_rounded,
                  label: '${stats.exitRequests} salida(s)',
                  color: const Color(0xFF0EA5E9),
                ),
              ],
              if (stats.cancellationRequests > 0) ...[
                if (stats.pendingApproval > 0 || stats.exitRequests > 0)
                  const SizedBox(width: 8),
                _AlertChip(
                  icon: Icons.cancel_outlined,
                  label: '${stats.cancellationRequests} cancelación(es)',
                  color: const Color(0xFFF59E0B),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AlertChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _AlertChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Revenue row ───────────────────────────────────────────────────────────────
class _RevenueRow extends StatelessWidget {
  final OwnerDashboardStats stats;

  const _RevenueRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RevenueCard(
            label: 'Hoy',
            amount: stats.revenueToday,
            icon: Icons.wb_sunny_outlined,
            color: const Color(0xFF16A34A),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RevenueCard(
            label: 'Este mes',
            amount: stats.revenueThisMonth,
            icon: Icons.calendar_month_outlined,
            color: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RevenueCard(
            label: 'Total',
            amount: stats.revenueAllTime,
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.headerBottom,
          ),
        ),
      ],
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _RevenueCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            'Q ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.appTextSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Occupancy card ────────────────────────────────────────────────────────────
class _OccupancyCard extends StatelessWidget {
  final OwnerDashboardStats stats;

  const _OccupancyCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rate = stats.occupancyRate;
    final free = stats.totalSpaces - stats.occupiedSpaces;
    final occupancyColor =
        rate >= 90
            ? const Color(0xFFDC2626)
            : rate >= 60
            ? const Color(0xFFF59E0B)
            : const Color(0xFF16A34A);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rate.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: occupancyColor,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ocupación actual',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTextSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Spaces summary
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SpaceBadge(
                    label: '${stats.occupiedSpaces} ocupados',
                    color: occupancyColor,
                  ),
                  const SizedBox(height: 6),
                  _SpaceBadge(
                    label: '$free libres',
                    color: const Color(0xFF16A34A),
                  ),
                  const SizedBox(height: 6),
                  _SpaceBadge(
                    label: '${stats.totalSpaces} total',
                    color: AppColors.headerBottom,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value:
                  stats.totalSpaces == 0
                      ? 0
                      : stats.occupiedSpaces / stats.totalSpaces,
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(occupancyColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SpaceBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: context.appTextPrimaryColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: context.appTextSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section title ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const _SectionTitle({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.headerBottom),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimaryColor,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ─── Activity tile ─────────────────────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final Reservation reservation;

  const _ActivityTile({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(reservation.state);
    final icon = _stateIcon(reservation.state);
    final label = _stateLabel(reservation.state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No. ${reservation.reservationNumber ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${reservation.userName ?? 'N/A'} · ${reservation.plate ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _format(reservation.reservedAt),
                style: TextStyle(
                  fontSize: 10,
                  color: context.appTextSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _stateColor(String state) {
    switch (state) {
      case 'active':
        return const Color(0xFF2563EB);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'cancellation_requested':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.headerBottom;
    }
  }

  IconData _stateIcon(String state) {
    switch (state) {
      case 'active':
        return Icons.local_parking_rounded;
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'pending':
        return Icons.hourglass_top_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  String _stateLabel(String state) {
    switch (state) {
      case 'active':
        return 'ACTIVA';
      case 'completed':
        return 'COMPLETADA';
      case 'cancelled':
        return 'CANCELADA';
      case 'pending':
        return 'PENDIENTE';
      case 'cancellation_requested':
        return 'CANCEL. SOLICITADA';
      default:
        return state.toUpperCase();
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
