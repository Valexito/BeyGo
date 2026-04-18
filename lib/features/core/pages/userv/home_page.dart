// lib/features/core/pages/home_page.dart
//
// Uses the common widget library (AppHamburgerButton, AppMapZoomControls, AppMapCenterButton)
// and migrates from Mapbox MapController to google_maps_flutter.
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapbox_api/common/ui/widgets/app_drawer.dart';
import 'package:mapbox_api/common/ui/widgets/app_widgets.dart';
import 'package:mapbox_api/common/ui/widgets/home_bottom_panel.dart';

import 'package:mapbox_api/features/reservations/providers/location_providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _bottomCtrl = DraggableScrollableController();

  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  bool _locatingUser = false;

  static const double _minSheet = 0.18;
  static const LatLng _defaultCenter = LatLng(14.8349, -91.5186); // Xela

  void _minimizePanel() {
    if (_bottomCtrl.isAttached) {
      _bottomCtrl.animateTo(
        _minSheet,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
    FocusScope.of(context).unfocus();
  }

  Future<void> _centerOnUser() async {
    if (_locatingUser) return;
    setState(() => _locatingUser = true);
    try {
      final locAsync = ref.read(currentLocationProvider);
      final pos = locAsync.valueOrNull;
      if (pos != null && _mapController != null) {
        final target = LatLng(pos.latitude, pos.longitude);
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: target, zoom: 16),
          ),
        );
        setState(() => _currentLocation = target);
      }
    } finally {
      if (mounted) setState(() => _locatingUser = false);
    }
  }

  void _onPlaceSelected(LatLng place) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: place, zoom: 16)),
    );
    _minimizePanel();
  }

  @override
  Widget build(BuildContext context) {
    final locAsync = ref.watch(currentLocationProvider);

    // Determine initial camera position
    final initialPosition = locAsync.maybeWhen(
      data:
          (pos) => CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 15,
          ),
      orElse: () => const CameraPosition(target: _defaultCenter, zoom: 14),
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────────────
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              // If location is available, fly there
              locAsync.whenData((pos) {
                controller.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: LatLng(pos.latitude, pos.longitude),
                      zoom: 15,
                    ),
                  ),
                );
              });
            },
            initialCameraPosition: initialPosition,
            onTap: (_) => _minimizePanel(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // ── Top left: Hamburger menu button ─────────────────────────────────
          Positioned(
            top: 0,
            left: 12,
            child: SafeArea(
              child: AppHamburgerButton(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
          ),

          // ── Right side: Zoom controls + center button ────────────────────────
          Positioned(
            right: 12,
            bottom: 200,
            child: Column(
              children: [
                AppMapZoomControls(controller: _mapController),
                const SizedBox(height: 8),
                AppMapCenterButton(
                  onTap: _centerOnUser,
                  loading: _locatingUser,
                ),
              ],
            ),
          ),

          // ── Bottom panel ─────────────────────────────────────────────────────
          HomeBottomPanel(
            controller: _bottomCtrl,
            onPlaceSelected: _onPlaceSelected,
          ),
        ],
      ),
    );
  }
}
