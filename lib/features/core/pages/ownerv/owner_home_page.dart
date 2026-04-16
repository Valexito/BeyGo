import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/features/core/pages/ownerv/owner_reservations_page.dart';
import 'package:mapbox_api/features/core/pages/ownerv/owner_requests_page.dart';
import 'package:mapbox_api/features/core/pages/ownerv/owner_settings_page.dart';
import 'package:mapbox_api/features/core/pages/ownerv/owner_history_page.dart';
import 'package:mapbox_api/features/core/pages/ownerv/providers/dashboard_providers.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';

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
    _TabItem('Historial', Icons.history_rounded),
    _TabItem('Ajustes', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return OwnerOnly(
      builder: (_) {
        final pages = <Widget>[
          const _OwnerDashboardView(),
          const OwnerRequestsPage(),
          const OwnerReservationsPage(),
          const OwnerHistoryPage(),
          const OwnerSettingsPage(),
        ];

        return Scaffold(
          backgroundColor: AppColors.pageBg,
          body: pages[_index],
          bottomNavigationBar: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                backgroundColor: Colors.white,
                indicatorColor: AppColors.primarySoft.withOpacity(0.25),
                labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                  states,
                ) {
                  final isSelected = states.contains(WidgetState.selected);
                  return TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color:
                        isSelected
                            ? AppColors.headerBottom
                            : AppColors.headerBottom.withOpacity(0.6),
                  );
                }),
                destinations:
                    _tabs.map((t) {
                      return NavigationDestination(
                        icon: Icon(
                          t.icon,
                          color: AppColors.headerBottom.withOpacity(0.6),
                        ),
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
  const _OwnerDashboardView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(ownerDashboardStatsProvider);
    final parkingAsync = ref.watch(ownerParkingProvider);

    final parkingName = parkingAsync.asData?.value?.name ?? 'Mi Parqueo';

    return Scaffold(
      backgroundColor: AppColors.pageBg,
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

                  // ── Revenue cards ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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

                  // ── Occupancy ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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

                  // ── Stats grid ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: _SectionTitle(
                        icon: Icons.bar_chart_rounded,
                        title: 'Resumen',
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
                            childAspectRatio: 1.55,
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

  const _DashboardHeader({required this.parkingName, required this.stats});

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

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.headerTop, AppColors.headerBottom],
        ),
        borderRadius: BorderRadius.only(
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
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'EN VIVO',
                      style: TextStyle(
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

          // Quick stats row
          Row(
            children: [
              _HeaderStat(
                label: 'Activas',
                value: '${stats.activeReservations}',
                icon: Icons.local_parking_rounded,
              ),
              _HeaderDivider(),
              _HeaderStat(
                label: 'Pendientes',
                value: '${stats.pendingApproval}',
                icon: Icons.hourglass_top_rounded,
              ),
              _HeaderDivider(),
              _HeaderStat(
                label: 'Solicitudes',
                value: '${stats.exitRequests + stats.cancellationRequests}',
                icon: Icons.notifications_none_rounded,
              ),
              _HeaderDivider(),
              _HeaderStat(
                label: 'Espacios',
                value:
                    '${stats.totalSpaces - stats.occupiedSpaces}/${stats.totalSpaces}',
                icon: Icons.grid_view_rounded,
                sublabel: 'libres',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? sublabel;

  const _HeaderStat({
    required this.label,
    required this.value,
    required this.icon,
    this.sublabel,
  });

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
            sublabel ?? label,
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
      color: Colors.white.withOpacity(0.20),
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
            const Text(
              'Requiere atención',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
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
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
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
              color: color.withOpacity(0.10),
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
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8A94A6),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.05),
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
                    const Text(
                      'Ocupación actual',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A94A6),
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
        color: color.withOpacity(0.10),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8A94A6),
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

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.headerBottom),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${reservation.userName ?? 'N/A'} · ${reservation.plate ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A94A6),
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
                  color: color.withOpacity(0.10),
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
                style: const TextStyle(fontSize: 10, color: Color(0xFF8A94A6)),
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
