// lib/features/core/providers/map_providers.dart
//
// ✅ FIXED: Replaced flutter_map.MapController → GoogleMapController
//
// GoogleMapController cannot be created in a Provider directly — it's handed
// to us by the GoogleMap widget via onMapCreated. We store it in a StateProvider
// that the widget writes to once the map is ready.
//
// NOTE: If you only use MapWidget (which manages its own controller internally),
// you may not need this provider at all. It's useful if you want to control
// the map from outside MapWidget (e.g. from a Riverpod action).
//
// Usage:
//   // In the widget that owns GoogleMap:
//   final mapCtrl = ref.read(googleMapControllerProvider.notifier);
//   GoogleMap(onMapCreated: (ctrl) => mapCtrl.state = ctrl, ...)
//
//   // From anywhere else:
//   final ctrl = ref.watch(googleMapControllerProvider);
//   ctrl?.animateCamera(CameraUpdate.newLatLng(...));
//
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Stores the GoogleMapController once the GoogleMap widget hands it over.
/// Nullable because the map might not be ready yet.
final googleMapControllerProvider = StateProvider<GoogleMapController?>(
  (ref) => null,
);
