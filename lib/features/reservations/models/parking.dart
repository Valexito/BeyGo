import 'package:cloud_firestore/cloud_firestore.dart';

class Parking {
  final String id;
  final double lat;
  final double lng;
  final String name;
  final String ownerID;
  final int price;
  final String? phone;
  final int spaces;
  final double? rating;
  final double? originalPrice;
  final String? imageUrl;
  final String? localImagePath;
  final String? descripcion;
  final String? coverUrl;
  final List<String> photos;
  final int pricePerHour;
  final Map<String, String>? businessHours;
  final bool autoApproveReservations;
  final bool requirePlateOnEntry;

  const Parking({
    required this.id,
    required this.lat,
    required this.lng,
    required this.name,
    required this.ownerID,
    required this.price,
    required this.spaces,
    this.rating,
    this.originalPrice,
    this.imageUrl,
    this.localImagePath,
    this.descripcion,
    this.coverUrl,
    this.photos = const [],
    this.pricePerHour = 0,
    this.businessHours,
    this.phone,
    this.autoApproveReservations = false,
    this.requirePlateOnEntry = true,
  });

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0.0;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  factory Parking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Parking.fromMap(data, id: doc.id);
  }

  factory Parking.fromMap(Map<String, dynamic> data, {required String id}) {
    final parsedPrice = _toInt(data['price']);
    final parsedPricePerHour = _toInt(data['pricePerHour']);

    final bh = data['businessHours'];
    Map<String, String>? parsedHours;
    if (bh is Map) {
      parsedHours = {
        'open': bh['open']?.toString() ?? '',
        'close': bh['close']?.toString() ?? '',
      };
    }

    return Parking(
      id: id,
      lat: _toDouble(data['lat']),
      lng: _toDouble(data['lng']),
      name: (data['name'] as String?) ?? '',
      ownerID: (data['ownerID'] as String?) ?? '',
      price: parsedPrice,
      spaces: _toInt(data['spaces']),
      rating: data['rating'] is num ? (data['rating'] as num).toDouble() : null,
      originalPrice:
          data['originalPrice'] is num
              ? (data['originalPrice'] as num).toDouble()
              : null,
      imageUrl: data['imageUrl'] as String?,
      localImagePath: data['localImagePath'] as String?,
      descripcion: data['descripcion'] as String?,
      coverUrl: data['coverUrl'] as String?,
      photos: _toStringList(data['photos']),
      pricePerHour: parsedPricePerHour > 0 ? parsedPricePerHour : parsedPrice,
      businessHours: parsedHours,
      phone: data['phone'] as String?,
      autoApproveReservations:
          (data['autoApproveReservations'] as bool?) ?? false,
      requirePlateOnEntry: (data['requirePlateOnEntry'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'name': name,
    'ownerID': ownerID,
    'price': price,
    'spaces': spaces,
    'rating': rating,
    'originalPrice': originalPrice,
    'imageUrl': imageUrl,
    'localImagePath': localImagePath,
    'descripcion': descripcion,
    'coverUrl': coverUrl,
    'photos': photos,
    'pricePerHour': pricePerHour,
    'businessHours': businessHours,
    'phone': phone,
    'autoApproveReservations': autoApproveReservations,
    'requirePlateOnEntry': requirePlateOnEntry,
  };

  Parking copyWith({
    String? id,
    double? lat,
    double? lng,
    String? name,
    String? ownerID,
    int? price,
    int? spaces,
    double? rating,
    double? originalPrice,
    String? imageUrl,
    String? localImagePath,
    String? descripcion,
    String? coverUrl,
    List<String>? photos,
    int? pricePerHour,
    Map<String, String>? businessHours,
    String? phone,
    bool? autoApproveReservations,
    bool? requirePlateOnEntry,
  }) {
    return Parking(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      name: name ?? this.name,
      ownerID: ownerID ?? this.ownerID,
      price: price ?? this.price,
      spaces: spaces ?? this.spaces,
      rating: rating ?? this.rating,
      originalPrice: originalPrice ?? this.originalPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      descripcion: descripcion ?? this.descripcion,
      coverUrl: coverUrl ?? this.coverUrl,
      photos: photos ?? this.photos,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      businessHours: businessHours ?? this.businessHours,
      phone: phone ?? this.phone,
      autoApproveReservations:
          autoApproveReservations ?? this.autoApproveReservations,
      requirePlateOnEntry: requirePlateOnEntry ?? this.requirePlateOnEntry,
    );
  }
}
