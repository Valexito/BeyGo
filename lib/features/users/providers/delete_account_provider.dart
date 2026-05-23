import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

final deleteAccountProvider = Provider<
  Future<void> Function({required String uid})
>((ref) {
  final auth = FirebaseAuth.instance;
  final functions = FirebaseFunctions.instance;

  return ({required String uid}) async {
    try {
      await functions.httpsCallable('deleteMyAccount').call({'uid': uid});
      await auth.signOut();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'failed-precondition') {
        throw Exception(
          e.message ??
              'Tienes reservaciones activas o pendientes. No puedes eliminar tu cuenta todavía.',
        );
      }
      if (e.code == 'unauthenticated') {
        throw Exception(
          'Tu sesión expiró. Vuelve a iniciar sesión e intenta nuevamente.',
        );
      }
      throw Exception(
        e.message ??
            'No se pudo eliminar tu cuenta en este momento. Intenta nuevamente.',
      );
    }
  };
});
