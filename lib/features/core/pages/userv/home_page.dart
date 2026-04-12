import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:mapbox_api/common/utils/components/app_drawer.dart';
import 'package:mapbox_api/common/utils/components/home_bottom_panel.dart';
import 'package:mapbox_api/features/core/components/map_widget.dart';

// Providers (Riverpod)
import 'package:mapbox_api/features/core/providers/map_providers.dart';
import 'package:mapbox_api/features/reservations/providers/location_providers.dart';

const mapboxToken = String.fromEnvironment('MAPBOX_TOKEN');

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _bottomCtrl = DraggableScrollableController();

  static const double _minSheet = 0.18;

  void _minimizePanel() {
    _bottomCtrl.animateTo(
      _minSheet,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // 1) MapController compartido (Riverpod)
    final MapController map = ref.watch(mapControllerProvider);

    // 2) (Opcional) Ubicación actual para “esperar” antes de mostrar algo o centrar una vez
    final locAsync = ref.watch(currentLocationProvider);

    debugPrint('MAPBOX_TOKEN length: ${mapboxToken.length}');
    debugPrint(
      'MAPBOX_TOKEN preview: ${mapboxToken.isEmpty ? 'EMPTY' : mapboxToken.substring(0, mapboxToken.length > 12 ? 12 : mapboxToken.length)}',
    );
    debugPrint('MAPBOX_TOKEN available: ${mapboxToken.isNotEmpty}');

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // --- MAPA ---
          locAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (_, __) =>
                    MapWidget(mapController: map, onMapTap: _minimizePanel),
            data:
                (_) => MapWidget(mapController: map, onMapTap: _minimizePanel),
          ),

          // --- BOTÓN HAMBURGUESA ---
          Positioned(
            top: 40,
            left: 16,
            child: _FloatingIcon(
              icon: Icons.menu,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),

          // --- BOTÓN SETTINGS ---
          Positioned(
            top: 40,
            right: 16,
            child: _FloatingIcon(
              icon: Icons.settings,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (_) => const _SettingsSheet(),
                );
              },
            ),
          ),

          // --- PANEL INFERIOR ---
          HomeBottomPanel(
            controller: _bottomCtrl,
            onPlaceSelected: (LatLng p) {
              map.move(p, 16);
              _minimizePanel();
            },
          ),
        ],
      ),
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FloatingIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blueAccent, width: 1.8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.blueAccent),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          ListTile(
            leading: Icon(Icons.language),
            title: Text('Cambiar idioma'),
          ),
          ListTile(
            leading: Icon(Icons.brightness_6),
            title: Text('Cambiar tema'),
          ),
        ],
      ),
    );
  }
}
