import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:mapbox_api/features/core/providers/firebase_providers.dart'
    show firestoreProvider, currentUserProvider;

import 'package:mapbox_api/features/users/models/vehicule.dart';
import 'package:mapbox_api/features/users/models/user_role.dart';

// ---------- Refs ----------
final userDocRefProvider =
    Provider.family<DocumentReference<Map<String, dynamic>>, String>(
      (ref, uid) => ref.watch(firestoreProvider).collection('users').doc(uid),
    );

// ---------- Perfil completo ----------
final isProfileCompleteProvider = FutureProvider.family<bool, String>((
  ref,
  uid,
) async {
  try {
    await FirebaseAuth.instance.currentUser?.reload();
  } catch (_) {}

  final snap = await ref.read(userDocRefProvider(uid)).get();
  if (!snap.exists) return false;

  final d = snap.data() ?? <String, dynamic>{};

  String s(dynamic v) => (v as String? ?? '').trim();

  final hasName = s(d['name']).isNotEmpty || s(d['displayName']).isNotEmpty;
  final hasPhone = s(d['phone']).isNotEmpty;
  final hasRole = s(d['role']).isNotEmpty;
  final hasVehiclePlate = s(d['vehiclePlate']).isNotEmpty;
  final hasVehicleType = s(d['vehicleType']).isNotEmpty;
  final completed = d['profileCompleted'] == true;

  return (hasName &&
          hasPhone &&
          hasRole &&
          hasVehiclePlate &&
          hasVehicleType) ||
      completed;
});

// ---------- Guardado de perfil ----------
final saveProfileProvider = Provider<
  Future<void> Function({
    required String name,
    required String phone,
    required String role,
    required String vehiclePlate,
    required String vehicleType,
  })
>((ref) {
  return ({
    required String name,
    required String phone,
    required String role,
    required String vehiclePlate,
    required String vehicleType,
  }) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('No authenticated user.');

    final doc = ref.read(userDocRefProvider(u.uid));

    final existing = await doc.get();
    final alreadyCreatedAt = existing.data()?['createdAt'];

    await doc.set({
      'uid': u.uid,
      'email': u.email,
      'name': name.trim(),
      'displayName': name.trim(),
      'phone': phone.trim(),
      'role': role.trim(),
      'vehiclePlate': vehiclePlate.trim().toUpperCase(),
      'vehicleType': vehicleType.trim(),
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': alreadyCreatedAt ?? FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    ref.invalidate(isProfileCompleteProvider(u.uid));
    ref.invalidate(canEnterAppProvider(u.uid));
    ref.invalidate(myProfileStreamProvider);
    ref.invalidate(myRoleStreamProvider);
  };
});

// ---------- Stream de mi perfil ----------
final myProfileStreamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();

  return ref.watch(userDocRefProvider(uid)).snapshots().map((s) => s.data());
});

final myVehiclesProvider = StreamProvider<List<Vehicle>>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return const Stream.empty();

  return ref
      .watch(userDocRefProvider(uid))
      .collection('vehicles')
      .orderBy('createdAt')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => Vehicle.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) {
            if (a.isPrimary == b.isPrimary) return 0;
            return a.isPrimary ? -1 : 1;
          }),
      );
});

// ---------- ¿tengo al menos un parking? ----------
final iOwnAtLeastOneParkingProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return false;

  final db = ref.watch(firestoreProvider);

  try {
    final q =
        await db
            .collection('parkings')
            .where('ownerID', isEqualTo: uid)
            .limit(1)
            .get();

    return q.docs.isNotEmpty;
  } catch (_) {
    return false;
  }
});

final updateBasicProfileProvider = Provider<
  Future<void> Function({
    required String name,
    required String phone,
    required String email,
    String? dob,
    String? gender,
    String? photoUrl,
  })
>((ref) {
  return ({
    required String name,
    required String phone,
    required String email,
    String? dob,
    String? gender,
    String? photoUrl,
  }) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('No authenticated user.');

    final doc = ref.read(userDocRefProvider(u.uid));

    await doc.set({
      'uid': u.uid,
      'email': email.trim(),
      'name': name.trim(),
      'displayName': name.trim(),
      'phone': phone.trim(),
      'dob': (dob ?? '').trim(),
      'gender': (gender ?? '').trim(),
      if (photoUrl != null && photoUrl.trim().isNotEmpty)
        'photoURL': photoUrl.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    ref.invalidate(isProfileCompleteProvider(u.uid));
    ref.invalidate(canEnterAppProvider(u.uid));
    ref.invalidate(myProfileStreamProvider);
    ref.invalidate(myRoleStreamProvider);
  };
});

// ---------- Rol efectivo ----------
final myRoleStreamProvider = StreamProvider<UserRole>((ref) {
  final profileAsync = ref.watch(myProfileStreamProvider);

  return profileAsync.when(
    data: (data) async* {
      final r = parseRole(data?['role'] as String?);
      if (r != UserRole.unknown) {
        yield r;
        return;
      }

      final owns = await ref.read(iOwnAtLeastOneParkingProvider.future);
      yield owns ? UserRole.provider : UserRole.user;
    },
    loading: () => const Stream<UserRole>.empty(),
    error: (_, __) async* {
      final owns = await ref.read(iOwnAtLeastOneParkingProvider.future);
      yield owns ? UserRole.provider : UserRole.user;
    },
  );
});

// ---------- ¿puede entrar a la app? ----------
// ✅ FIX: sin autoDispose + retry en PERMISSION_DENIED (ocurre durante cambio de sesión)
final canEnterAppProvider = FutureProvider.family<bool, String>((
  ref,
  uid,
) async {
  // Verifica que el uid del provider coincida con el usuario actual
  // Evita race condition durante cambio de sesión
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid != uid) {
    // El usuario cambió, espera un momento y reverifica
    await Future.delayed(const Duration(milliseconds: 500));
    final recheck = FirebaseAuth.instance.currentUser?.uid;
    if (recheck != uid) return false;
  }

  final db = ref.watch(firestoreProvider);

  bool isRecoverableAccessError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('permission-denied') ||
        msg.contains('permission denied') ||
        msg.contains('permis') ||
        msg.contains('app check') ||
        msg.contains('appcheck') ||
        msg.contains('app attestation failed') ||
        msg.contains('too many attempts') ||
        msg.contains('unavailable') ||
        msg.contains('deadline-exceeded') ||
        msg.contains('timeout');
  }

  Future<bool> _check() async {
    final doc = await db
        .collection('users')
        .doc(uid)
        .get()
        .timeout(const Duration(seconds: 8));

    if (!doc.exists) return false;

    final data = doc.data() ?? <String, dynamic>{};

    final roleStr = ((data['role'] as String?) ?? '').trim();
    final role = parseRole(roleStr);

    if (role == UserRole.provider || role == UserRole.admin) return true;

    String s(dynamic v) => (v as String? ?? '').trim();

    final hasName =
        s(data['name']).isNotEmpty || s(data['displayName']).isNotEmpty;
    final hasPhone = s(data['phone']).isNotEmpty;
    final hasRole = roleStr.isNotEmpty;
    final hasVehiclePlate = s(data['vehiclePlate']).isNotEmpty;
    final hasVehicleType = s(data['vehicleType']).isNotEmpty;
    final completed = data['profileCompleted'] == true;

    if ((hasName && hasPhone && hasRole && hasVehiclePlate && hasVehicleType) ||
        completed) {
      return true;
    }

    final owns = await db
        .collection('parkings')
        .where('ownerID', isEqualTo: uid)
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 8));

    return owns.docs.isNotEmpty;
  }

  try {
    return await _check();
  } catch (e) {
    // PERMISSION_DENIED / App Check / timeouts durante cambio de sesión o
    // primeras instalaciones de debug → reintenta antes de concluir que el
    // perfil no existe.
    if (isRecoverableAccessError(e)) {
      await Future.delayed(const Duration(seconds: 2));
      // Verifica que el uid aún sea el usuario actual antes de reintentar
      final currentAfterDelay = FirebaseAuth.instance.currentUser?.uid;
      if (currentAfterDelay != uid) return false;
      try {
        return await _check();
      } catch (retryError) {
        if (isRecoverableAccessError(retryError)) {
          throw StateError(
            'No se pudo validar el perfil en este momento. '
            'Revisa App Check o tu conexión e inténtalo de nuevo.',
          );
        }
        return false;
      }
    }
    return false;
  }
});

// ---------- Notification Settings ----------
final notificationSettingsDocProvider =
    Provider.family<DocumentReference<Map<String, dynamic>>, String>(
      (ref, uid) => ref
          .watch(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('notifications'),
    );

final notificationSettingsStreamFamilyProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
      return ref
          .watch(notificationSettingsDocProvider(uid))
          .snapshots()
          .map((s) => s.data());
    });

final myNotificationSettingsStreamProvider =
    StreamProvider<Map<String, dynamic>?>((ref) {
      final uid = ref.watch(currentUserProvider)?.uid;
      if (uid == null) return const Stream.empty();

      return ref
          .watch(notificationSettingsDocProvider(uid))
          .snapshots()
          .map((s) => s.data());
    });

final saveNotificationSettingsProvider =
    Provider<Future<void> Function(String uid, Map<String, dynamic> settings)>((
      ref,
    ) {
      return (String uid, Map<String, dynamic> settings) async {
        await ref.read(notificationSettingsDocProvider(uid)).set({
          ...settings,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      };
    });
