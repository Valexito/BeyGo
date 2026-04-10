import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_api/common/env/env.dart';
import 'package:mapbox_api/features/core/services/favorite_service.dart';
import 'package:mapbox_api/features/core/components/home_bottom_parking_details.dart';
import 'package:mapbox_api/features/reservations/services/geolocator.dart';
import 'package:mapbox_api/features/reservations/services/parking_service.dart';
import 'package:mapbox_api/features/reservations/models/parking.dart';
import 'package:rxdart/rxdart.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapWidget extends StatefulWidget {
  const MapWidget({super.key, this.mapController, this.onMapTap});

  final MapController? mapController;
  final VoidCallback? onMapTap;

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  LatLng? currentPosition;
  List<Marker> _parkingMarkers = [];
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = widget.mapController ?? MapController();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final location = await getCurrentLocation();
      if (!mounted) return;
      setState(() => currentPosition = location);
      await _loadParkingMarkers();
    } catch (e) {
      debugPrint('Error obteniendo ubicación: $e');
      if (!mounted) return;
      setState(() => currentPosition = LatLng(14.834999, -91.518669));
      await _loadParkingMarkers();
    }
  }

  Future<void> _loadParkingMarkers() async {
    final parkings = await ParkingService().getAllParkings();
    if (!mounted) return;

    setState(() {
      _parkingMarkers =
          parkings.map((p) {
            return Marker(
              point: LatLng(p.lat, p.lng),
              width: 100,
              height: 80,
              child: GestureDetector(
                onTap: () => _showParkingDetails(p),
                child: Column(
                  children: [
                    const Icon(
                      Icons.directions_car_filled,
                      color: Colors.blue,
                      size: 30,
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(221, 255, 255, 255),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        p.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList();
    });
  }

  void _showParkingDetails(Parking parking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                if (localFav == null) localFav = snap.data ?? false;
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

  void zoomBy(double delta) {
    final cam = _mapController.camera;
    final newZoom = (cam.zoom + delta).clamp(2.0, 20.0);
    _mapController.move(cam.center, newZoom.toDouble());
  }

  void centerOn(LatLng target, {double zoom = 16}) {
    _mapController.move(target, zoom);
  }

  void centerOnUser() {
    if (currentPosition != null) {
      _mapController.move(currentPosition!, 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: currentPosition!,
            initialZoom: 16,
            onTap: (_, __) => widget.onMapTap?.call(),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${Env.mapboxToken}',
              additionalOptions: {
                'accessToken': Env.mapboxToken,
                'id': 'mapbox/streets-v12',
              },
              userAgentPackageName: 'com.example.mapbox_api',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: currentPosition!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                ..._parkingMarkers,
              ],
            ),
          ],
        ),
        Positioned(
          right: 18,
          bottom: 245,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _roundBtn(icon: Icons.add, onTap: () => zoomBy(1)),
              const SizedBox(height: 14),
              _roundBtn(icon: Icons.remove, onTap: () => zoomBy(-1)),
              const SizedBox(height: 14),
              _roundBtn(icon: Icons.my_location, onTap: centerOnUser),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blueAccent, width: 1.8),
          ),
          child: Icon(icon, color: Colors.blueAccent),
        ),
      ),
    );
  }
}
