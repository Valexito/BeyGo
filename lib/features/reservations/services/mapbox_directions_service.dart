import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Lee el token desde --dart-define (o desde env_*.json con --dart-define-from-file)
const _ENV_TOKEN = String.fromEnvironment('MAPBOX_TOKEN');

/// Servicio de direcciones con soporte Mapbox + OSRM (fallback).
class MapboxDirectionsService {
  MapboxDirectionsService({
    String? mapboxAccessToken,
    this.profile =
        'driving', // 'driving' | 'driving-traffic' | 'walking' | 'cycling'
  }) : _token = mapboxAccessToken ?? _ENV_TOKEN;

  final String _token;
  final String profile;

  Future<List<LatLng>> getRoutePoints(LatLng origin, LatLng destination) async {
    final data = await _fetchRoute(origin, destination);
    return data.points;
  }

  Future<double> getDistanceMeters(LatLng origin, LatLng destination) async {
    final data = await _fetchRoute(origin, destination);
    return data.distanceMeters;
  }

  Future<double> getDurationSeconds(LatLng origin, LatLng destination) async {
    final data = await _fetchRoute(origin, destination);
    return data.durationSeconds;
  }

  // -------------------- internos --------------------

  Future<_RouteData> _fetchRoute(LatLng o, LatLng d) async {
    print('[ROUTE] origin: ${o.latitude}, ${o.longitude}');
    print('[ROUTE] destination: ${d.latitude}, ${d.longitude}');
    print('[ROUTE] token present: ${_token.isNotEmpty}');

    if (_token.isNotEmpty) {
      try {
        print('[ROUTE] Trying Mapbox...');
        return await _fetchRouteMapbox(o, d);
      } catch (e) {
        print('[ROUTE] Mapbox failed -> fallback OSRM');
        print('[ROUTE][ERROR] $e');
        return await _fetchRouteOsrm(o, d);
      }
    }

    print('[ROUTE] Using OSRM directly');
    return await _fetchRouteOsrm(o, d);
  }

  /// Mapbox Directions (requiere token)
  Future<_RouteData> _fetchRouteMapbox(LatLng o, LatLng d) async {
    final base =
        'https://api.mapbox.com/directions/v5/mapbox/$profile/'
        '${o.longitude},${o.latitude};${d.longitude},${d.latitude}';
    final url = '$base?overview=full&geometries=geojson&access_token=$_token';

    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw StateError('Mapbox error ${resp.statusCode}: ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final routes = (json['routes'] as List?) ?? const [];
    if (routes.isEmpty) throw StateError('Mapbox: no se encontró ruta');

    final first = routes.first as Map<String, dynamic>;
    final distance = (first['distance'] as num).toDouble(); // m
    final duration = (first['duration'] as num).toDouble(); // s

    final geometry = first['geometry'] as Map<String, dynamic>;
    final coords =
        (geometry['coordinates'] as List)
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

  /// OSRM público (fallback sin token)
  Future<_RouteData> _fetchRouteOsrm(LatLng o, LatLng d) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
        '${o.longitude},${o.latitude};${d.longitude},${d.latitude}'
        '?overview=full&geometries=geojson';

    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) {
      throw StateError('OSRM error ${resp.statusCode}: ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final routes = (json['routes'] as List?) ?? const [];
    if (routes.isEmpty) throw StateError('OSRM: no se encontró ruta');

    final first = routes.first as Map<String, dynamic>;
    final distance = (first['distance'] as num).toDouble(); // m
    final duration = (first['duration'] as num).toDouble(); // s

    final geometry = first['geometry'] as Map<String, dynamic>;
    final coords =
        (geometry['coordinates'] as List)
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
