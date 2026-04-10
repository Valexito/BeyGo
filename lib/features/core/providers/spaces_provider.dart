import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final availableSpacesProvider = StreamProvider.family<int, String>((
  ref,
  parkingId,
) {
  return FirebaseFirestore.instance
      .collection('parkings')
      .doc(parkingId)
      .collection('spaces')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.where((d) => d['status'] == 'free').length;
      });
});
