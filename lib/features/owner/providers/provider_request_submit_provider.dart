import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:beygo/features/core/providers/firebase_providers.dart';

class ProviderRequestSubmitException implements Exception {
  final String userMessage;

  const ProviderRequestSubmitException(this.userMessage);

  @override
  String toString() => userMessage;
}

final submitProviderRequestProvider = Provider<
  Future<String> Function({
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
  final uuid = const Uuid();

  Future<String> _upload({
    required Uint8List file,
    required String path,
  }) async {
    final refSt = storage.ref(path);

    final metadata = SettableMetadata(contentType: 'image/jpeg');

    print('📤 Uploading to: $path');
    print('📦 Bytes size: ${file.length}');
    try {
      await refSt.putData(file, metadata);
    } on FirebaseException catch (e) {
      final details =
          '${e.code} ${(e.message ?? '').toLowerCase()} ${e.toString().toLowerCase()}';

      if (details.contains('billing account') ||
          details.contains('delinquent') ||
          details.contains('httpresult: 402') ||
          details.contains('code: 402') ||
          details.contains('terminated the upload session')) {
        throw const ProviderRequestSubmitException(
          'No se pudo subir la documentación porque Firebase Storage del proyecto tiene la facturación deshabilitada. Esto no es un problema de tus datos ni del formulario; hay que reactivar la cuenta de billing del proyecto en Firebase/Google Cloud.',
        );
      }

      if (e.code == 'unauthorized' || details.contains('permission')) {
        throw const ProviderRequestSubmitException(
          'No se pudo subir la documentación por permisos de Firebase Storage. Revisa las reglas o la autenticación del usuario.',
        );
      }

      throw const ProviderRequestSubmitException(
        'No se pudo subir la documentación del parqueo en este momento. Intenta de nuevo en unos minutos.',
      );
    }
    print('✅ Uploaded: $path');

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
    try {
      print('🚀 START submitProviderRequest');
      final userRef = db.collection('users').doc(uid);
      final requestRef = db.collection('provider_requests').doc();
      final requestId = requestRef.id;
      final requestNumber = 'OWN-${requestId.substring(0, 6).toUpperCase()}';

      /// UPLOAD FILES
      final dpiFrontUrl = await _upload(
        file: dpiFront,
        path: 'provider_requests/$requestId/dpi_front.jpg',
      );

      final dpiBackUrl = await _upload(
        file: dpiBack,
        path: 'provider_requests/$requestId/dpi_back.jpg',
      );

      final patentUrl = await _upload(
        file: patent,
        path: 'provider_requests/$requestId/patent.jpg',
      );

      final List<String> imagesUrls = [];

      for (final img in parkingImages) {
        final url = await _upload(
          file: img,
          path: 'provider_requests/$requestId/${uuid.v4()}.jpg',
        );
        imagesUrls.add(url);
      }

      /// SAVE REQUEST
      await requestRef.set({
        'requestId': requestId,
        'requestNumber': requestNumber,
        'uid': uid,
        'companyName': companyName,
        'parkingName': parkingName,
        'email': email,
        'phone': phone,
        'nit': nit,
        'address': address,
        'capacity': capacity,
        'description': description,
        'pricePerHour': price,
        'freeCancellationMinutes': freeCancellationMinutes,
        'businessHours': {'open': openTime, 'close': closeTime},
        'lat': lat,
        'lng': lng,
        'parkingImages': imagesUrls,
        'documents': {
          'dpiFront': dpiFrontUrl,
          'dpiBack': dpiBackUrl,
          'patent': patentUrl,
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      /// UPDATE USER
      await userRef.set({
        'providerStatus': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ SUCCESS submitProviderRequest');
      return requestNumber;
    } on ProviderRequestSubmitException {
      rethrow;
    } on FirebaseException catch (e, st) {
      print('❌ ERROR submitProviderRequest: $e');
      print(st);
      throw ProviderRequestSubmitException(
        e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : 'No se pudo enviar la solicitud del parqueo en este momento.',
      );
    } catch (e, st) {
      print('❌ ERROR submitProviderRequest: $e');
      print(st);
      rethrow;
    }
  };
});
