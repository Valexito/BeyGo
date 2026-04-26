import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:beygo/features/core/providers/firebase_providers.dart';

/// ===============================
/// STREAM: ALL PROVIDER REQUESTS
/// ===============================
final providerRequestsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final db = ref.watch(firestoreProvider);

  return db
      .collection('provider_requests')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {'id': doc.id, ...data};
        }).toList();
      });
});

/// ===============================
/// APPROVE PROVIDER REQUEST
/// ===============================
final approveProviderRequestProvider =
    Provider<Future<void> Function({required String requestId})>((ref) {
      final db = ref.watch(firestoreProvider);

      return ({required String requestId}) async {
        final requestRef = db.collection('provider_requests').doc(requestId);

        final requestSnap = await requestRef.get();

        if (!requestSnap.exists) {
          throw StateError('Solicitud no encontrada');
        }

        final data = requestSnap.data() as Map<String, dynamic>;
        final uid = data['uid'];

        final parkingRef = db.collection('parkings').doc();

        await db.runTransaction((tx) async {
          /// CREATE PARKING
          tx.set(parkingRef, {
            'ownerID': uid,
            'name': data['parkingName'],
            'email': data['email'],
            'phone': data['phone'],
            'address': data['address'],
            'descripcion': data['description'],
            'pricePerHour': data['pricePerHour'],
            'spaces': data['capacity'],
            'lat': data['lat'],
            'lng': data['lng'],
            'photos': data['parkingImages'],
            'coverUrl':
                data['parkingImages'] != null &&
                        (data['parkingImages'] as List).isNotEmpty
                    ? data['parkingImages'][0]
                    : null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          /// UPDATE REQUEST STATUS
          tx.update(requestRef, {
            'status': 'approved',
            'reviewedAt': FieldValue.serverTimestamp(),
          });

          /// UPDATE USER ROLE
          final userRef = db.collection('users').doc(uid);

          tx.set(userRef, {
            'role': 'provider',
            'providerStatus': 'approved',
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });
      };
    });

/// ===============================
/// REJECT PROVIDER REQUEST
/// ===============================
final rejectProviderRequestProvider = Provider<
  Future<void> Function({required String requestId, String? comment})
>((ref) {
  final db = ref.watch(firestoreProvider);

  return ({required String requestId, String? comment}) async {
    final requestRef = db.collection('provider_requests').doc(requestId);

    final requestSnap = await requestRef.get();

    if (!requestSnap.exists) {
      throw StateError('Solicitud no encontrada');
    }

    final data = requestSnap.data() as Map<String, dynamic>;
    final uid = data['uid'];

    await db.runTransaction((tx) async {
      /// UPDATE REQUEST
      tx.update(requestRef, {
        'status': 'rejected',
        'reviewComment': comment,
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      /// RESET USER STATUS
      final userRef = db.collection('users').doc(uid);

      tx.set(userRef, {
        'providerStatus': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  };
});
