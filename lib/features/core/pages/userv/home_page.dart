// lib/features/core/pages/home_page.dart
//
// ✅ GlobalKey<MapWidgetState> — works because MapWidgetState is PUBLIC
// ✅ Hamburger: safeTop + 12px (not glued to corner)
// ✅ Settings: top-right
// ✅ Map controls: AnimatedPositioned, float above bottom sheet
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/widgets/app_drawer.dart';
import 'package:mapbox_api/common/ui/widgets/home_bottom_panel.dart';
import 'package:mapbox_api/features/core/components/map_widget.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _bottomCtrl = DraggableScrollableController();

  // ✅ MapWidgetState is public — this compiles correctly
  final _mapKey = GlobalKey<MapWidgetState>();

  GoogleMapController? _mapController;
  LatLng? _userLocation;
  bool _locatingUser = false;

  static const double _minSheet = 0.18;
  double _sheetFraction = _minSheet;

  @override
  void initState() {
    super.initState();
    _bottomCtrl.addListener(_onSheetChanged);
  }

  @override
  void dispose() {
    _bottomCtrl.removeListener(_onSheetChanged);
    super.dispose();
  }

  void _onSheetChanged() {
    if (!_bottomCtrl.isAttached) return;
    final size = _bottomCtrl.size;
    if ((size - _sheetFraction).abs() > 0.005) {
      setState(() => _sheetFraction = size);
    }
  }

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
      _mapKey.currentState?.centerOnUser();
    } finally {
      if (mounted) setState(() => _locatingUser = false);
    }
  }

  Future<void> _zoomIn() => _mapKey.currentState?.zoomBy(1) ?? Future.value();

  Future<void> _zoomOut() => _mapKey.currentState?.zoomBy(-1) ?? Future.value();

  void _onPlaceSelected(LatLng place) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: place, zoom: 16)),
    );
    _minimizePanel();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final safeTop = MediaQuery.of(context).padding.top;
    final controlsBottom = (_sheetFraction * screen.height) + 16;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          // ── Map (parking markers + user location) ────────────────────────
          Positioned.fill(
            child: MapWidget(
              key: _mapKey,
              onMapTap: _minimizePanel,
              onMapCreated: (ctrl) => _mapController = ctrl,
              onUserLocationChanged: (location) {
                if (!mounted) return;
                setState(() => _userLocation = location);
              },
            ),
          ),

          // ── Top-left: Hamburger (safeTop + 12, not at the corner edge) ───
          Positioned(
            top: safeTop + 12,
            left: 12,
            child: _TopBtn(
              icon: Icons.menu_rounded,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),

          // ── Top-right: Settings ──────────────────────────────────────────
          Positioned(
            top: safeTop + 12,
            right: 12,
            child: _TopBtn(
              icon: Icons.settings_outlined,
              onTap:
                  () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const _SettingsSheet(),
                  ),
            ),
          ),

          // ── Map controls (float above bottom panel) ──────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            right: 12,
            bottom: controlsBottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapCtrlBtn(icon: Icons.add, onTap: _zoomIn),
                const SizedBox(height: 6),
                _MapCtrlBtn(icon: Icons.remove, onTap: _zoomOut),
                const SizedBox(height: 10),
                _MapCtrlBtn(
                  icon:
                      _locatingUser
                          ? Icons.location_searching_rounded
                          : Icons.my_location_rounded,
                  onTap: _centerOnUser,
                  loading: _locatingUser,
                  accent: true,
                ),
              ],
            ),
          ),

          // ── Bottom search/place panel ────────────────────────────────────
          HomeBottomPanel(
            controller: _bottomCtrl,
            onPlaceSelected: _onPlaceSelected,
            userLocation: _userLocation,
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _TopBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: AppColors.headerBottom),
    ),
  );
}

class _MapCtrlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;
  final bool accent;

  const _MapCtrlBtn({
    required this.icon,
    required this.onTap,
    this.loading = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent ? AppColors.headerBottom : Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child:
          loading
              ? Padding(
                padding: const EdgeInsets.all(11),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accent ? Colors.white : AppColors.headerBottom,
                ),
              )
              : Icon(
                icon,
                size: 20,
                color: accent ? Colors.white : AppColors.headerBottom,
              ),
    ),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const Text(
            'Configuración',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.headerBottom,
            ),
          ),
          const SizedBox(height: 16),
          _Tile(
            icon: Icons.language_outlined,
            label: 'Idioma',
            subtitle: 'Español',
          ),
          _Tile(
            icon: Icons.brightness_6_outlined,
            label: 'Tema',
            subtitle: 'Claro',
          ),
          _Tile(
            icon: Icons.notifications_outlined,
            label: 'Notificaciones',
            subtitle: 'Activadas',
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  const _Tile({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.headerBottom.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.headerBottom),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A94A6)),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: Colors.grey.shade400,
        ),
      ],
    ),
  );
}
