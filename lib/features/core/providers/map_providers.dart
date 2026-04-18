// lib/features/core/providers/map_providers.dart
//
// Replaced flutter_map MapController → GoogleMapController (google_maps_flutter)
//
// IMPORTANT: GoogleMapController cannot be created directly in a Provider because
// it's handed to us by the GoogleMap widget via onMapCreated. So we store it in
// a StateProvider that the widget writes to once the map is ready.
//
// Usage in widget:
//
//   final mapCtrlNotifier = ref.read(googleMapControllerProvider.notifier);
//
//   GoogleMap(
//     onMapCreated: (ctrl) => mapCtrlNotifier.state = ctrl,
//     ...
//   )
//
// Usage anywhere:
//
//   final ctrl = ref.watch(googleMapControllerProvider);
//   ctrl?.animateCamera(CameraUpdate.newLatLng(...));

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Stores the GoogleMapController once the GoogleMap widget hands it to us.
/// Nullable because the map might not be ready yet.
final googleMapControllerProvider = StateProvider<GoogleMapController?>(
  (ref) => null,
);
