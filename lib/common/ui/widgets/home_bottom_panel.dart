// lib/features/core/widgets/home_bottom_panel.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart' show AppColors;
import 'package:mapbox_api/common/env/env.dart';
import 'package:mapbox_api/features/core/services/recent_searches.dart';

class HomeBottomPanel extends StatefulWidget {
  const HomeBottomPanel({
    super.key,
    required this.controller,
    required this.onPlaceSelected,
    this.userLocation,
  });

  final DraggableScrollableController controller;
  final ValueChanged<LatLng> onPlaceSelected;

  /// ✅ Pass this from the parent (HomeScreen/MapPage) using your existing
  /// getCurrentLocation() service. The widget uses it to bias Places results
  /// nearby — no duplicate permission requests.
  ///
  /// Example in parent:
  ///   LatLng? _userLocation;
  ///   void initState() {
  ///     getCurrentLocation().then((loc) => setState(() => _userLocation = loc));
  ///   }
  ///   // then in build:
  ///   HomeBottomPanel(userLocation: _userLocation, ...)
  final LatLng? userLocation;

  @override
  State<HomeBottomPanel> createState() => _HomeBottomPanelState();
}

class _HomeBottomPanelState extends State<HomeBottomPanel> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focus = FocusNode();

  List<_PlaceSuggestion> _suggestions = [];
  List<RecentItem> _recents = [];
  Timer? _debounce;
  bool _searching = false;
  bool _hasFocus = false;
  _Category? _activeCategory;

  static const _debounceMs = 320;
  static const _minSize = 0.22;
  static const _maxSize = 0.80;
  static const _nearbyRadiusMeters = 25000;

  static const _categories = [
    _Category('Parqueos', Icons.local_parking_rounded),
    _Category('Restaurantes', Icons.restaurant_rounded),
    _Category('Teatros', Icons.theaters_rounded),
    _Category('Bancos', Icons.account_balance_rounded),
    _Category('Hospitales', Icons.local_hospital_rounded),
    _Category('Farmacias', Icons.local_pharmacy_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadRecents();
    _focus.addListener(() {
      setState(() => _hasFocus = _focus.hasFocus);
      if (_focus.hasFocus) _animateTo(_maxSize);
    });
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _loadRecents() async {
    final items = await RecentSearches.load();
    if (!mounted) return;
    setState(() => _recents = items);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _animateTo(double size) {
    widget.controller.animateTo(
      size,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (_activeCategory != null) setState(() => _activeCategory = null);
    if (value.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: _debounceMs),
      () => _fetchSuggestions(value.trim()),
    );
  }

  // ── Google Places Autocomplete with location bias ──────────────────────────
  Future<void> _fetchSuggestions(String input) async {
    if (input.isEmpty) return;
    setState(() => _searching = true);
    try {
      final apiKey = Env.googleMapsKey;

      final params = <String, String>{
        'input': input,
        'key': apiKey,
        'language': 'es',
        'types': 'establishment|geocode',
        'components': 'country:gt',
        'region': 'gt',
      };

      // Restrict to Guatemala and bias results around the user's real location.
      final loc = widget.userLocation;
      if (loc != null) {
        params['location'] = '${loc.latitude},${loc.longitude}';
        params['radius'] = '$_nearbyRadiusMeters';
      }

      debugPrint(
        '[Places] input="$input" '
        'location=${loc?.latitude},${loc?.longitude} '
        'radius=${loc != null ? _nearbyRadiusMeters : 'none'} '
        'components=${params['components']}',
      );

      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        params,
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';
        if (status != 'OK' && status != 'ZERO_RESULTS') {
          debugPrint(
            '[Places] Error: $status — ${data['error_message'] ?? ''}',
          );
        }
        final predictions = (data['predictions'] as List?) ?? [];
        setState(() {
          _suggestions =
              predictions.map((p) {
                final sf = p['structured_formatting'] as Map<String, dynamic>?;
                final types = (p['types'] as List?)?.cast<String>() ?? [];
                return _PlaceSuggestion(
                  placeId: p['place_id'] ?? '',
                  mainText:
                      (sf?['main_text'] as String?) ?? (p['description'] ?? ''),
                  secondaryText: (sf?['secondary_text'] as String?) ?? '',
                  fullText: p['description'] ?? '',
                  types: types,
                );
              }).toList();
          _searching = false;
        });
        debugPrint(
          '[Places] status=$status predictions=${_suggestions.length}',
        );
      } else {
        setState(() {
          _suggestions = [];
          _searching = false;
        });
      }
    } catch (e) {
      debugPrint('[Places] Exception: $e');
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _searching = false;
      });
    }
  }

  @override
  void didUpdateWidget(covariant HomeBottomPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLoc = oldWidget.userLocation;
    final newLoc = widget.userLocation;
    if (oldLoc?.latitude != newLoc?.latitude ||
        oldLoc?.longitude != newLoc?.longitude) {
      debugPrint(
        '[Places] userLocation updated to '
        '${newLoc?.latitude},${newLoc?.longitude}',
      );
    }
  }

  void _onCategoryTap(_Category cat) {
    if (_activeCategory?.label == cat.label) {
      setState(() {
        _activeCategory = null;
        _suggestions = [];
      });
      _searchController.clear();
      return;
    }
    setState(() => _activeCategory = cat);
    _searchController.text = cat.label;
    _animateTo(_maxSize);
    _fetchSuggestions(cat.label);
  }

  Future<void> _selectSuggestion(_PlaceSuggestion suggestion) async {
    if (suggestion.placeId.isEmpty) return;
    FocusScope.of(context).unfocus();
    _animateTo(_minSize);
    try {
      final apiKey = Env.googleMapsKey;
      final uri =
          Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
            'place_id': suggestion.placeId,
            'key': apiKey,
            'fields': 'geometry,name,formatted_address',
          });
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final loc =
            data['result']?['geometry']?['location'] as Map<String, dynamic>?;
        if (loc != null) {
          final lat = (loc['lat'] as num).toDouble();
          final lng = (loc['lng'] as num).toDouble();
          widget.onPlaceSelected(LatLng(lat, lng));
          await RecentSearches.add(
            RecentItem(
              name: suggestion.mainText,
              address: suggestion.fullText,
              lat: lat,
              lng: lng,
            ),
          );
          await _loadRecents();
        }
      }
    } catch (_) {}
    _searchController.clear();
    setState(() {
      _suggestions = [];
      _activeCategory = null;
    });
  }

  void _selectRecent(RecentItem r) {
    widget.onPlaceSelected(LatLng(r.lat, r.lng));
    _animateTo(_minSize);
    FocusScope.of(context).unfocus();
  }

  IconData _iconFor(List<String> types) {
    if (types.any((t) => t.contains('parking')))
      return Icons.local_parking_rounded;
    if (types.any((t) => t.contains('restaurant') || t.contains('food')))
      return Icons.restaurant_rounded;
    if (types.any((t) => t.contains('theater') || t.contains('cinema')))
      return Icons.theaters_rounded;
    if (types.any((t) => t.contains('hospital') || t.contains('health')))
      return Icons.local_hospital_rounded;
    if (types.any((t) => t.contains('bank') || t.contains('finance')))
      return Icons.account_balance_rounded;
    if (types.any((t) => t.contains('pharmacy')))
      return Icons.local_pharmacy_rounded;
    if (types.any((t) => t.contains('school') || t.contains('university')))
      return Icons.school_rounded;
    if (types.any((t) => t.contains('store') || t.contains('shop')))
      return Icons.shopping_bag_rounded;
    if (types.any((t) => t.contains('gas_station')))
      return Icons.local_gas_station_rounded;
    if (types.any((t) => t.contains('lodging') || t.contains('hotel')))
      return Icons.hotel_rounded;
    if (types.any((t) => t.contains('route') || t.contains('street_address')))
      return Icons.fork_right_rounded;
    return Icons.place_rounded;
  }

  Color _colorFor(List<String> types) {
    if (types.any((t) => t.contains('parking'))) return const Color(0xFF2563EB);
    if (types.any((t) => t.contains('restaurant') || t.contains('food')))
      return const Color(0xFFEA580C);
    if (types.any((t) => t.contains('hospital') || t.contains('health')))
      return const Color(0xFF16A34A);
    if (types.any((t) => t.contains('bank'))) return const Color(0xFF7C3AED);
    if (types.any((t) => t.contains('theater'))) return const Color(0xFFDB2777);
    if (types.any((t) => t.contains('pharmacy')))
      return const Color(0xFF0891B2);
    return AppColors.headerBottom;
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = widget.userLocation != null;

    return DraggableScrollableSheet(
      controller: widget.controller,
      initialChildSize: _minSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: const [_minSize, 0.50, _maxSize],
      builder: (context, scrollController) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _animateTo(_maxSize),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.headerTop,
                                          AppColors.headerBottom,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.navigation_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '¿A dónde vamos?',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      Text(
                                        hasLocation
                                            ? 'Mostrando resultados cercanos'
                                            : 'Busca un lugar o toca en el mapa',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              hasLocation
                                                  ? AppColors.headerBottom
                                                      .withOpacity(0.7)
                                                  : const Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Search field
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color:
                                        _hasFocus
                                            ? AppColors.headerBottom
                                                .withOpacity(0.55)
                                            : const Color(0xFFE2E8F0),
                                    width: _hasFocus ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          _hasFocus
                                              ? AppColors.headerBottom
                                                  .withOpacity(0.10)
                                              : Colors.black.withOpacity(0.03),
                                      blurRadius: _hasFocus ? 16 : 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _focus,
                                  onChanged: _onSearchChanged,
                                  textInputAction: TextInputAction.search,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Teatro, parqueo, hospital...',
                                    hintStyle: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.all(13),
                                      child:
                                          _searching
                                              ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color:
                                                          AppColors
                                                              .headerBottom,
                                                    ),
                                              )
                                              : Icon(
                                                Icons.search_rounded,
                                                size: 20,
                                                color:
                                                    _hasFocus
                                                        ? AppColors.headerBottom
                                                        : const Color(
                                                          0xFF94A3B8,
                                                        ),
                                              ),
                                    ),
                                    suffixIcon:
                                        _searchController.text.isNotEmpty
                                            ? GestureDetector(
                                              onTap: () {
                                                _searchController.clear();
                                                setState(() {
                                                  _suggestions = [];
                                                  _activeCategory = null;
                                                });
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    3,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Color(
                                                          0xFFE2E8F0,
                                                        ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close_rounded,
                                                    size: 12,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                            )
                                            : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Category chips
                              SizedBox(
                                height: 36,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _categories.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (_, i) {
                                    final cat = _categories[i];
                                    final active =
                                        _activeCategory?.label == cat.label;
                                    return GestureDetector(
                                      onTap: () => _onCategoryTap(cat),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              active
                                                  ? AppColors.headerBottom
                                                  : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color:
                                                active
                                                    ? AppColors.headerBottom
                                                    : const Color(0xFFE2E8F0),
                                          ),
                                          boxShadow:
                                              active
                                                  ? [
                                                    BoxShadow(
                                                      color: AppColors
                                                          .headerBottom
                                                          .withOpacity(0.28),
                                                      blurRadius: 10,
                                                      offset: const Offset(
                                                        0,
                                                        3,
                                                      ),
                                                    ),
                                                  ]
                                                  : [],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              cat.icon,
                                              size: 13,
                                              color:
                                                  active
                                                      ? Colors.white
                                                      : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              cat.label,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    active
                                                        ? Colors.white
                                                        : const Color(
                                                          0xFF475569,
                                                        ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),

                      // Section label
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        sliver: SliverToBoxAdapter(
                          child:
                              _suggestions.isNotEmpty
                                  ? _SectionLabel(
                                    icon: Icons.place_rounded,
                                    label:
                                        _activeCategory?.label ?? 'Sugerencias',
                                  )
                                  : const _SectionLabel(
                                    icon: Icons.history_rounded,
                                    label: 'Recientes',
                                  ),
                        ),
                      ),

                      // Results
                      if (_suggestions.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((_, i) {
                              final s = _suggestions[i];
                              return _ResultTile(
                                icon: _iconFor(s.types),
                                iconColor: _colorFor(s.types),
                                title: s.mainText,
                                subtitle: s.secondaryText,
                                onTap: () => _selectSuggestion(s),
                              );
                            }, childCount: _suggestions.length),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          sliver:
                              _recents.isEmpty
                                  ? SliverToBoxAdapter(child: _EmptyRecents())
                                  : SliverList(
                                    delegate: SliverChildBuilderDelegate((
                                      _,
                                      i,
                                    ) {
                                      final r = _recents[i];
                                      return _ResultTile(
                                        icon: Icons.history_rounded,
                                        iconColor: const Color(0xFF64748B),
                                        title: r.name,
                                        subtitle: r.address,
                                        onTap: () => _selectRecent(r),
                                        isRecent: true,
                                      );
                                    }, childCount: _recents.length),
                                  ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Supporting widgets ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.headerBottom),
        const SizedBox(width: 5),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.headerBottom,
            letterSpacing: 0.9,
          ),
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isRecent;

  const _ResultTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isRecent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: iconColor.withOpacity(0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE9EFF6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: iconColor, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isRecent
                        ? Icons.north_west_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: isRecent ? 13 : 10,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRecents extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EFF6)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.explore_outlined,
              size: 26,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Aún no hay búsquedas',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tus destinos recientes aparecerán aquí',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class _PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;
  final List<String> types;

  const _PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
    required this.types,
  });
}

class _Category {
  final String label;
  final IconData icon;
  const _Category(this.label, this.icon);
}
