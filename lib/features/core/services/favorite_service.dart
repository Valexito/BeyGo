import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:beygo/features/reservations/reservations.dart';

class FavoriteService {
  FavoriteService._();
  static final instance = FavoriteService._();

  final _col = FirebaseFirestore.instance.collection('favorites');

  String _docId(String uid, String parkingId) => '${uid}_$parkingId';

  Future<void> add(String uid, Parking p) async {
    if (p.id.isEmpty) {
      throw ArgumentError('Parking.id must not be empty');
    }

    final cover =
        (p.photos.isNotEmpty ? p.photos.first : null) ??
        p.coverUrl ??
        p.imageUrl;

    final map = <String, dynamic>{
      'userId': uid,
      'parkingId': p.id,
      'name': p.name,
      'ownerID': p.ownerID,
      'price': p.price,
      'spaces': p.spaces,
      'rating': (p.rating ?? 0).toDouble(),
      'originalPrice': p.originalPrice,
      'imageUrl': p.imageUrl, // legacy
      'coverUrl': cover, // principal para la UI
      'photos': p.photos, // opcional
      'descripcion': p.descripcion,
      'lat': p.lat,
      'lng': p.lng,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Escribimos en el doc determinista
    await _col.doc(_docId(uid, p.id)).set({
      ...map,
      'createdAt': FieldValue.serverTimestamp(), // 👈 IMPORTANTE
    });
    // (Opcional) limpia duplicados con auto-ID si existen
    final dupes =
        await _col
            .where('userId', isEqualTo: uid)
            .where('parkingId', isEqualTo: p.id)
            .get();
    for (final d in dupes.docs) {
      if (d.id != _docId(uid, p.id)) {
        await d.reference.delete();
      }
    }
  }

  /// Quitar favorito por parkingId (borra el determinista y cualquier auto-ID previo)
  Future<void> removeByParkingId(String uid, String parkingId) async {
    // borra determinista
    await _col.doc(_docId(uid, parkingId)).delete();

    // borra cualquier auto-ID que hubiera quedado
    final qs =
        await _col
            .where('userId', isEqualTo: uid)
            .where('parkingId', isEqualTo: parkingId)
            .get();
    for (final d in qs.docs) {
      try {
        await d.reference.delete();
      } catch (_) {
        // ignore permission errors for old/bad docs
      }
    }
  }

  /// Quitar por docId (útil desde la lista de favoritos)
  Future<void> removeByDocId(String docId) async {
    await _col.doc(docId).delete();
  }

  /// ¿Es favorito? — No dependemos del docId, sino de la existencia de un match.
  Stream<bool> isFavoriteStream(String uid, String parkingId) {
    return _col
        .where('userId', isEqualTo: uid)
        .where('parkingId', isEqualTo: parkingId)
        .snapshots()
        .map((qs) => qs.docs.isNotEmpty);
  }
}
