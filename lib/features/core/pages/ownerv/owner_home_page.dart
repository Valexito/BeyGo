import 'package:flutter/material.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/features/core/pages/ownerv/owner_reservations_page.dart';
import 'package:mapbox_api/features/core/pages/ownerv/owner_requests_page.dart';
import 'package:mapbox_api/features/core/pages/ownerv/owner_settings_page.dart';
import 'package:mapbox_api/features/core/pages/ownerv/owner_history_page.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';

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
        final pages = const <Widget>[
          _OwnerDashboardView(),
          OwnerRequestsPage(),
          OwnerReservationsPage(),
          OwnerHistoryPage(),
          OwnerSettingsPage(),
        ];

        return Scaffold(
          backgroundColor: AppColors.pageBg,
          appBar: AppBar(
            title: Text(_tabs[_index].label),
            centerTitle: true,
            backgroundColor: AppColors.headerBottom,
          ),
          body: pages[_index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: Colors.white,
            indicatorColor: AppColors.primarySoft.withOpacity(0.25),
            destinations:
                _tabs
                    .map(
                      (t) => NavigationDestination(
                        icon: Icon(t.icon),
                        label: t.label,
                      ),
                    )
                    .toList(),
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

class _OwnerDashboardView extends StatelessWidget {
  const _OwnerDashboardView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.headerTop, AppColors.headerBottom],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Dashboard',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: const [
              _MetricCard('Activos', Icons.local_parking),
              _MetricCard('Pendientes', Icons.notifications),
              _MetricCard('Rating', Icons.star),
              _MetricCard('Ingresos', Icons.attach_money),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MetricCard(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.headerBottom),
          const Spacer(),
          Text(label),
        ],
      ),
    );
  }
}
