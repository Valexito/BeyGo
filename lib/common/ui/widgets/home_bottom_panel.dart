import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/core.dart';

class HomeBottomPanel extends StatefulWidget {
  const HomeBottomPanel({
    super.key,
    required this.controller,
    required this.onPlaceSelected,
    this.userLocation,
    this.collapseSignal = 0,
  });

  final DraggableScrollableController controller;
  final ValueChanged<LatLng> onPlaceSelected;
  final LatLng? userLocation;
  final int collapseSignal;

  @override
  State<HomeBottomPanel> createState() => _HomeBottomPanelState();
}

class _HomeBottomPanelState extends State<HomeBottomPanel> {
  final GooglePlacesService _placesService = GooglePlacesService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focus = FocusNode();

  List<_PlaceSuggestion> _suggestions = [];
  List<RecentItem> _recents = [];
  Timer? _debounce;
  bool _searching = false;
  bool _hasFocus = false;
  _Category? _activeCategory;

  static const _debounceMs = 320;
  static const _minSize = 0.24;
  static const _midSize = 0.54;
  static const _focusSize = 0.62;
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

  void _clearSearchState() {
    _debounce?.cancel();
    _searchController.clear();
    _focus.unfocus();
    _focus.canRequestFocus = false;
    setState(() {
      _hasFocus = false;
      _suggestions = [];
      _activeCategory = null;
      _searching = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.canRequestFocus = true;
      }
    });
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
      final loc = widget.userLocation;
      debugPrint(
        '[Places] input="$input" '
        'location=${loc?.latitude},${loc?.longitude} '
        'radius=${loc != null ? _nearbyRadiusMeters : 'none'} country=gt',
      );

      final suggestions = await _placesService.autocomplete(
        input: input,
        locationBias: loc,
        radiusMeters: loc != null ? _nearbyRadiusMeters : null,
      );
      if (!mounted) return;
      setState(() {
        _suggestions =
            suggestions
                .map(
                  (s) => _PlaceSuggestion(
                    placeId: s.placeId,
                    mainText: s.mainText,
                    secondaryText: s.secondaryText,
                    fullText: s.fullText,
                    types: s.types,
                  ),
                )
                .toList();
        _searching = false;
      });
      debugPrint('[Places] predictions=${_suggestions.length}');
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
    if (oldWidget.collapseSignal != widget.collapseSignal) {
      _clearSearchState();
    }
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
    _fetchSuggestions(cat.label);
    _animateTo(_focusSize);
  }

  Future<void> _selectSuggestion(_PlaceSuggestion suggestion) async {
    if (suggestion.placeId.isEmpty) return;
    FocusScope.of(context).unfocus();
    _animateTo(_minSize);
    try {
      final loc = await _placesService.fetchPlaceLocation(suggestion.placeId);
      if (!mounted) return;
      if (loc != null) {
        final lat = loc.latitude;
        final lng = loc.longitude;
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

  Color _panelAccent(BuildContext context) {
    return context.isDarkMode ? Colors.white : AppColors.headerBottom;
  }

  Color _panelSecondaryAccent(BuildContext context) {
    return context.isDarkMode
        ? Colors.white.withValues(alpha: 0.72)
        : AppColors.headerBottom.withValues(alpha: 0.7);
  }

  // The active chip background is white in dark mode (see _panelAccent),
  // so a white icon/label on top of it would be invisible — use a dark
  // brand color there instead of the usual white-on-accent foreground.
  Color _panelActiveForeground(BuildContext context) {
    return context.isDarkMode ? AppColors.headerBottom : Colors.white;
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
      snapSizes: const [_minSize, _midSize, _focusSize, _maxSize],
      builder: (context, scrollController) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (widget.controller.isAttached &&
                widget.controller.size <= (_minSize + 0.02)) {
              _animateTo(_midSize);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: context.appSectionBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.12),
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
                    color:
                        context.isDarkMode
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
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
                                      Text(
                                        '¿A dónde vamos?',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: context.appTextPrimaryColor,
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
                                                  ? _panelSecondaryAccent(
                                                    context,
                                                  )
                                                  : context
                                                      .appTextSecondaryColor,
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
                                  color: context.appInputBackground,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color:
                                        _hasFocus
                                            ? _panelAccent(context).withValues(
                                              alpha: 0.55,
                                            )
                                            : context.appBorderColor,
                                    width: _hasFocus ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          _hasFocus
                                              ? _panelAccent(
                                                context,
                                              ).withValues(alpha: 0.10)
                                              : Colors.black.withValues(
                                                alpha: 0.03,
                                              ),
                                      blurRadius: _hasFocus ? 16 : 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _focus,
                                  onTap: () => _animateTo(_focusSize),
                                  onChanged: _onSearchChanged,
                                  textInputAction: TextInputAction.search,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.appTextPrimaryColor,
                                  ),
                                  decoration: InputDecoration(
                                    filled: false,
                                    hintText: 'Teatro, parqueo, hospital...',
                                    hintStyle: TextStyle(
                                      fontSize: 13,
                                      color: context.appTextSecondaryColor,
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
                                                          _panelAccent(
                                                            context,
                                                          ),
                                                    ),
                                              )
                                              : Icon(
                                                Icons.search_rounded,
                                                size: 20,
                                                color:
                                                    _hasFocus
                                                        ? _panelAccent(context)
                                                        : context
                                                            .appTextSecondaryColor,
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
                                                  decoration: BoxDecoration(
                                                    color:
                                                        context.appBorderColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.close_rounded,
                                                    size: 12,
                                                    color:
                                                        context
                                                            .appTextSecondaryColor,
                                                  ),
                                                ),
                                              ),
                                            )
                                            : null,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
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
                                                  ? _panelAccent(context)
                                                  : context.appCardBackground,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color:
                                                active
                                                    ? _panelAccent(context)
                                                    : context.appBorderColor,
                                          ),
                                          boxShadow:
                                              active
                                                  ? [
                                                    BoxShadow(
                                                      color: _panelAccent(
                                                            context,
                                                          )
                                                          .withValues(
                                                            alpha: 0.28,
                                                          ),
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
                                                      ? _panelActiveForeground(
                                                        context,
                                                      )
                                                      : context
                                                          .appTextSecondaryColor,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              cat.label,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    active
                                                        ? _panelActiveForeground(
                                                          context,
                                                        )
                                                        : context
                                                            .appTextPrimaryColor,
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
    final accent =
        context.isDarkMode ? Colors.white : AppColors.headerBottom;
    return Row(
      children: [
        Icon(icon, size: 12, color: accent),
        const SizedBox(width: 5),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: accent,
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
    final effectiveIconColor =
        context.isDarkMode && !isRecent ? Colors.white : iconColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: iconColor.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
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
                    color: effectiveIconColor.withValues(
                      alpha: context.isDarkMode ? 0.12 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: effectiveIconColor, size: 19),
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimaryColor,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.appTextSecondaryColor,
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
                    color: context.appInputBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isRecent
                        ? Icons.north_west_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: isRecent ? 13 : 10,
                    color: context.appTextSecondaryColor,
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
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.appInputBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.explore_outlined,
              size: 26,
              color: context.appTextSecondaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Aún no hay búsquedas',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tus destinos recientes aparecerán aquí',
            style: TextStyle(
              fontSize: 12,
              color: context.appTextSecondaryColor,
            ),
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
