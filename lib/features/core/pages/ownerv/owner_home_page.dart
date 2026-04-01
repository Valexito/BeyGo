import 'package:flutter/material.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/features/core/pages/ownerv/owner_parking_list_page.dart';
import 'package:mapbox_api/features/core/pages/ownerv/owner_reservations_page.dart';
import 'package:mapbox_api/features/core/pages/ownerv/owner_settings_page.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  int _index = 0;

  final _tabs = const <_TabItem>[
    _TabItem('Parqueos', Icons.local_parking_outlined),
    _TabItem('Solicitudes', Icons.fact_check_outlined),
    _TabItem('Reservas', Icons.receipt_long_outlined),
    _TabItem('Ajustes', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return OwnerOnly(
      builder: (_) {
        final pages = const [
          OwnerParkingListPage(),
          OwnerReservationsPage(),
          OwnerReservationsPage(showOnlyHistory: true),
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
