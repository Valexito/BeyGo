// lib/features/reservations/services/parking_service.dart
// ignore_for_file: avoid_print
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/parking.dart';

class ParkingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _uuid = const Uuid();

  // ----- Reads -----
  Future<List<Parking>> getAllParkings() async {
    final snapshot = await _firestore.collection('parkings').get(); // <— PLURAL
    return snapshot.docs.map((d) => Parking.fromDoc(d)).toList();
  }

  // ----- Create (sin fotos) — si aún lo usas, pásalo a PLURAL -----
  Future<String> createParking({
    required String ownerID,
    required String name,
    required double lat,
    required double lng,
    required int spaces,
    String? descripcion,
    int price = 0,
    String? imageUrl,
    String? localImagePath,
  }) async {
    _ensureSameUser(ownerID);

    final ref = await _firestore.collection('parkings').add({
      'ownerID': ownerID,
      'name': name,
      'lat': lat,
      'lng': lng,
      'spaces': spaces,
      'pricePerHour': price,
      'descripcion': descripcion,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _syncParkingSpaces(ref: ref, targetSpaces: spaces);
    return ref.id;
  }

  // ----- Create con fotos -----
  Future<String> createParkingWithImages({
    required String ownerID,
    required String name,
    required double lat,
    required double lng,
    required int spaces,
    required List<XFile> images,
    String? descripcion,
    int price = 0,
  }) async {
    _ensureSameUser(ownerID);

    if (images.length < 3) {
      throw Exception('Sube al menos 3 imágenes.');
    }

    // 1) Crea PRIMERO el doc en /parkings/{parkingId}
    final docRef = _firestore.collection('parkings').doc(); // <— PLURAL
    final parkingId = docRef.id;

    await docRef.set({
      'ownerID': ownerID,
      'name': name,
      'lat': lat,
      'lng': lng,
      'spaces': spaces,
      'pricePerHour': price,
      'descripcion':
          (descripcion == null || descripcion.isEmpty) ? null : descripcion,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _syncParkingSpaces(ref: docRef, targetSpaces: spaces);

    // pequeña espera ayuda a reglas de Storage que leen el doc recién creado
    await Future.delayed(const Duration(milliseconds: 200));

    // 2) Sube a /parkings/{parkingId}/photos/{fileName}
    final urls = await _uploadImages(
      ownerID: ownerID,
      parkingId: parkingId,
      images: images,
    );

    // 3) Actualiza con portada y galería
    await docRef.set({
      'coverUrl': urls.first,
      'photos': urls,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return parkingId;
  }

  // ----- Agregar más fotos luego -----
  Future<List<String>> addParkingImages({
    required String ownerID,
    required String parkingId,
    required List<XFile> images,
  }) async {
    _ensureSameUser(ownerID);

    // verifica que el doc exista y sea tuyo (evita 403s confusos)
    final snap = await _firestore.collection('parkings').doc(parkingId).get();
    if (!snap.exists) {
      throw Exception('El parqueo $parkingId no existe.');
    }
    if (snap.data()?['ownerID'] != ownerID) {
      throw Exception('No eres el dueño de este parqueo.');
    }

    final urls = await _uploadImages(
      ownerID: ownerID,
      parkingId: parkingId,
      images: images,
    );

    await _firestore.collection('parkings').doc(parkingId).update({
      'photos': FieldValue.arrayUnion(urls),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return urls;
  }

  Future<void> updateParkingDetails({
    required String ownerID,
    required String parkingId,
    required String name,
    required String phone,
    required String address,
    required int spaces,
    required String description,
    required int pricePerHour,
    required String openTime,
    required String closeTime,
    double? lat,
    double? lng,
    List<String>? existingPhotos,
    List<XFile> newImages = const [],
  }) async {
    _ensureSameUser(ownerID);

    final docRef = _firestore.collection('parkings').doc(parkingId);
    final snap = await docRef.get();
    if (!snap.exists) {
      throw StateError('El parqueo ya no existe.');
    }
    final currentData = snap.data() ?? <String, dynamic>{};
    final currentOwnerId =
        ((currentData['ownerID'] as String?) ??
                (currentData['ownerUid'] as String?) ??
                '')
            .trim();
    if (currentOwnerId != ownerID) {
      throw StateError('No tienes permiso para editar este parqueo.');
    }

    final uploadedUrls =
        newImages.isEmpty
            ? const <String>[]
            : await _uploadImages(
              ownerID: ownerID,
              parkingId: parkingId,
              images: newImages,
            );

    final currentPhotos =
        existingPhotos ??
        ((snap.data()?['photos'] as List?) ?? const [])
            .map((e) => '$e')
            .where((e) => e.trim().isNotEmpty)
            .toList();
    final mergedPhotos = [...currentPhotos, ...uploadedUrls];
    final coverUrl =
        mergedPhotos.isNotEmpty
            ? mergedPhotos.first
            : (snap.data()?['coverUrl'] as String?);

    await docRef.set({
      'ownerID': ownerID,
      'name': name,
      'phone': phone,
      'address': address,
      'spaces': spaces,
      'descripcion': description,
      'pricePerHour': pricePerHour,
      'businessHours': {
        'open': openTime,
        'close': closeTime,
      },
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'photos': mergedPhotos,
      'coverUrl': coverUrl,
      'parkingName': FieldValue.delete(),
      'ownerUid': FieldValue.delete(),
      'capacity': FieldValue.delete(),
      'description': FieldValue.delete(),
      'price': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _syncParkingSpaces(ref: docRef, targetSpaces: spaces);
  }

  Future<void> _syncParkingSpaces({
    required DocumentReference<Map<String, dynamic>> ref,
    required int targetSpaces,
  }) async {
    if (targetSpaces <= 0) {
      throw StateError('La cantidad de espacios debe ser mayor a cero.');
    }

    final spacesRef = ref.collection('spaces');
    final snapshot = await spacesRef.get();
    final docsByNumber = <int, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    for (final doc in snapshot.docs) {
      final parsedNumber =
          int.tryParse(doc.id) ?? (doc.data()['spaceNumber'] as num?)?.toInt();
      if (parsedNumber == null || parsedNumber <= 0) continue;
      docsByNumber[parsedNumber] = doc;
    }

    final batch = _firestore.batch();

    for (var number = 1; number <= targetSpaces; number++) {
      final existing = docsByNumber[number];
      if (existing == null) {
        batch.set(spacesRef.doc('$number'), {
          'spaceNumber': number,
          'status': 'free',
          'currentReservationId': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        continue;
      }

      final data = existing.data();
      final currentSpaceNumber = (data['spaceNumber'] as num?)?.toInt();
      if (currentSpaceNumber != number) {
        batch.set(existing.reference, {
          'spaceNumber': number,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    for (final entry in docsByNumber.entries) {
      if (entry.key <= targetSpaces) continue;

      final data = entry.value.data();
      final status = ((data['status'] as String?) ?? 'free').trim().toLowerCase();
      final currentReservationId =
          (data['currentReservationId'] as String?)?.trim() ?? '';

      if (status != 'free' || currentReservationId.isNotEmpty) {
        throw StateError(
          'No puedes reducir espacios porque el espacio ${entry.key} está en uso.',
        );
      }

      batch.delete(entry.value.reference);
    }

    await batch.commit();
  }

  // ===== Helpers =====
  void _ensureSameUser(String ownerID) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Debes iniciar sesión.');
    if (uid != ownerID) {
      throw StateError('UID actual ($uid) no coincide con ownerID ($ownerID).');
    }
  }

  Future<List<String>> _uploadImages({
    required String ownerID, // solo para logs/validar, NO en la ruta
    required String parkingId, // este sí va en la ruta
    required List<XFile> images,
  }) async {
    final urls = <String>[];

    for (final img in images) {
      final bytes = await img.readAsBytes();
      final ext = _guessExt(img.name);
      final contentType = _guessContentType(ext);

      // tus reglas aceptan hasta 10MB; si quieres 5MB cámbialo aquí o en reglas
      if (bytes.length > 10 * 1024 * 1024) {
        throw Exception('La imagen ${img.name} excede 10 MB.');
      }

      // 🔴 RUTA CORRECTA que coincide con tus reglas:
      //     /parkings/{parkingId}/photos/{uuid.ext}
      final fileName = '${_uuid.v4()}.$ext';
      final path = 'parkings/$parkingId/photos/$fileName';
      print('[upload] uid=$ownerID path=$path size=${bytes.length}');

      final ref = _storage.ref(path);
      final metadata = SettableMetadata(contentType: contentType);

      try {
        await ref.putData(Uint8List.fromList(bytes), metadata);
      } on FirebaseException catch (e) {
        print(
          '[upload][FirebaseException] code=${e.code} message=${e.message}',
        );
        rethrow;
      }

      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  String _guessExt(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'png';
    if (n.endsWith('.webp')) return 'webp';
    if (n.endsWith('.jpeg') || n.endsWith('.jpg')) return 'jpg';
    return 'jpg';
  }

  String _guessContentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

/// ============================
/// 🔥 PROVIDER
/// ============================
final parkingServiceProvider = Provider<ParkingService>(
  (ref) => ParkingService(),
);

/// Stream en tiempo real de todos los parqueos activos para el mapa.
/// Solo incluye parkings con lat/lng válidos (distinto de 0).
///
/// Úsalo en MapWidget:
///   final parkingsAsync = ref.watch(allParkingsStreamProvider);
///
/// Si agregas un campo 'isApproved' o 'status' en Firestore,
/// descomenta el .where() correspondiente.
final allParkingsStreamProvider = StreamProvider<List<Parking>>((ref) {
  return FirebaseFirestore.instance
      .collection('parkings')
      // .where('isApproved', isEqualTo: true)  // ← descomenta si lo necesitas
      // .where('status', isEqualTo: 'active')   // ← o este
      .snapshots()
      .map(
        (snap) =>
            snap.docs
                .map((d) => Parking.fromDoc(d))
                .where((p) => p.lat != 0 && p.lng != 0)
                .toList(),
      );
});
