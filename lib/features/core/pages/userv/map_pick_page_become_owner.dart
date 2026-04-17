import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_api/common/env/env.dart';
import 'package:mapbox_api/features/reservations/services/geolocator.dart';
import 'package:mapbox_api/common/components/ui/app_styles.dart';
import 'package:mapbox_api/common/components/ui/my_text.dart';

class MapPickPage extends StatefulWidget {
  const MapPickPage({super.key});

  @override
  State<MapPickPage> createState() => _MapPickPageState();
}

class _MapPickPageState extends State<MapPickPage> {
  final _map = MapController();
  LatLng? _center;
  LatLng? _picked;
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
      if (_focusNode.hasFocus) {
        setState(() => _isActive = true);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final here = await getCurrentLocation();
      setState(() => _center = here);
    } catch (_) {
      setState(() => _center = LatLng(14.834999, -91.518669));
    }
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

    final token = Env.mapboxToken;
    if (token.isEmpty) return;

    final uri = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(q)}.json'
      '?access_token=$token&autocomplete=true&limit=5',
    );

    try {
      final res = await http.get(uri);
      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final features = data['features'] as List;

        setState(() {
          _suggestions =
              features.map<Map<String, dynamic>>((f) {
                return {
                  'name': f['text'],
                  'place': f['place_name'],
                  'coords': f['center'],
                };
              }).toList();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _suggestions = []);
    }
  }

  void _selectSuggestion(Map<String, dynamic> s) {
    final coords = s['coords'];
    final target = LatLng(coords[1], coords[0]);

    setState(() {
      _picked = target;
      _suggestions = [];
      _searchController.clear();
      FocusScope.of(context).unfocus();
      _isActive = false;
    });

    // Move slightly up so marker is visible above bottom panel
    final adjusted = LatLng(target.latitude + 0.0015, target.longitude);
    _map.move(adjusted, 17);
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
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _center!,
                initialZoom: 16,
                onTap: (tapPos, latlng) {
                  _collapseUI();
                  setState(() => _picked = latlng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=${Env.mapboxToken}',
                  userAgentPackageName: 'com.example.mapbox_api',
                  tileSize: 256,
                  maxZoom: 19,
                ),
                if (_picked != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _picked!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // BUBBLES (decorative like other screens)
          Positioned(
            top: 40,
            left: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
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
                color: Colors.white.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // HEADER (overlay, does NOT block map)
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
              decoration: BoxDecoration(
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
                  _map.move(_map.camera.center, _map.camera.zoom + 1);
                }),
                const SizedBox(height: 10),
                _mapButton(Icons.remove, () {
                  _map.move(_map.camera.center, _map.camera.zoom - 1);
                }),
                const SizedBox(height: 10),
                _mapButton(Icons.my_location, () async {
                  try {
                    final here = await getCurrentLocation();
                    _map.move(here, 17);
                    setState(() => _picked = here);
                  } catch (_) {}
                }),
              ],
            ),
          ),

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
                      if (!_isActive) {
                        setState(() => _isActive = true);
                      }
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
                        color: Colors.black.withOpacity(0.08),
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
                          if (!_isActive) {
                            setState(() => _isActive = true);
                          }
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
                                if (!_isActive) {
                                  setState(() => _isActive = true);
                                }
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
