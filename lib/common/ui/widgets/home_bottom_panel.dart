import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart' show AppColors;
import 'package:mapbox_api/common/ui/components/my_textfield.dart';
import 'package:mapbox_api/common/env/env.dart';
import 'package:mapbox_api/features/core/services/recent_searches.dart';

class HomeBottomPanel extends StatefulWidget {
  const HomeBottomPanel({
    super.key,
    required this.controller,
    required this.onPlaceSelected,
  });

  final DraggableScrollableController controller;

  /// Called when a place is chosen — returns Google Maps LatLng
  final ValueChanged<LatLng> onPlaceSelected;

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

  static const _debounceMs = 350;
  static const _minSize = 0.22;
  static const _maxSize = 0.72;

  @override
  void initState() {
    super.initState();
    _loadRecents();
    _focus.addListener(() {
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
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: _debounceMs),
      () => _fetchSuggestions(value),
    );
  }

  // ── Google Places Autocomplete ─────────────────────────────────────────────
  Future<void> _fetchSuggestions(String input) async {
    final q = input.trim();
    if (q.isEmpty) return;

    setState(() => _searching = true);

    try {
      // Use Google Places Autocomplete REST API
      // Key should be stored in Env class (--dart-define=GOOGLE_MAPS_KEY=...)
      final apiKey = Env.googleMapsKey; // add this to your Env class
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': q,
          'key': apiKey,
          'language': 'es',
          'components': 'country:gt', // bias to Guatemala; remove for global
          'types': 'geocode|establishment',
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final predictions = (data['predictions'] as List?) ?? [];

        setState(() {
          _suggestions =
              predictions
                  .map(
                    (p) => _PlaceSuggestion(
                      placeId: p['place_id'] ?? '',
                      mainText:
                          (p['structured_formatting']?['main_text']
                              as String?) ??
                          (p['description'] ?? ''),
                      secondaryText:
                          (p['structured_formatting']?['secondary_text']
                              as String?) ??
                          '',
                      fullText: p['description'] ?? '',
                    ),
                  )
                  .toList();
          _searching = false;
        });
      } else {
        setState(() {
          _suggestions = [];
          _searching = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _searching = false;
      });
    }
  }

  // ── Get LatLng from Place ID ───────────────────────────────────────────────
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

      final response = await http.get(uri).timeout(const Duration(seconds: 6));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final location =
            data['result']?['geometry']?['location'] as Map<String, dynamic>?;

        if (location != null) {
          final lat = (location['lat'] as num).toDouble();
          final lng = (location['lng'] as num).toDouble();
          final target = LatLng(lat, lng);

          widget.onPlaceSelected(target);

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
    setState(() => _suggestions = []);
  }

  // ── Select from recents ───────────────────────────────────────────────────
  void _selectRecent(RecentItem r) {
    widget.onPlaceSelected(LatLng(r.lat, r.lng));
    _animateTo(_minSize);
    FocusScope.of(context).unfocus();
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.headerBottom,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _resultCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSoft),
              boxShadow: [
                BoxShadow(
                  color: AppColors.headerBottom.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
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
                          color: Color(0xFF1E293B),
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
                            color: Color(0xFF8A94A6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 28,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 8),
          Text(
            'Sin búsquedas recientes',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSuggestions = _suggestions.isNotEmpty;

    return DraggableScrollableSheet(
      controller: widget.controller,
      initialChildSize: _minSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      builder: (context, scrollController) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _animateTo(_maxSize),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(34),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.headerBottom.withOpacity(0.10),
                  blurRadius: 18,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle
                const SizedBox(height: 10),
                Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: AppColors.borderSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        const Text(
                          'Buscar destino',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.headerBottom,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Search field
                        MyTextField(
                          controller: _searchController,
                          hintText: '¿A dónde quieres ir?',
                          keyboardType: TextInputType.text,
                          prefixIcon: Icons.search_rounded,
                          onChanged: _onSearchChanged,
                          margin: EdgeInsets.zero,
                          focusNode: _focus,
                          suffix:
                              _searchController.text.isNotEmpty
                                  ? IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: Colors.grey.shade400,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _suggestions = []);
                                    },
                                  )
                                  : null,
                        ),
                        const SizedBox(height: 18),

                        // Loading indicator
                        if (_searching)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.headerBottom,
                                ),
                              ),
                            ),
                          )
                        // Suggestions (Google Places)
                        else if (hasSuggestions) ...[
                          _sectionTitle('Sugerencias'),
                          ..._suggestions.map(
                            (s) => _resultCard(
                              icon: Icons.place_outlined,
                              iconColor: AppColors.headerBottom,
                              title: s.mainText,
                              subtitle: s.secondaryText,
                              onTap: () => _selectSuggestion(s),
                            ),
                          ),
                        ]
                        // Recents
                        else ...[
                          _sectionTitle('Recientes'),
                          if (_recents.isEmpty)
                            _emptyState()
                          else
                            ..._recents.map(
                              (r) => _resultCard(
                                icon: Icons.history_rounded,
                                iconColor: AppColors.textSecondary,
                                title: r.name,
                                subtitle: r.address,
                                onTap: () => _selectRecent(r),
                              ),
                            ),
                        ],
                      ],
                    ),
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

// ─── Model ─────────────────────────────────────────────────────────────────
class _PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;

  const _PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
  });
}
