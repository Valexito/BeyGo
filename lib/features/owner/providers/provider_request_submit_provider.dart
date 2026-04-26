import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:beygo/features/core/providers/firebase_providers.dart';

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
  final uuid = const Uuid();

  Future<String> _upload({
    required Uint8List file,
    required String path,
  }) async {
    final refSt = storage.ref(path);

    final metadata = SettableMetadata(contentType: 'image/jpeg');

    print('📤 Uploading to: $path');
    print('📦 Bytes size: ${file.length}');
    await refSt.putData(file, metadata);
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
    } catch (e, st) {
      print('❌ ERROR submitProviderRequest: $e');
      print(st);
      rethrow;
    }
  };
});
