import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:beygo/common/common.dart';

class GoogleDirectionsService {
  GoogleDirectionsService({String? apiKey})
    : _key = apiKey ?? Env.googleMapsKey;

  final String _key;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<List<LatLng>> getRoutePoints(LatLng origin, LatLng dest) async {
    final data = await _fetch(origin, dest);
    return data.points;
  }

  Future<double> getDistanceMeters(LatLng origin, LatLng dest) async {
    final data = await _fetch(origin, dest);
    return data.distanceMeters;
  }

  Future<double> getDurationSeconds(LatLng origin, LatLng dest) async {
    final data = await _fetch(origin, dest);
    return data.durationSeconds;
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<_RouteData> _fetch(LatLng o, LatLng d) async {
    if (_key.isNotEmpty) {
      try {
        return await _fetchGoogle(o, d);
      } catch (e) {
        print('[DIRECTIONS] Google failed → OSRM fallback: $e');
        return _fetchOsrm(o, d);
      }
    }
    print('[DIRECTIONS] No API key → using OSRM');
    return _fetchOsrm(o, d);
  }

  /// Google Directions API — returns encoded polyline
  Future<_RouteData> _fetchGoogle(LatLng o, LatLng d) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${o.latitude},${o.longitude}',
      'destination': '${d.latitude},${d.longitude}',
      'mode': 'driving',
      'language': 'es',
      'key': _key,
    });

    final resp = await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      throw StateError('Google Directions ${resp.statusCode}: ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final status = json['status'] as String;
    if (status != 'OK') {
      throw StateError('Google Directions status: $status');
    }

    final routes = (json['routes'] as List?) ?? [];
    if (routes.isEmpty) throw StateError('No routes returned');

    final route = routes.first as Map<String, dynamic>;
    final leg = (route['legs'] as List).first as Map<String, dynamic>;

    final distanceMeters =
        ((leg['distance'] as Map)['value'] as num).toDouble();
    final durationSeconds =
        ((leg['duration'] as Map)['value'] as num).toDouble();

    // Decode the overview polyline
    final encoded = (route['overview_polyline'] as Map)['points'] as String;
    final points = _decodePolyline(encoded);

    return _RouteData(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  /// OSRM public — free fallback, no key
  Future<_RouteData> _fetchOsrm(LatLng o, LatLng d) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${o.longitude},${o.latitude};${d.longitude},${d.latitude}'
        '?overview=full&geometries=geojson';

    final resp = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw StateError('OSRM ${resp.statusCode}: ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final routes = (json['routes'] as List?) ?? [];
    if (routes.isEmpty) throw StateError('OSRM: no routes');

    final first = routes.first as Map<String, dynamic>;
    final distance = (first['distance'] as num).toDouble();
    final duration = (first['duration'] as num).toDouble();
    final coords =
        (first['geometry']['coordinates'] as List)
            .map<List>((e) => (e as List).cast<num>().toList())
            .toList();
    final points =
        coords.map((xy) => LatLng(xy[1].toDouble(), xy[0].toDouble())).toList();

    return _RouteData(
      points: points,
      distanceMeters: distance,
      durationSeconds: duration,
    );
  }

  // ── Google encoded polyline decoder ───────────────────────────────────────
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}

class _RouteData {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  _RouteData({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}
