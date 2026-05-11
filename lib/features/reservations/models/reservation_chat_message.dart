import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationChatMessage {
  final String id;
  final String reservationId;
  final String senderId;
  final String senderRole;
  final String text;
  final DateTime createdAt;

  const ReservationChatMessage({
    required this.id,
    required this.reservationId,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  bool get isFromOwner => senderRole == 'owner';
  bool get isFromUser => senderRole == 'user';

  factory ReservationChatMessage.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAt = data['createdAt'];

    return ReservationChatMessage(
      id: doc.id,
      reservationId: (data['reservationId'] as String?) ?? '',
      senderId: (data['senderId'] as String?) ?? '',
      senderRole: (data['senderRole'] as String?) ?? 'user',
      text: (data['text'] as String?) ?? '',
      createdAt:
          createdAt is Timestamp ? createdAt.toDate() : Timestamp.now().toDate(),
    );
  }
}
