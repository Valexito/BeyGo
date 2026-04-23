// lib/features/core/pages/map_picker_page.dart
//
// ─── MIGRATION LOG ───────────────────────────────────────────────────────────
//  v2 — Migrated from flutter_map + Mapbox tiles → google_maps_flutter
//  • Tap to place pin (same UX as before)
//  • Search bar with Google Places Autocomplete
//  • Confirm button returns LatLng
//  • Consistent UI with the rest of the app
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapbox_api/common/services/geolocator.dart';
import 'package:mapbox_api/common/services/google_places_service.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/google_map_styles.dart';
import 'package:mapbox_api/common/ui/components/my_button.dart';
import 'package:mapbox_api/common/ui/components/navy_header.dart';
import 'package:mapbox_api/common/ui/widgets/app_map_controls.dart';

class MapPickerPage extends StatefulWidget {
  /// Optional initial position. Defaults to Xela, Guatemala.
  final LatLng? initialPosition;
  final String title;

  const MapPickerPage({
    super.key,
    this.initialPosition,
    this.title = 'Selecciona ubicación',
  });

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final GooglePlacesService _placesService = GooglePlacesService();
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<_Suggestion> _suggestions = [];
  Timer? _debounce;
  bool _showSuggestions = false;
  bool _locating = false;

  static final LatLng _defaultCenter = const LatLng(14.8349, -91.5186); // Xela

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Google Places search ───────────────────────────────────────────────────
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final predictions = await _placesService.autocomplete(
          input: value.trim(),
          locationBias: _selectedPosition ?? widget.initialPosition,
        );
        if (!mounted) return;
        setState(() {
          _suggestions =
              predictions
                  .map(
                    (p) => _Suggestion(
                      placeId: p.placeId,
                      mainText: p.mainText,
                      secondaryText: p.secondaryText,
                    ),
                  )
                  .toList();
          _showSuggestions = _suggestions.isNotEmpty;
        });
      } catch (_) {}
    });
  }

  Future<void> _selectSuggestion(_Suggestion s) async {
    _searchFocus.unfocus();
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });

    try {
      final target = await _placesService.fetchPlaceLocation(s.placeId);
      if (!mounted) return;
      if (target != null) {
        setState(() => _selectedPosition = target);
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: target, zoom: 16),
          ),
        );
        _searchCtrl.text = s.mainText;
      }
    } catch (_) {}
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _selectedPosition = position;
      _showSuggestions = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _confirm() {
    if (_selectedPosition != null) {
      Navigator.pop(context, _selectedPosition);
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final loc = await getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _selectedPosition = loc;
        _showSuggestions = false;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: loc, zoom: 16)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pudimos obtener tu ubicación: $e')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialPosition ?? _defaultCenter;

    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: Column(
        children: [
          // ── Header ──
          AppGradientHeader(
            title: widget.title,
            subtitle: 'Toca el mapa o busca una dirección',
            showBack: true,
          ),

          // ── Map + controls ──
          Expanded(
            child: Stack(
              children: [
                // Map
                GoogleMap(
                  onMapCreated: (c) => _mapController = c,
                  initialCameraPosition: CameraPosition(
                    target: initial,
                    zoom: 15,
                  ),
                  onTap: _onMapTap,
                  markers:
                      _selectedPosition == null
                          ? {}
                          : {
                            Marker(
                              markerId: const MarkerId('selected'),
                              position: _selectedPosition!,
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueAzure,
                              ),
                            ),
                          },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  style: GoogleMapStyles.forBrightness(
                    Theme.of(context).brightness,
                  ),
                ),

                // ── Search bar ──
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      _SearchBar(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        onChanged: _onSearchChanged,
                        onClear: () {
                          _searchCtrl.clear();
                          setState(() {
                            _suggestions = [];
                            _showSuggestions = false;
                          });
                        },
                      ),

                      // Suggestion dropdown
                      if (_showSuggestions && _suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: context.appCardBackground,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.headerBottom.withValues(
                                  alpha: 0.12,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children:
                                _suggestions.map((s) {
                                  return InkWell(
                                    onTap: () => _selectSuggestion(s),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color:
                                                  context.appIconCircleColor,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                            child: const Icon(
                                              Icons.place_outlined,
                                              size: 16,
                                              color: AppColors.headerBottom,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  s.mainText,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        context
                                                            .appTextPrimaryColor,
                                                  ),
                                                ),
                                                if (s.secondaryText.isNotEmpty)
                                                  Text(
                                                    s.secondaryText,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          context
                                                              .appTextSecondaryColor,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── Zoom controls ──
                Positioned(
                  right: 12,
                  bottom: 120,
                  child: AppMapControls(
                    onZoomIn:
                        () =>
                            _mapController?.animateCamera(CameraUpdate.zoomIn()),
                    onZoomOut:
                        () => _mapController?.animateCamera(
                          CameraUpdate.zoomOut(),
                        ),
                    onMyLocation: _goToCurrentLocation,
                    loadingMyLocation: _locating,
                  ),
                ),

                // ── Confirm button ──
                if (_selectedPosition != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: MyButton(
                      text: 'Confirmar ubicación',
                      icon: Icons.check_rounded,
                      onTap: _confirm,
                      margin: EdgeInsets.zero,
                    ),
                  ),

                // ── Hint when nothing selected ──
                if (_selectedPosition == null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: context.appCardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.appBorderColor),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.headerBottom.withValues(
                              alpha: 0.08,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 18,
                            color: context.appTextSecondaryColor,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Toca el mapa para marcar la ubicación',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.appTextSecondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search bar widget ──────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.appTextPrimaryColor,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar dirección...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: context.appTextSecondaryColor,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.headerBottom,
            size: 20,
          ),
          suffixIcon:
              controller.text.isNotEmpty
                  ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade400,
                    ),
                    onPressed: onClear,
                  )
                  : null,
          filled: true,
          fillColor: context.appCardBackground,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ─── Suggestion model ───────────────────────────────────────────────────────
class _Suggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;

  const _Suggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
}
