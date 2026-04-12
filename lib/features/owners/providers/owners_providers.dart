import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:mapbox_api/features/core/providers/firebase_providers.dart';

final submitProviderRequestProvider = Provider<
  Future<void> Function({
    required String uid,
    required String companyName,
    required String parkingName,
    required String email,
    required String phone,
    required String nit,
    required String address,
    required int capacity,
    required String description,
    required double lat,
    required double lng,
    required List<Uint8List> parkingImages,
    required Uint8List dpiFront,
    required Uint8List dpiBack,
    required Uint8List patent,
    required int price,
    required int freeCancellationMinutes,
    required String openTime,
    required String closeTime,
  })
>((ref) {
  final db = ref.watch(firestoreProvider);
  final storage = ref.watch(storageProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final uuid = const Uuid();

  Future<T> _retry<T>(
    Future<T> Function() op, {
    int max = 6,
    Duration firstDelay = const Duration(milliseconds: 300),
  }) async {
    var attempt = 0;
    var delay = firstDelay;
    late Object lastErr;

    while (attempt < max) {
      try {
        return await op();
      } catch (e) {
        lastErr = e;
        attempt++;
        if (attempt >= max) break;
        await Future.delayed(delay);
        final nextMs = (delay.inMilliseconds * 1.8).clamp(300, 4000).toInt();
        delay = Duration(milliseconds: nextMs);
      }
    }
    throw lastErr;
  }

  Future<String> _uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    required String path,
  }) async {
    final bytes = fileBytes;
    if (bytes.isEmpty) {
      throw Exception('Archivo vacío');
    }
    if (bytes.length > 10 * 1024 * 1024) {
      throw Exception('El archivo excede 10MB.');
    }

    final ext = _guessExt(fileName);
    final contentType = _guessContentType(ext);

    final refSt = storage.ref(path);
    final metadata = SettableMetadata(contentType: contentType);

    await _retry(() async {
      await refSt.putData(Uint8List.fromList(bytes), metadata);
      return true;
    });

    return refSt.getDownloadURL();
  }

  return ({
    required String uid,
    required String companyName,
    required String parkingName,
    required String email,
    required String phone,
    required String nit,
    required String address,
    required int capacity,
    required String description,
    required double lat,
    required double lng,
    required List<Uint8List> parkingImages,
    required Uint8List dpiFront,
    required Uint8List dpiBack,
    required Uint8List patent,
    required int price,
    required int freeCancellationMinutes,
    required String openTime,
    required String closeTime,
  }) async {
    final current = auth.currentUser;
    if (current == null || current.uid != uid) {
      throw StateError('Debes iniciar sesión correctamente.');
    }

    if (companyName.trim().isEmpty) {
      throw ArgumentError('Company name es obligatorio.');
    }
    if (parkingName.trim().isEmpty) {
      throw ArgumentError('Parking name es obligatorio.');
    }
    if (email.trim().isEmpty) {
      throw ArgumentError('Email es obligatorio.');
    }
    if (phone.trim().isEmpty) {
      throw ArgumentError('Phone es obligatorio.');
    }
    if (nit.trim().isEmpty) {
      throw ArgumentError('NIT es obligatorio.');
    }
    if (address.trim().isEmpty) {
      throw ArgumentError('Address es obligatorio.');
    }
    if (capacity <= 0) {
      throw ArgumentError('La capacidad debe ser mayor a 0.');
    }
    if (price < 0) {
      throw ArgumentError('El precio por hora no puede ser negativo.');
    }
    if (freeCancellationMinutes < 3) {
      throw ArgumentError(
        'El tiempo de cancelación gratis no puede ser menor a 3 minutos.',
      );
    }
    if (openTime.trim().isEmpty || closeTime.trim().isEmpty) {
      throw ArgumentError('El horario de atención es obligatorio.');
    }
    if (parkingImages.length < 3) {
      throw ArgumentError('Debes subir al menos 3 fotos del parqueo.');
    }

    final userRef = db.collection('users').doc(uid);
    final userSnap = await userRef.get();
    final userData = userSnap.data() ?? {};
    final providerStatus = (userData['providerStatus'] ?? 'none').toString();

    if (providerStatus == 'pending') {
      throw StateError('Ya tienes una solicitud pendiente.');
    }

    final requestRef = db.collection('provider_requests').doc();
    final requestId = requestRef.id;

    final List<String> uploadedPaths = [];
    final List<String> parkingImageUrls = [];

    try {
      final dpiFrontPath =
          'provider_requests/$requestId/documents/dpi_front.jpg';
      final dpiBackPath =
          'provider_requests/$requestId/documents/dpi_back.jpg';
      final patentPath =
          'provider_requests/$requestId/documents/patent.jpg';

      final dpiFrontUrl = await _uploadFile(fileBytes: dpiFront, fileName: 'dpi_front.jpg', path: dpiFrontPath);
      uploadedPaths.add(dpiFrontPath);

      final dpiBackUrl = await _uploadFile(fileBytes: dpiBack, fileName: 'dpi_back.jpg', path: dpiBackPath);
      uploadedPaths.add(dpiBackPath);

      final patentUrl = await _uploadFile(fileBytes: patent, fileName: 'patent.jpg', path: patentPath);
      uploadedPaths.add(patentPath);

      for (final img in parkingImages) {
        final filePath =
            'provider_requests/$requestId/parking/${uuid.v4()}.jpg';

        final url = await _uploadFile(
          fileBytes: img,
          fileName: 'parking.jpg',
          path: filePath,
        );

        uploadedPaths.add(filePath);
        parkingImageUrls.add(url);
      }

      await requestRef.set({
        'requestId': requestId,
        'uid': uid,
        'companyName': companyName.trim(),
        'parkingName': parkingName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'nit': nit.trim(),
        'address': address.trim(),
        'capacity': capacity,
        'description': description.trim(),
        'pricePerHour': price,
        'freeCancellationMinutes': freeCancellationMinutes,
        'businessHours': {'open': openTime.trim(), 'close': closeTime.trim()},
        'lat': lat,
        'lng': lng,
        'parkingImages': parkingImageUrls,
        'documents': {
          'dpiFront': dpiFrontUrl,
          'dpiBack': dpiBackUrl,
          'patent': patentUrl,
        },
        'status': 'pending',
        'reviewComment': null,
        'reviewedAt': null,
        'reviewedBy': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await userRef.set({
        'providerStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      await _safeDeleteUploadedFiles(
        storage: storage,
        uploadedPaths: uploadedPaths,
      );
      rethrow;
    }
  };
});

Future<void> _safeDeleteUploadedFiles({
  required FirebaseStorage storage,
  required List<String> uploadedPaths,
}) async {
  for (final path in uploadedPaths) {
    try {
      await storage.ref(path).delete();
    } catch (_) {}
  }
}

String _guessExt(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'png';
  if (n.endsWith('.webp')) return 'webp';
  if (n.endsWith('.jpeg')) return 'jpeg';
  if (n.endsWith('.jpg')) return 'jpg';
  return 'jpg';
}

String _guessContentType(String ext) {
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'jpeg':
      return 'image/jpeg';
    case 'jpg':
    default:
      return 'image/jpeg';
  }
}
