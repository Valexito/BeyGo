// lib/features/core/components/map_widget.dart
//
// ✅ FULLY MIGRATED: flutter_map + Mapbox → google_maps_flutter
//    • No flutter_map, no latlong2, no Mapbox token
//    • currentPosition is google_maps_flutter.LatLng (not nullable mismatch)
//    • Parking markers via Google Maps Markers
//    • Favorites + parking detail sheet unchanged
//
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:rxdart/rxdart.dart';
import 'package:mapbox_api/common/services/geolocator.dart'; // ← returns google_maps_flutter.LatLng
import 'package:mapbox_api/features/core/services/favorite_service.dart';
import 'package:mapbox_api/features/core/components/home_bottom_parking_details.dart';
import 'package:mapbox_api/features/reservations/providers/parking_service_provider.dart';
import 'package:mapbox_api/features/reservations/models/parking.dart';

class MapWidget extends StatefulWidget {
  /// Called when the user taps the map background (not a marker).
  final VoidCallback? onMapTap;

  /// Exposes the GoogleMapController to the parent once the map is ready.
  final void Function(GoogleMapController)? onMapCreated;

  const MapWidget({super.key, this.onMapTap, this.onMapCreated});

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  GoogleMapController? _mapController;

  // ✅ google_maps_flutter.LatLng — NOT latlong2.LatLng
  // This was the source of Image 4 error: variable typed as latlong2.LatLng?
  // but assigned a google_maps_flutter.LatLng value.
  LatLng? _currentPosition;

  Set<Marker> _markers = {};

  static const LatLng _fallback = LatLng(14.834999, -91.518669); // Xela

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // getCurrentLocation() now returns google_maps_flutter.LatLng ✅
    LatLng position;
    try {
      position = await getCurrentLocation();
    } catch (_) {
      position = _fallback;
    }
    if (!mounted) return;
    // Both `position` and `_currentPosition` are the same LatLng type ✅
    setState(() => _currentPosition = position);
    await _loadParkingMarkers(position);
  }

  Future<void> _loadParkingMarkers(LatLng userPosition) async {
    final parkings = await ParkingService().getAllParkings();
    if (!mounted) return;

    final markers = <Marker>{};

    // User location
    markers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: userPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Tu ubicación'),
      ),
    );

    // Parking spots
    for (final p in parkings) {
      // Parking.lat and Parking.lng are doubles — wrap directly ✅
      final pos = LatLng(p.lat, p.lng);
      markers.add(
        Marker(
          markerId: MarkerId('parking_${p.id}'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: p.name,
            snippet: 'Q${p.price}/hora · Toca para ver',
          ),
          onTap: () => _showParkingDetails(p),
        ),
      );
    }

    if (!mounted) return;
    setState(() => _markers = markers);
  }

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
            return StreamBuilder<bool>(
              stream: FirebaseAuth.instance.authStateChanges().switchMap((
                user,
              ) {
                if (user == null) return Stream.value(false);
                return FavoriteService.instance.isFavoriteStream(
                  user.uid,
                  parking.id,
                );
              }),
              builder: (context, snap) {
                localFav ??= snap.data ?? false;
                final uiFav = localFav!;
                return HomeParkingDetailBottomSheet(
                  parking: parking,
                  isFavorite: uiFav,
                  onToggleFavorite: () async {
                    final next = !uiFav;
                    setSheetState(() => localFav = next);
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;
                      if (next) {
                        await FavoriteService.instance.add(user.uid, parking);
                      } else {
                        await FavoriteService.instance.removeByParkingId(
                          user.uid,
                          parking.id,
                        );
                      }
                    } catch (_) {
                      setSheetState(() => localFav = !next);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo actualizar favoritos'),
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
  }

  // ── Public methods called by home_page.dart via GlobalKey ─────────────────

  void centerOnUser() {
    if (_currentPosition == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentPosition!, zoom: 16),
      ),
    );
  }

  Future<void> zoomBy(double delta) async {
    if (_mapController == null) return;
    final zoom = await _mapController!.getZoomLevel();
    _mapController!.animateCamera(
      CameraUpdate.zoomTo((zoom + delta).clamp(2.0, 20.0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return Container(
        color: const Color(0xFFF0F4F8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.headerTop, AppColors.headerBottom],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.headerBottom.withOpacity(0.25),
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

    return GoogleMap(
      onMapCreated: (ctrl) {
        _mapController = ctrl;
        widget.onMapCreated?.call(ctrl);
      },
      initialCameraPosition: CameraPosition(
        target: _currentPosition!,
        zoom: 15,
      ),
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      onTap: (_) => widget.onMapTap?.call(),
    );
  }
}
