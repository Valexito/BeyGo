// lib/features/core/components/map_widget.dart
//
// ✅ MapWidgetState is PUBLIC — GlobalKey<MapWidgetState> works from home_page.dart
// ✅ No rxdart, no flutter_map, no latlong2, no Mapbox
// ✅ Real-time parking markers from allParkingsStreamProvider
// ✅ Tap marker → HomeParkingDetailBottomSheet → full reservation flow
//
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:mapbox_api/common/services/geolocator.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/google_map_styles.dart';
import 'package:mapbox_api/features/core/components/home_bottom_parking_details.dart';
import 'package:mapbox_api/features/core/services/favorite_service.dart';
import 'package:mapbox_api/features/reservations/models/parking.dart';
import 'package:mapbox_api/features/reservations/providers/parking_service_provider.dart';

class MapWidget extends ConsumerStatefulWidget {
  /// Called when the user taps the map background (not a marker).
  final VoidCallback? onMapTap;

  /// Exposes the GoogleMapController to the parent once the map is ready.
  final void Function(GoogleMapController)? onMapCreated;

  /// Notifies the parent whenever we resolve the user's location.
  final ValueChanged<LatLng>? onUserLocationChanged;

  const MapWidget({
    super.key,
    this.onMapTap,
    this.onMapCreated,
    this.onUserLocationChanged,
  });

  @override
  // ✅ PUBLIC state class — required so home_page.dart can do:
  //    final _mapKey = GlobalKey<MapWidgetState>();
  //    _mapKey.currentState?.centerOnUser();
  MapWidgetState createState() => MapWidgetState();
}

/// Public state class — intentionally named without underscore so it can be
/// referenced as a type argument in GlobalKey<MapWidgetState> from other files.
class MapWidgetState extends ConsumerState<MapWidget> {
  GoogleMapController? _mapController;
  LatLng? _currentPosition;

  static const LatLng _fallback = LatLng(14.834999, -91.518669); // Xela

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      // getCurrentLocation() returns google_maps_flutter.LatLng ✅
      final pos = await getCurrentLocation();
      if (!mounted) return;
      setState(() => _currentPosition = pos);
      widget.onUserLocationChanged?.call(pos);
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 15)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _currentPosition = _fallback);
      widget.onUserLocationChanged?.call(_fallback);
    }
  }

  // ── Build markers ─────────────────────────────────────────────────────────
  Set<Marker> _buildMarkers(List<Parking> parkings) {
    return parkings.map((p) {
      return Marker(
        markerId: MarkerId('parking_${p.id}'),
        position: LatLng(p.lat, p.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: p.name,
          snippet: 'Q${p.price}/hora · Toca para ver',
        ),
        onTap: () => _showParkingDetails(p),
      );
    }).toSet();
  }

  // ── Parking detail sheet ──────────────────────────────────────────────────
  // Uses nested StreamBuilder instead of rxdart switchMap ✅
  void _showParkingDetails(Parking parking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        bool? localFav;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnap) {
                final user = authSnap.data;
                return StreamBuilder<bool>(
                  stream:
                      user == null
                          ? Stream.value(false)
                          : FavoriteService.instance.isFavoriteStream(
                            user.uid,
                            parking.id,
                          ),
                  builder: (context, favSnap) {
                    localFav ??= favSnap.data ?? false;
                    final uiFav = localFav!;
                    return HomeParkingDetailBottomSheet(
                      parking: parking,
                      isFavorite: uiFav,
                      onToggleFavorite: () async {
                        final next = !uiFav;
                        setSheetState(() => localFav = next);
                        try {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          if (currentUser == null) return;
                          if (next) {
                            await FavoriteService.instance.add(
                              currentUser.uid,
                              parking,
                            );
                          } else {
                            await FavoriteService.instance.removeByParkingId(
                              currentUser.uid,
                              parking.id,
                            );
                          }
                        } catch (_) {
                          setSheetState(() => localFav = !next);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo actualizar favoritos',
                                ),
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Public API (called from home_page.dart via GlobalKey<MapWidgetState>) ─

  /// Animates the camera to the user's current position.
  void centerOnUser() {
    if (_currentPosition == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentPosition!, zoom: 16),
      ),
    );
  }

  /// Zooms the map in or out by [delta] levels.
  Future<void> zoomBy(double delta) async {
    if (_mapController == null) return;
    final zoom = await _mapController!.getZoomLevel();
    _mapController!.animateCamera(
      CameraUpdate.zoomTo((zoom + delta).clamp(2.0, 20.0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Real-time parking markers ✅
    final parkingsAsync = ref.watch(allParkingsStreamProvider);
    final brightness = Theme.of(context).brightness;

    if (_currentPosition == null) {
      return _MapLoading();
    }

    final markers = parkingsAsync.maybeWhen(
      data: (parkings) => _buildMarkers(parkings),
      orElse: () => <Marker>{},
    );

    return GoogleMap(
      onMapCreated: (ctrl) {
        _mapController = ctrl;
        widget.onMapCreated?.call(ctrl);
        if (_currentPosition != null) {
          ctrl.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _currentPosition!, zoom: 15),
            ),
          );
        }
      },
      initialCameraPosition: CameraPosition(
        target: _currentPosition!,
        zoom: 15,
      ),
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      style: GoogleMapStyles.forBrightness(brightness),
      onTap: (_) => widget.onMapTap?.call(),
    );
  }
}

// ─── Loading placeholder ──────────────────────────────────────────────────────
class _MapLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appPageBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.headerTop, AppColors.headerBottom],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.headerBottom.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Cargando mapa...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.headerBottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
