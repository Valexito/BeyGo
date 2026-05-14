import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:beygo/common/common.dart';

class GooglePlacesService {
  static const Duration _timeout = Duration(seconds: 6);
  static const MethodChannel _placesChannel = MethodChannel('beygo/places');

  Future<List<PlaceAutocompleteSuggestion>> autocomplete({
    required String input,
    LatLng? locationBias,
    int? radiusMeters,
    String language = 'es',
    String countryCode = 'gt',
    String types = 'establishment|geocode',
  }) async {
    final query = input.trim();
    if (query.isEmpty) return const [];

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _autocompleteNative(
        input: query,
        countryCode: countryCode,
        locationBias: locationBias,
        radiusMeters: radiusMeters,
      );
    }

    final apiKey = await Env.resolveGoogleMapsKey();
    if (apiKey.isEmpty) {
      throw Exception(
        'Google Places no está configurado. Falta la API key de Maps/Places.',
      );
    }

    final params = <String, String>{
      'input': query,
      'key': apiKey,
      'language': language,
      'types': types,
      'components': 'country:$countryCode',
      'region': countryCode,
    };

    if (locationBias != null) {
      params['location'] = '${locationBias.latitude},${locationBias.longitude}';
    }

    if (locationBias != null && radiusMeters != null) {
      params['radius'] = '$radiusMeters';
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      params,
    );

    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) return const [];

    final data = json.decode(res.body) as Map<String, dynamic>;
    final status = data['status'] as String? ?? '';
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      throw Exception(
        'Places autocomplete failed: $status ${data['error_message'] ?? ''}',
      );
    }

    final predictions = (data['predictions'] as List?) ?? const [];
    return predictions.map((raw) {
      final p = raw as Map<String, dynamic>;
      final sf = p['structured_formatting'] as Map<String, dynamic>?;
      return PlaceAutocompleteSuggestion(
        placeId: p['place_id'] as String? ?? '',
        mainText:
            (sf?['main_text'] as String?) ??
            (p['description'] as String? ?? ''),
        secondaryText: (sf?['secondary_text'] as String?) ?? '',
        fullText: p['description'] as String? ?? '',
        types: ((p['types'] as List?) ?? const []).cast<String>(),
      );
    }).toList();
  }

  Future<LatLng?> fetchPlaceLocation(String placeId) async {
    if (placeId.isEmpty) return null;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _fetchPlaceLocationNative(placeId);
    }

    final apiKey = await Env.resolveGoogleMapsKey();
    if (apiKey.isEmpty) return null;

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': apiKey,
        'fields': 'geometry,name,formatted_address',
      },
    );

    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) return null;

    final data = json.decode(res.body) as Map<String, dynamic>;
    final loc =
        data['result']?['geometry']?['location'] as Map<String, dynamic>?;
    if (loc == null) return null;

    return LatLng(
      (loc['lat'] as num).toDouble(),
      (loc['lng'] as num).toDouble(),
    );
  }

  Future<List<PlaceAutocompleteSuggestion>> _autocompleteNative({
    required String input,
    required String countryCode,
    LatLng? locationBias,
    int? radiusMeters,
  }) async {
    final raw = await _placesChannel.invokeListMethod<dynamic>('autocomplete', {
      'input': input,
      'countryCode': countryCode,
      'latitude': locationBias?.latitude,
      'longitude': locationBias?.longitude,
      'radiusMeters': radiusMeters,
    });

    final items = raw ?? const [];
    return items.map((entry) {
      final p = Map<String, dynamic>.from(entry as Map);
      return PlaceAutocompleteSuggestion(
        placeId: p['placeId'] as String? ?? '',
        mainText: p['mainText'] as String? ?? '',
        secondaryText: p['secondaryText'] as String? ?? '',
        fullText: p['fullText'] as String? ?? '',
        types: ((p['types'] as List?) ?? const []).cast<String>(),
      );
    }).toList();
  }

  Future<LatLng?> _fetchPlaceLocationNative(String placeId) async {
    final raw = await _placesChannel.invokeMapMethod<dynamic, dynamic>(
      'fetchPlaceLocation',
      {'placeId': placeId},
    );
    if (raw == null) return null;

    final data = Map<String, dynamic>.from(raw);
    final lat = data['lat'];
    final lng = data['lng'];
    if (lat is! num || lng is! num) return null;

    return LatLng(lat.toDouble(), lng.toDouble());
  }
}

class PlaceAutocompleteSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;
  final String fullText;
  final List<String> types;

  const PlaceAutocompleteSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
    required this.fullText,
    required this.types,
  });
}
