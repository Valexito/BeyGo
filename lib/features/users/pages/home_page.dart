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
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/core.dart';

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

  // Must match HomeBottomPanel.initialChildSize/minChildSize so the floating
  // controls render in the correct position from the very first frame.
  static const double _minSheet = 0.22;
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
    final preferences = ref.watch(appPreferencesProvider);

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
                    builder:
                        (_) => _SettingsSheet(
                          themePreference: preferences.themePreference,
                        ),
                  ),
            ),
          ),

          Positioned(
            top: safeTop + 12,
            left: 72,
            right: 72,
            child: IgnorePointer(
              child: Center(child: _BrandBadge(compact: true)),
            ),
          ),

          // ── Map controls (float above bottom panel) ──────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            right: 12,
            bottom: controlsBottom,
            child: AppMapControls(
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              onMyLocation: _centerOnUser,
              loadingMyLocation: _locatingUser,
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
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.24 : 0.13,
            ),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: context.appTextPrimaryColor),
    ),
  );
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: context.appCardBackground.withValues(
          alpha: context.isDarkMode ? 0.94 : 0.97,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.22 : 0.10,
            ),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 30 : 36,
            height: compact ? 30 : 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              image: const DecorationImage(
                image: AssetImage('assets/branding/icon.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BeyGo',
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: context.appTextPrimaryColor,
                ),
              ),
              if (!compact)
                Text(
                  'Tu ruta al parqueo',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextSecondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet({required this.themePreference});

  final AppThemePreference themePreference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);
    return Container(
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: context.appBorderColor),
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
              color: context.appBorderColor,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Text(
            'Configuración',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          _Tile(
            icon: Icons.brightness_6_outlined,
            label: 'Tema',
            subtitle: _themeLabel(preferences.themePreference),
            onTap: () => _showHomeThemePicker(context, ref),
          ),
          _Tile(
            icon: Icons.notifications_outlined,
            label: 'Notificaciones',
            subtitle:
                preferences.notificationsEnabled ? 'Activadas' : 'Desactivadas',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConfigurationsPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback? onTap;
  const _Tile({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.appIconCircleColor,
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimaryColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.appTextSecondaryColor,
            ),
          ],
        ),
      ),
    ),
  );
}

String _themeLabel(AppThemePreference preference) {
  switch (preference) {
    case AppThemePreference.system:
      return 'Sistema';
    case AppThemePreference.light:
      return 'Claro';
    case AppThemePreference.dark:
      return 'Oscuro';
  }
}

Future<void> _showHomeThemePicker(BuildContext context, WidgetRef ref) async {
  final current = ref.read(appPreferencesProvider).themePreference;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Container(
        decoration: BoxDecoration(
          color: sheetContext.appCardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: sheetContext.appBorderColor),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetContext.appBorderColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Selecciona un tema',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: sheetContext.appTextPrimaryColor,
              ),
            ),
            const SizedBox(height: 14),
            ...AppThemePreference.values.map((option) {
              final selected = option == current;
              return ListTile(
                tileColor:
                    selected
                        ? AppColors.headerBottom.withValues(
                          alpha: sheetContext.isDarkMode ? 0.16 : 0.08,
                        )
                        : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  switch (option) {
                    AppThemePreference.system => Icons.brightness_auto_rounded,
                    AppThemePreference.light => Icons.light_mode_rounded,
                    AppThemePreference.dark => Icons.dark_mode_rounded,
                  },
                  color:
                      selected
                          ? AppColors.headerBottom
                          : sheetContext.appTextPrimaryColor,
                ),
                title: Text(
                  _themeLabel(option),
                  style: TextStyle(color: sheetContext.appTextPrimaryColor),
                ),
                trailing:
                    selected
                        ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.headerBottom,
                        )
                        : null,
                onTap: () async {
                  await ref
                      .read(appPreferencesProvider.notifier)
                      .setThemePreference(option);
                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              );
            }),
          ],
        ),
      );
    },
  );
}
