import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final deleteAccountProvider = Provider<
  Future<void> Function({required String uid})
>((ref) {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  return ({required String uid}) async {
    // 🔒 1. CHECK ACTIVE RESERVATIONS
    final activeReservations =
        await db
            .collection('reservations')
            .where('userId', isEqualTo: uid)
            .where('state', whereIn: ['active', 'cancellation_requested'])
            .get();

    if (activeReservations.docs.isNotEmpty) {
      throw Exception(
        'Tienes reservaciones activas. No puedes eliminar tu cuenta.',
      );
    }

    // 🧹 2. DELETE FAVORITES
    final favs =
        await db.collection('favorites').where('userId', isEqualTo: uid).get();

    for (final doc in favs.docs) {
      await doc.reference.delete();
    }

    // 🧹 3. DELETE SETTINGS
    final settingsRef = db.collection('users').doc(uid).collection('settings');

    final settingsDocs = await settingsRef.get();
    for (final doc in settingsDocs.docs) {
      await doc.reference.delete();
    }

    // 🧹 4. DELETE USER DOC
    await db.collection('users').doc(uid).delete();

    // 🔥 5. DELETE AUTH USER (requires recent login)
    final user = auth.currentUser;
    if (user != null) {
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          throw Exception(
            'Por seguridad, vuelve a iniciar sesión e intenta eliminar tu cuenta nuevamente.',
          );
        }
        rethrow;
      }
    }

    // 🔓 6. FORCE SIGN OUT (safety fallback)
    await auth.signOut();
  };
});
