import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/reservations/reservations.dart';
import 'package:beygo/features/users/providers/user_providers.dart'
    show
        myNotificationSettingsStreamProvider,
        saveNotificationSettingsProvider;

class OwnerParkingDocument {
  const OwnerParkingDocument({
    required this.id,
    required this.data,
  });

  final String id;
  final Map<String, dynamic> data;

  String get name => (data['name'] as String? ?? '').trim();
  String get phone => (data['phone'] as String? ?? '').trim();
  String get address => (data['address'] as String? ?? '').trim();
  String get description => (data['descripcion'] as String? ?? '').trim();
  int get spaces => (data['spaces'] as num?)?.toInt() ?? 0;
  double get lat => (data['lat'] as num?)?.toDouble() ?? 0;
  double get lng => (data['lng'] as num?)?.toDouble() ?? 0;
  int get pricePerHour =>
      ((data['pricePerHour'] as num?) ?? (data['price'] as num?) ?? 0).toInt();
  bool get autoApproveReservations =>
      (data['autoApproveReservations'] as bool?) ?? false;
  bool get requirePlateOnEntry =>
      (data['requirePlateOnEntry'] as bool?) ?? true;

  Map<String, String> get businessHours {
    final raw = data['businessHours'];
    if (raw is Map) {
      return raw.map((key, value) => MapEntry('$key', '${value ?? ''}'));
    }
    return const {'open': '08:00', 'close': '18:00'};
  }

  List<String> get photos {
    final raw = data['photos'];
    if (raw is List) {
      return raw.map((e) => '$e').where((e) => e.trim().isNotEmpty).toList();
    }
    final cover = (data['coverUrl'] as String? ?? '').trim();
    return cover.isEmpty ? const [] : [cover];
  }
}

final ownerParkingDocumentProvider = StreamProvider<OwnerParkingDocument?>((
  ref,
) {
  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final uid = auth.currentUser?.uid;
  if (uid == null) return const Stream.empty();

  return db
      .collection('parkings')
      .where('ownerID', isEqualTo: uid)
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        final doc = snapshot.docs.first;
        return OwnerParkingDocument(id: doc.id, data: doc.data());
      });
});

final ownerParkingBehaviorProvider =
    Provider<Future<void> Function(String parkingId, Map<String, dynamic>)>((
      ref,
    ) {
      final db = ref.watch(firestoreProvider);

      return (String parkingId, Map<String, dynamic> changes) async {
        await db.collection('parkings').doc(parkingId).set({
          ...changes,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      };
    });

final ownerNotificationsSettingsProvider = Provider<
  Future<void> Function(String uid, Map<String, dynamic>)
>((ref) {
  return ref.watch(saveNotificationSettingsProvider);
});

final submitParkingDeletionRequestProvider =
    Provider<Future<void> Function({
      required OwnerParkingDocument parking,
      required String reason,
    })>((ref) {
      final db = ref.watch(firestoreProvider);
      final auth = ref.watch(firebaseAuthProvider);

      return ({
        required OwnerParkingDocument parking,
        required String reason,
      }) async {
        final uid = auth.currentUser?.uid;
        if (uid == null) {
          throw StateError('Debes iniciar sesión para continuar.');
        }

        final reservations = await ref.read(ownerAllReservationsProvider.future);
        final activeReservations =
            reservations.where((r) => r.state == 'active').length;
        final pendingReservations =
            reservations
                .where(
                  (r) =>
                      r.state == 'pending' ||
                      r.state == 'cancellation_requested',
                )
                .length;

        await db.collection('provider_requests').add({
          'uid': uid,
          'requestType': 'parking_deletion',
          'parkingId': parking.id,
          'parkingName': parking.name,
          'reason': reason.trim(),
          'status': 'pending',
          'activeReservations': activeReservations,
          'pendingReservations': pendingReservations,
          'requestedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      };
    });

final ownerThemePreferenceProvider = Provider((ref) {
  return ref.watch(appPreferencesProvider).themePreference;
});

final ownerNotificationSettingsStreamProvider =
    myNotificationSettingsStreamProvider;
