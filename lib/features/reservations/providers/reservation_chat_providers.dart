import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/reservations/models/reservation.dart';
import 'package:beygo/features/reservations/models/reservation_chat_message.dart';

final reservationChatMessagesProvider =
    StreamProvider.family<List<ReservationChatMessage>, String>((
      ref,
      reservationId,
    ) {
      final db = ref.watch(firestoreProvider);
      return db
          .collection('reservations')
          .doc(reservationId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map(
            (qs) =>
                qs.docs
                    .map((doc) => ReservationChatMessage.fromDoc(doc))
                    .toList(),
          );
    });

final sendReservationChatMessageProvider = Provider<
  Future<void> Function({
    required Reservation reservation,
    required String text,
  })
>((ref) {
  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);

  return ({required Reservation reservation, required String text}) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Debes iniciar sesión para enviar mensajes.');
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (trimmed.length > 500) {
      throw StateError('El mensaje no puede exceder 500 caracteres.');
    }

    final senderRole = uid == reservation.ownerId ? 'owner' : 'user';

    await db
        .collection('reservations')
        .doc(reservation.id)
        .collection('messages')
        .add({
          'reservationId': reservation.id,
          'senderId': uid,
          'senderRole': senderRole,
          'text': trimmed,
          'createdAt': Timestamp.now(),
        });
  };
});
