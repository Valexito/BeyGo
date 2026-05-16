import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/reservations/models/reservation.dart';
import 'package:beygo/features/reservations/models/reservation_chat_message.dart';
import 'package:uuid/uuid.dart';

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
    final peerUid = uid == reservation.ownerId ? reservation.userId : reservation.ownerId;

    final myBlockRef = db
        .collection('reservations')
        .doc(reservation.id)
        .collection('chat_blocks')
        .doc(uid);
    final peerBlockRef = db
        .collection('reservations')
        .doc(reservation.id)
        .collection('chat_blocks')
        .doc(peerUid);

    final snapshots = await Future.wait([myBlockRef.get(), peerBlockRef.get()]);
    final myBlock = snapshots[0];
    final peerBlock = snapshots[1];

    if (myBlock.exists) {
      throw StateError(
        'Bloqueaste a este participante. Desbloquéalo para enviar mensajes.',
      );
    }

    if (peerBlock.exists) {
      final blockedUid = (peerBlock.data()?['blockedUid'] as String?) ?? '';
      if (blockedUid == uid) {
        throw StateError(
          'Este participante bloqueó la conversación y ya no acepta nuevos mensajes.',
        );
      }
    }

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

class ReservationChatBlockState {
  final bool blockedByMe;
  final bool blockedByPeer;
  final String? blockerUid;

  const ReservationChatBlockState({
    required this.blockedByMe,
    required this.blockedByPeer,
    this.blockerUid,
  });

  bool get isConversationBlocked => blockedByMe || blockedByPeer;
}

final reservationChatBlockStateProvider =
    StreamProvider.family<ReservationChatBlockState, Reservation>((
      ref,
      reservation,
    ) {
      final db = ref.watch(firestoreProvider);
      final auth = ref.watch(firebaseAuthProvider);
      final currentUid = auth.currentUser?.uid ?? '';

      if (currentUid.isEmpty) {
        return Stream.value(
          const ReservationChatBlockState(
            blockedByMe: false,
            blockedByPeer: false,
          ),
        );
      }

      final peerUid =
          currentUid == reservation.ownerId ? reservation.userId : reservation.ownerId;

      return db
          .collection('reservations')
          .doc(reservation.id)
          .collection('chat_blocks')
          .snapshots()
          .map((snap) {
            bool blockedByMe = false;
            bool blockedByPeer = false;
            String? blockerUid;

            for (final doc in snap.docs) {
              final data = doc.data();
              final docBlockerUid = (data['blockerUid'] as String?) ?? doc.id;
              final blockedUid = (data['blockedUid'] as String?) ?? '';

              if (docBlockerUid == currentUid && blockedUid == peerUid) {
                blockedByMe = true;
                blockerUid = currentUid;
              }

              if (docBlockerUid == peerUid && blockedUid == currentUid) {
                blockedByPeer = true;
                blockerUid = peerUid;
              }
            }

            return ReservationChatBlockState(
              blockedByMe: blockedByMe,
              blockedByPeer: blockedByPeer,
              blockerUid: blockerUid,
            );
          });
    });

final blockReservationChatParticipantProvider = Provider<
  Future<void> Function({required Reservation reservation})
>((ref) {
  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);

  return ({required Reservation reservation}) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Debes iniciar sesión.');

    final peerUid = uid == reservation.ownerId ? reservation.userId : reservation.ownerId;
    if (peerUid.isEmpty) {
      throw StateError('No se encontró el participante para bloquear.');
    }

    await db
        .collection('reservations')
        .doc(reservation.id)
        .collection('chat_blocks')
        .doc(uid)
        .set({
          'reservationId': reservation.id,
          'blockerUid': uid,
          'blockedUid': peerUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
  };
});

final unblockReservationChatParticipantProvider = Provider<
  Future<void> Function({required Reservation reservation})
>((ref) {
  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);

  return ({required Reservation reservation}) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Debes iniciar sesión.');

    await db
        .collection('reservations')
        .doc(reservation.id)
        .collection('chat_blocks')
        .doc(uid)
        .delete();
  };
});

final reportReservationChatMessageProvider = Provider<
  Future<String> Function({
    required Reservation reservation,
    required ReservationChatMessage message,
  })
>((ref) {
  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);

  return ({
    required Reservation reservation,
    required ReservationChatMessage message,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('Debes iniciar sesión.');

    final reportId = const Uuid().v4();
    final reportNumber = 'REP-${reportId.split('-').first.toUpperCase()}';

    await db.collection('support_reports').doc(reportId).set({
      'reportId': reportId,
      'reportNumber': reportNumber,
      'userId': user.uid,
      'userEmail': user.email,
      'reportType': 'chat_message',
      'subject': 'Reporte de mensaje de chat',
      'message':
          'Mensaje reportado en reservación ${reservation.id}. '
          'Autor: ${message.senderId}. Contenido: ${message.text}',
      'reservationId': reservation.id,
      'messageId': message.id,
      'reportedUid': message.senderId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return reportNumber;
  };
});
