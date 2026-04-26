// lib/features/reservations/providers/location_providers.dart
//
// ✅ FIXED: Removed latlong2 entirely.
//    Uses google_maps_flutter.LatLng everywhere.
//    geolocator helper now lives at:
//      lib/features/reservations/services/geolocator.dart  (feature-scoped)
//    OR:
//      lib/common/services/geolocator.dart  (if you prefer it shared)
//
//    Both files now return google_maps_flutter.LatLng so there is no conflict.
//
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:beygo/common/services/geolocator.dart' as helper;

// ⚠️  Import whichever path matches YOUR project structure.
//    If the file is at lib/features/reservations/services/geolocator.dart:
//    If the file is at lib/common/services/geolocator.dart, change to:
//    import 'package:beygo/common/services/geolocator.dart' as helper;

/// One-shot current location (used for initial map position and route origin).
/// Falls back to Xela coords if GPS fails or permission is denied.
final currentLocationProvider = FutureProvider<LatLng>((ref) async {
  try {
    final loc = await helper.getCurrentLocation();
    debugPrint('[LOCATION] success: ${loc.latitude}, ${loc.longitude}');
    return loc;
  } catch (e) {
    debugPrint('[LOCATION] error: $e → using Xela fallback');
    return const LatLng(14.834999, -91.518669);
  }
});

