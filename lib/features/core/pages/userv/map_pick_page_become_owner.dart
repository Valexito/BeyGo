import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapbox_api/common/env/env.dart';
import 'package:mapbox_api/common/services/geolocator.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_text.dart';

class MapPickPage extends StatefulWidget {
  const MapPickPage({super.key});

  @override
  State<MapPickPage> createState() => _MapPickPageState();
}

class _MapPickPageState extends State<MapPickPage> {
  GoogleMapController? _mapController;
  LatLng? _center;
  LatLng? _picked;
  Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _isActive = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _init();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) setState(() => _isActive = true);
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final here = await getCurrentLocation();
      setState(() => _center = here);
    } catch (_) {
      setState(() => _center = const LatLng(14.834999, -91.518669));
    }
  }

  void _setPickedLocation(LatLng latlng) {
    setState(() {
      _picked = latlng;
      _markers = {
        Marker(
          markerId: const MarkerId('picked'),
          position: latlng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(value);
    });
  }

  Future<void> _fetchSuggestions(String value) async {
    final q = value.trim();
    if (q.length < 3) {
      if (!mounted) return;
      setState(() => _suggestions = []);
      return;
    }

    final key = Env.googleMapsKey;
    if (key.isEmpty) return;

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(q)}&key=$key&language=es',
    );

    try {
      final res = await http.get(uri);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final predictions = data['predictions'] as List;
        setState(() {
          _suggestions =
              predictions.map<Map<String, dynamic>>((p) {
                return {
                  'name':
                      (p['structured_formatting']?['main_text'] ??
                          p['description']) as String,
                  'place': p['description'] as String,
                  'place_id': p['place_id'] as String,
                };
              }).toList();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _suggestions = []);
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> s) async {
    final key = Env.googleMapsKey;
    final placeId = s['place_id'] as String;

    setState(() {
      _suggestions = [];
      _searchController.clear();
      FocusScope.of(context).unfocus();
      _isActive = false;
    });

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${Uri.encodeComponent(placeId)}&fields=geometry&key=$key',
      );
      final res = await http.get(uri);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final loc = data['result']['geometry']['location'];
        final target = LatLng(loc['lat'] as double, loc['lng'] as double);
        _setPickedLocation(target);
        final adjusted = LatLng(target.latitude + 0.0015, target.longitude);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(adjusted, 17));
      }
    } catch (_) {}
  }

  void _collapseUI() {
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _isActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_center == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: (ctrl) => _mapController = ctrl,
              initialCameraPosition: CameraPosition(target: _center!, zoom: 16),
              onTap: (latlng) {
                _collapseUI();
                _setPickedLocation(latlng);
              },
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            ),
          ),

          // Decorative bubbles
          Positioned(
            top: 40,
            left: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: -10,
            right: -10,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 12,
                16,
                12,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.headerTop, AppColors.headerBottom],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                      ),
                      label: const Text('Regresar'),
                    ),
                    const Spacer(),
                    const MyText(
                      text: 'Busca tu ubicación',
                      variant: MyTextVariant.subtitle,
                      customColor: Colors.white,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed:
                          _picked == null
                              ? null
                              : () => Navigator.pop(context, _picked),
                      child: const Text(
                        'Usar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Zoom / my-location buttons
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            right: 12,
            bottom:
                (_isActive || _suggestions.isNotEmpty)
                    ? MediaQuery.of(context).viewInsets.bottom + 320
                    : 180,
            child: Column(
              children: [
                _mapButton(Icons.add, () {
                  _mapController?.animateCamera(CameraUpdate.zoomIn());
                }),
                const SizedBox(height: 10),
                _mapButton(Icons.remove, () {
                  _mapController?.animateCamera(CameraUpdate.zoomOut());
                }),
                const SizedBox(height: 10),
                _mapButton(Icons.my_location, () async {
                  try {
                    final here = await getCurrentLocation();
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(here, 17),
                    );
                    _setPickedLocation(here);
                  } catch (_) {}
                }),
              ],
            ),
          ),

          // Bottom search panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            left: 0,
            right: 0,
            bottom: 0,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      if (!_isActive) setState(() => _isActive = true);
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (!_isActive) setState(() => _isActive = true);
                          _focusNode.requestFocus();
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            height: 5,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _searchController,
                              focusNode: _focusNode,
                              onChanged: (v) {
                                if (!_isActive) setState(() => _isActive = true);
                                _onSearchChanged(v);
                              },
                              decoration: InputDecoration(
                                hintText: 'Buscar ubicación...',
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: AppColors.headerBottom,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                              ),
                            ),
                            if (_suggestions.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                child: ListView(
                                  shrinkWrap: true,
                                  children:
                                      _suggestions.map((s) {
                                        return ListTile(
                                          leading: Icon(
                                            Icons.place,
                                            color: AppColors.headerBottom,
                                          ),
                                          title: Text(s['name']),
                                          subtitle: Text(s['place']),
                                          onTap: () => _selectSuggestion(s),
                                        );
                                      }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 24, color: AppColors.headerBottom),
        ),
      ),
    );
  }
}
