// lib/features/reservations/providers/directions_providers.dart
//
// latlong2.LatLng → google_maps_flutter.LatLng
//
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:beygo/common/common.dart';

/// DI of the directions service.
/// Uses Env.googleMapsKey automatically; falls back to OSRM if key is empty.
final directionsServiceProvider = Provider<GoogleDirectionsService>((ref) {
  return GoogleDirectionsService();
});

typedef RouteArgs = ({LatLng origin, LatLng destination});

final routePointsProvider = FutureProvider.autoDispose
    .family<List<LatLng>, RouteArgs>((ref, args) async {
      ref.keepAlive();
      final svc = ref.read(directionsServiceProvider);
      return svc.getRoutePoints(args.origin, args.destination);
    });

final routeDistanceProvider = FutureProvider.autoDispose
    .family<String, RouteArgs>((ref, args) async {
      ref.keepAlive();
      final svc = ref.read(directionsServiceProvider);
      final meters = await svc.getDistanceMeters(args.origin, args.destination);
      if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
      return '${(meters / 1000).toStringAsFixed(1)} km';
    });

final routeDurationProvider = FutureProvider.autoDispose
    .family<String, RouteArgs>((ref, args) async {
      ref.keepAlive();
      final svc = ref.read(directionsServiceProvider);
      final seconds = await svc.getDurationSeconds(
        args.origin,
        args.destination,
      );
      final minutes = (seconds / 60).round();
      if (minutes < 60) return '$minutes min';
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}min';
    });
