import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_api/features/core/providers/firebase_providers.dart';
import 'package:mapbox_api/features/reservations/models/parking_space.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';
import 'package:mapbox_api/features/reservations/models/parking.dart';

final _dbProvider = firestoreProvider;

DocumentReference<Map<String, dynamic>> _parkingDoc(
  FirebaseFirestore db,
  String id,
) => db.collection('parkings').doc(id);

DocumentReference<Map<String, dynamic>> _spaceDoc(
  FirebaseFirestore db,
  String parkingId,
  int spaceNumber,
) => _parkingDoc(db, parkingId).collection('spaces').doc('$spaceNumber');

DocumentReference<Map<String, dynamic>> _reservationDoc(
  FirebaseFirestore db,
  String id,
) => db.collection('reservations').doc(id);

DocumentReference<Map<String, dynamic>> _userReservationControlDoc(
  FirebaseFirestore db,
  String uid,
) => db
    .collection('users')
    .doc(uid)
    .collection('reservation_control')
    .doc('main');

const int freeCancellationWindowMinutes =
    Reservation.freeCancellationWindowMinutesLimit;
const int maxCancellationAttempts = Reservation.maxCancellationAttemptsLimit;
const int reservationCooldownDays = Reservation.reservationCooldownDaysLimit;

typedef CancellationRequestResult =
    ({
      String nextState,
      bool penaltyApplies,
      bool requiresProviderApproval,
      bool limitReached,
      int reservationCancelAttempts,
      int userCancelAttempts,
      int attemptsLeft,
      DateTime? restrictedUntil,
    });

bool _isWithinFreeCancellationWindow(Reservation reservation) {
  final now = DateTime.now();

  if (reservation.freeCancellationUntil != null) {
    return now.isBefore(reservation.freeCancellationUntil!) ||
        now.isAtSameMomentAs(reservation.freeCancellationUntil!);
  }

  final elapsedMinutes = now.difference(reservation.reservedAt).inMinutes;
  return elapsedMinutes <= freeCancellationWindowMinutes;
}

DateTime? _parseTimestamp(dynamic value) {
  if (value is Timestamp) return value.toDate();
  return null;
}

int _calculateDurationMinutes(DateTime start, DateTime end) {
  final minutes = end.difference(start).inMinutes;
  return minutes <= 0 ? 1 : minutes;
}

double _calculateAmount({
  required int pricePerHour,
  required int durationMinutes,
}) {
  final minutes = durationMinutes <= 0 ? 1 : durationMinutes;
  final pricePerMinute = pricePerHour / 60.0;
  final raw = pricePerMinute * minutes;
  return double.parse(raw.toStringAsFixed(2));
}

final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

final parkingSpacesProvider =
    StreamProvider.family<Map<int, ParkingSpace>, String>((ref, parkingId) {
      final db = ref.watch(_dbProvider);

      return _parkingDoc(db, parkingId).collection('spaces').snapshots().map((
        s,
      ) {
        final map = <int, ParkingSpace>{};

        for (final d in s.docs) {
          final n = int.tryParse(d.id);
          if (n == null) continue;
          map[n] = ParkingSpace.fromDoc(
            d as DocumentSnapshot<Map<String, dynamic>>,
          );
        }

        return map;
      });
    });

final parkingByIdProvider = FutureProvider.family<Parking, String>((
  ref,
  id,
) async {
  final db = ref.watch(_dbProvider);
  final snap = await _parkingDoc(db, id).get();
  return Parking.fromDoc(snap as DocumentSnapshot<Map<String, dynamic>>);
});

final parkingStreamProvider = StreamProvider.family<Parking, String>((ref, id) {
  final db = ref.watch(_dbProvider);

  return _parkingDoc(db, id).snapshots().map(
    (snap) => Parking.fromDoc(snap as DocumentSnapshot<Map<String, dynamic>>),
  );
});

final userReservationControlProvider = StreamProvider<Map<String, dynamic>?>((
  ref,
) {
  final db = ref.watch(_dbProvider);
  final userAsync = ref.watch(authStateProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return _userReservationControlDoc(
        db,
        user.uid,
      ).snapshots().map((doc) => doc.data());
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

final userReservationsProvider = StreamProvider<List<Reservation>>((ref) {
  final db = ref.watch(_dbProvider);
  final userAsync = ref.watch(authStateProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();

      final q = db
          .collection('reservations')
          .where('userId', isEqualTo: user.uid)
          .orderBy('reservedAt', descending: true);

      return q.snapshots().map(
        (qs) =>
            qs.docs
                .map(
                  (d) => Reservation.fromDoc(
                    d as DocumentSnapshot<Map<String, dynamic>>,
                  ),
                )
                .toList(),
      );
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

final reserveSpaceProvider = Provider<
  Future<String> Function({
    required String parkingId,
    required String parkingName,
    required int spaceNumber,
    required String vehiclePlate,
  })
>((ref) {
  final db = ref.watch(_dbProvider);
  final auth = ref.watch(firebaseAuthProvider);

  return ({
    required String parkingId,
    required String parkingName,
    required int spaceNumber,
    required String vehiclePlate,
  }) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Debes iniciar sesión para reservar.');
    }

    final userSnap = await db.collection('users').doc(uid).get();
    final userData = userSnap.data() ?? <String, dynamic>{};

    final userName = userData['name'] ?? userData['displayName'] ?? '';
    final plate = vehiclePlate.trim().toUpperCase();
    if (plate.isEmpty) {
      throw StateError('Selecciona un vehículo para continuar.');
    }

    final controlRef = _userReservationControlDoc(db, uid);
    final controlSnap = await controlRef.get();
    final controlData = controlSnap.data() ?? <String, dynamic>{};
    final restrictedUntil = _parseTimestamp(controlData['restrictedUntil']);

    if (restrictedUntil != null && DateTime.now().isBefore(restrictedUntil)) {
      throw StateError('No puedes reservar temporalmente.');
    }

    final parkingSnap = await _parkingDoc(db, parkingId).get();
    if (!parkingSnap.exists) {
      throw StateError('El parqueo no existe.');
    }

    final p = Parking.fromDoc(
      parkingSnap as DocumentSnapshot<Map<String, dynamic>>,
    );

    if (p.ownerID.trim().isEmpty) {
      throw StateError('El parqueo no tiene ownerID válido.');
    }

    final resRef = db.collection('reservations').doc();
    final spaceRef = _spaceDoc(db, parkingId, spaceNumber);

    final now = DateTime.now();
    final freeUntil = now.add(
      const Duration(minutes: freeCancellationWindowMinutes),
    );
    final number = _generateReservationNumber();

    final reservation = Reservation(
      id: resRef.id,
      reservationNumber: number,
      userId: uid,
      parkingId: parkingId,
      parkingName: parkingName,
      ownerId: p.ownerID,
      userName: userName,
      plate: plate,
      spaceNumber: spaceNumber,
      reservedAt: now,
      state: 'pending',
      providerApprovalStatus: 'pending',
      pricePerHour: p.pricePerHour,
      freeCancellationUntil: freeUntil,
      exitStatus: 'none',
    );

    await db.runTransaction((tx) async {
      final spaceSnap = await tx.get(spaceRef);
      final spaceData = spaceSnap.data() as Map<String, dynamic>? ?? {};

      final currentStatus =
          ((spaceData['status'] ?? 'free') as String).toLowerCase().trim();

      if (currentStatus != 'free') {
        throw StateError('El espacio ya no está disponible.');
      }

      tx.set(resRef, reservation.toMap());

      tx.set(spaceRef, {
        'status': 'requested',
        'currentReservationId': resRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    return resRef.id;
  };
});

final cancelReservationProvider =
    Provider<Future<void> Function({required Reservation reservation})>((ref) {
      final db = ref.watch(_dbProvider);
      final auth = ref.watch(firebaseAuthProvider);

      return ({required Reservation reservation}) async {
        final uid = auth.currentUser?.uid;
        if (uid == null) {
          throw StateError('Debes iniciar sesión.');
        }

        if (reservation.userId != uid) {
          throw StateError('No puedes cancelar esta reservación.');
        }

        if (reservation.state != 'active') {
          throw StateError('Solo una reserva activa puede cancelarse.');
        }

        if (reservation.exitStatus == 'requested' ||
            reservation.exitStatus == 'approved') {
          throw StateError(
            'No puedes cancelar una reserva con salida en proceso.',
          );
        }

        final reservationRef = _reservationDoc(db, reservation.id);
        final spaceRef = _spaceDoc(
          db,
          reservation.parkingId,
          reservation.spaceNumber,
        );
        final controlRef = _userReservationControlDoc(db, uid);

        final now = DateTime.now();
        final isFreeWindow = _isWithinFreeCancellationWindow(reservation);

        if (isFreeWindow) {
          await db.runTransaction((tx) async {
            final latestReservationSnap = await tx.get(reservationRef);
            final spaceSnap = await tx.get(spaceRef);

            if (!latestReservationSnap.exists) {
              throw StateError('La reservación ya no existe.');
            }

            final latestReservation = Reservation.fromDoc(
              latestReservationSnap as DocumentSnapshot<Map<String, dynamic>>,
            );

            if (latestReservation.state != 'active') {
              throw StateError('La reservación ya no está activa.');
            }

            final spaceData = spaceSnap.data() as Map<String, dynamic>? ?? {};

            tx.update(reservationRef, {
              'state': 'cancelled',
              'endedAt': Timestamp.fromDate(now),
              'cancelRequestedAt': Timestamp.fromDate(now),
              'cancellationReason': 'Cancelación dentro del tiempo permitido',
              'cancellationPenaltyApplied': false,
              'providerApprovalStatus': null,
            });

            if ((spaceData['status'] ?? 'free') == 'occupied' &&
                spaceData['currentReservationId'] == reservation.id) {
              tx.set(spaceRef, {
                'status': 'free',
                'currentReservationId': null,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          });

          return;
        }

        await db.runTransaction((tx) async {
          final latestReservationSnap = await tx.get(reservationRef);
          final controlSnap = await tx.get(controlRef);

          if (!latestReservationSnap.exists) {
            throw StateError('La reservación ya no existe.');
          }

          final latestReservation = Reservation.fromDoc(
            latestReservationSnap as DocumentSnapshot<Map<String, dynamic>>,
          );

          if (latestReservation.state != 'active') {
            throw StateError('La reservación ya no está activa.');
          }

          final controlData = controlSnap.data() as Map<String, dynamic>? ?? {};

          final currentAttempts =
              (controlData['cancelAttempts'] as num?)?.toInt() ?? 0;
          final nextAttempts = currentAttempts + 1;
          final limitReached = nextAttempts >= maxCancellationAttempts;
          final restrictedUntil =
              limitReached
                  ? now.add(const Duration(days: reservationCooldownDays))
                  : null;

          tx.update(reservationRef, {
            'state': 'cancellation_requested',
            'cancelRequestedAt': Timestamp.fromDate(now),
            'cancellationReason': 'Cancelación fuera del tiempo permitido',
            'cancellationPenaltyApplied': true,
            'providerApprovalStatus': 'pending',
            'cancelAttempts': (latestReservation.cancelAttempts) + 1,
            'userCancelAttempts': nextAttempts,
            'restrictedUntil':
                restrictedUntil != null
                    ? Timestamp.fromDate(restrictedUntil)
                    : null,
          });

          if (controlSnap.exists) {
            tx.update(controlRef, {
              'cancelAttempts': nextAttempts,
              'restrictedUntil':
                  restrictedUntil != null
                      ? Timestamp.fromDate(restrictedUntil)
                      : null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            tx.set(controlRef, {
              'userId': uid,
              'cancelAttempts': nextAttempts,
              'restrictedUntil':
                  restrictedUntil != null
                      ? Timestamp.fromDate(restrictedUntil)
                      : null,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        });
      };
    });

final requestExitProvider =
    Provider<Future<void> Function({required Reservation reservation})>((ref) {
      final db = ref.watch(_dbProvider);
      final auth = ref.watch(firebaseAuthProvider);

      return ({required Reservation reservation}) async {
        final uid = auth.currentUser?.uid;
        if (uid == null) {
          throw StateError('Debes iniciar sesión.');
        }

        if (reservation.state != 'active') {
          throw StateError('Solo una reserva activa puede solicitar salida.');
        }

        if (reservation.exitStatus == 'requested') {
          throw StateError('La salida ya fue solicitada.');
        }

        if (reservation.exitStatus == 'approved') {
          throw StateError('La salida ya fue aprobada.');
        }

        final now = DateTime.now();
        final durationMinutes = _calculateDurationMinutes(
          reservation.reservedAt,
          now,
        );
        final pricePerHour = reservation.pricePerHour ?? 0;
        final estimatedAmount = _calculateAmount(
          pricePerHour: pricePerHour,
          durationMinutes: durationMinutes,
        );

        await _reservationDoc(db, reservation.id).update({
          'exitStatus': 'requested',
          'exitRequestedAt': FieldValue.serverTimestamp(),
          'exitRequestedBy': uid,
          'estimatedAmount': estimatedAmount,
          'estimatedDurationMinutes': durationMinutes,
          'exitLockedAt': FieldValue.serverTimestamp(),
        });
      };
    });

final completeReservationWithBillingProvider =
    Provider<Future<void> Function({required Reservation r})>((ref) {
      final db = ref.watch(_dbProvider);

      return ({required Reservation r}) async {
        if (r.state != 'active') {
          throw StateError('Solo una reserva activa puede completarse.');
        }

        if (r.exitStatus != 'approved') {
          throw StateError('La salida debe ser aprobada.');
        }

        final end = DateTime.now();
        final durationMinutes = _calculateDurationMinutes(r.reservedAt, end);
        final pricePerHour = r.pricePerHour ?? 0;
        final amount = _calculateAmount(
          pricePerHour: pricePerHour,
          durationMinutes: durationMinutes,
        );

        final reservationRef = _reservationDoc(db, r.id);
        final spaceRef = _spaceDoc(db, r.parkingId, r.spaceNumber);

        await db.runTransaction((tx) async {
          final reservationSnap = await tx.get(reservationRef);
          if (!reservationSnap.exists) {
            throw StateError('La reservación ya no existe.');
          }

          final latestReservation = Reservation.fromDoc(
            reservationSnap as DocumentSnapshot<Map<String, dynamic>>,
          );

          if (latestReservation.state != 'active') {
            throw StateError('La reservación ya no está activa.');
          }

          if (latestReservation.exitStatus != 'approved') {
            throw StateError('La salida debe estar aprobada.');
          }

          tx.update(reservationRef, {
            'state': 'completed',
            'endedAt': Timestamp.fromDate(end),
            'durationMinutes': durationMinutes,
            'pricePerHour': pricePerHour,
            'amount': amount,
          });

          final spaceSnap = await tx.get(spaceRef);
          final spaceData = spaceSnap.data() as Map<String, dynamic>? ?? {};

          if ((spaceData['status'] ?? 'free') == 'occupied' &&
              spaceData['currentReservationId'] == r.id) {
            tx.set(spaceRef, {
              'status': 'free',
              'currentReservationId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        });
      };
    });

final ownerManagedParkingIdsProvider = FutureProvider<List<String>>((
  ref,
) async {
  final db = ref.watch(_dbProvider);
  final auth = ref.watch(firebaseAuthProvider);

  final uid = auth.currentUser?.uid;
  if (uid == null) return [];

  final snap =
      await db.collection('parkings').where('ownerID', isEqualTo: uid).get();

  return snap.docs.map((d) => d.id).toList();
});

final ownerAllReservationsProvider = StreamProvider<List<Reservation>>((ref) {
  final db = ref.watch(_dbProvider);
  final userAsync = ref.watch(authStateProvider);

  return userAsync.when(
    data: (user) {
      if (user == null) return const Stream.empty();

      final q = db
          .collection('reservations')
          .where('ownerId', isEqualTo: user.uid)
          .orderBy('reservedAt', descending: true);

      return q.snapshots().map(
        (qs) =>
            qs.docs
                .map(
                  (d) => Reservation.fromDoc(
                    d as DocumentSnapshot<Map<String, dynamic>>,
                  ),
                )
                .toList(),
      );
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

final ownerExitRequestsProvider = Provider<AsyncValue<List<Reservation>>>((
  ref,
) {
  final allAsync = ref.watch(ownerAllReservationsProvider);
  return allAsync.whenData(
    (items) => items.where((r) => r.exitStatus == 'requested').toList(),
  );
});

final ownerCancellationRequestsProvider =
    Provider<AsyncValue<List<Reservation>>>((ref) {
      final allAsync = ref.watch(ownerAllReservationsProvider);
      return allAsync.whenData(
        (items) =>
            items.where((r) => r.state == 'cancellation_requested').toList(),
      );
    });

final ownerConfirmExitProvider =
    Provider<Future<void> Function({required Reservation reservation})>((ref) {
      final db = ref.watch(_dbProvider);

      return ({required Reservation reservation}) async {
        final reservationRef = _reservationDoc(db, reservation.id);
        final spaceRef = _spaceDoc(
          db,
          reservation.parkingId,
          reservation.spaceNumber,
        );

        await db.runTransaction((tx) async {
          final reservationSnap = await tx.get(reservationRef);
          final spaceSnap = await tx.get(spaceRef);

          if (!reservationSnap.exists) {
            throw StateError('La reservación ya no existe.');
          }

          final latest = Reservation.fromDoc(
            reservationSnap as DocumentSnapshot<Map<String, dynamic>>,
          );

          if (latest.exitStatus != 'requested') {
            throw StateError('La salida ya no está pendiente.');
          }

          final spaceData = spaceSnap.data() as Map<String, dynamic>? ?? {};

          tx.update(reservationRef, {
            'state': 'completed',
            'exitStatus': 'approved',
            'exitApprovedAt': FieldValue.serverTimestamp(),
            'endedAt':
                latest.exitRequestedAt != null
                    ? Timestamp.fromDate(latest.exitRequestedAt!)
                    : FieldValue.serverTimestamp(),
            'durationMinutes': latest.estimatedDurationMinutes,
            'amount': latest.estimatedAmount,
          });

          final currentStatus =
              (spaceData['status'] ?? 'free').toString().toLowerCase().trim();

          if ((currentStatus == 'occupied' || currentStatus == 'requested') &&
              spaceData['currentReservationId'] == reservation.id) {
            tx.set(spaceRef, {
              'status': 'free',
              'currentReservationId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        });
      };
    });

final ownerConfirmCancellationProvider =
    Provider<Future<void> Function({required Reservation reservation})>((ref) {
      final db = ref.watch(_dbProvider);

      return ({required Reservation reservation}) async {
        final reservationRef = _reservationDoc(db, reservation.id);
        final spaceRef = _spaceDoc(
          db,
          reservation.parkingId,
          reservation.spaceNumber,
        );

        final now = DateTime.now();

        await db.runTransaction((tx) async {
          final reservationSnap = await tx.get(reservationRef);
          final spaceSnap = await tx.get(spaceRef);

          if (!reservationSnap.exists) {
            throw StateError('La reservación ya no existe.');
          }

          final latest = Reservation.fromDoc(
            reservationSnap as DocumentSnapshot<Map<String, dynamic>>,
          );

          if (latest.state != 'cancellation_requested') {
            throw StateError('La cancelación ya no está pendiente.');
          }

          final spaceData = spaceSnap.data() as Map<String, dynamic>? ?? {};

          tx.update(reservationRef, {
            'state': 'cancelled',
            'providerApprovalStatus': 'approved',
            'endedAt': Timestamp.fromDate(now),
          });

          final currentStatus =
              (spaceData['status'] ?? 'free').toString().toLowerCase().trim();

          if ((currentStatus == 'occupied' || currentStatus == 'requested') &&
              spaceData['currentReservationId'] == reservation.id) {
            tx.set(spaceRef, {
              'status': 'free',
              'currentReservationId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        });
      };
    });

final ownerApproveReservationProvider =
    Provider<Future<void> Function({required Reservation reservation})>((ref) {
      final db = ref.watch(_dbProvider);

      return ({required Reservation reservation}) async {
        final reservationRef = _reservationDoc(db, reservation.id);
        final spaceRef = _spaceDoc(
          db,
          reservation.parkingId,
          reservation.spaceNumber,
        );

        await db.runTransaction((tx) async {
          final reservationSnap = await tx.get(reservationRef);
          final spaceSnap = await tx.get(spaceRef);

          if (!reservationSnap.exists) {
            throw StateError('La reservación ya no existe.');
          }

          final latest = Reservation.fromDoc(
            reservationSnap as DocumentSnapshot<Map<String, dynamic>>,
          );

          if (latest.state != 'pending') {
            throw StateError('La reservación ya no está pendiente.');
          }

          final spaceData = spaceSnap.data() as Map<String, dynamic>? ?? {};

          final currentStatus =
              (spaceData['status'] ?? 'free').toString().toLowerCase().trim();

          if (currentStatus != 'requested') {
            throw StateError('El espacio ya no está en estado solicitado.');
          }

          final number = _generateReservationNumber();

          tx.set(reservationRef, {
            'state': 'active',
            'providerApprovalStatus': 'approved',
            'reservationNumber': number,
            'ownerId': reservation.ownerId, // 🔥
          }, SetOptions(merge: true));
          tx.set(spaceRef, {
            'status': 'occupied',
            'currentReservationId': reservation.id,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });
      };
    });

/// Force-completes an active reservation as the owner.
/// Cancels the reservation, frees the space, and stores the reason as evidence.
/// NOTE: User strike must be applied via Cloud Function (future).
final ownerForceCancelProvider = Provider<
  Future<void> Function({
    required Reservation reservation,
    required String reason,
  })
>((ref) {
  final db = ref.watch(_dbProvider);

  return ({required Reservation reservation, required String reason}) async {
    final reservationRef = _reservationDoc(db, reservation.id);
    final spaceRef = _spaceDoc(
      db,
      reservation.parkingId,
      reservation.spaceNumber,
    );

    final now = DateTime.now();

    await db.runTransaction((tx) async {
      final reservationSnap = await tx.get(reservationRef);
      final spaceSnap = await tx.get(spaceRef);

      if (!reservationSnap.exists) {
        throw StateError('La reservación ya no existe.');
      }

      final latest = Reservation.fromDoc(
        reservationSnap as DocumentSnapshot<Map<String, dynamic>>,
      );

      if (latest.state != 'active' && latest.state != 'pending') {
        throw StateError('La reservación no puede ser cancelada.');
      }

      tx.update(reservationRef, {
        'state': 'cancelled',
        'endedAt': Timestamp.fromDate(now),
        'cancellationReason':
            reason.trim().isEmpty
                ? 'Cancelado por el propietario'
                : reason.trim(),
        'cancellationPenaltyApplied': true,
        'providerApprovalStatus': 'approved',
      });

      final spaceData = spaceSnap.data() as Map<String, dynamic>? ?? {};
      final currentStatus =
          (spaceData['status'] ?? 'free').toString().toLowerCase().trim();

      if ((currentStatus == 'occupied' || currentStatus == 'requested') &&
          spaceData['currentReservationId'] == reservation.id) {
        tx.set(spaceRef, {
          'status': 'free',
          'currentReservationId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  };
});

String _generateReservationNumber() {
  final now = DateTime.now();
  final ts = now.millisecondsSinceEpoch.toString().substring(8);
  final random = (1000 + (now.microsecondsSinceEpoch % 9000)).toString();
  return 'RES-$ts$random';
}
// ─────────────────────────────────────────────────────────────────────────────
// ADD THIS TO THE END OF:
//   lib/features/reservations/providers/reservations_providers.dart
//
// After ownerForceCancelProvider and _generateReservationNumber()
// ─────────────────────────────────────────────────────────────────────────────

/// Owner rejects a pending reservation.
/// Sets state → 'cancelled', providerApprovalStatus → 'rejected',
/// and frees the space if it was in 'requested' status.
final ownerRejectReservationProvider =
    Provider<Future<void> Function({required Reservation reservation})>((ref) {
      final db = ref.watch(_dbProvider);

      return ({required Reservation reservation}) async {
        final reservationRef = _reservationDoc(db, reservation.id);
        final spaceRef = _spaceDoc(
          db,
          reservation.parkingId,
          reservation.spaceNumber,
        );

        final now = DateTime.now();

        await db.runTransaction((tx) async {
          final reservationSnap = await tx.get(reservationRef);
          final spaceSnap = await tx.get(spaceRef);

          if (!reservationSnap.exists) {
            throw StateError('La reservación ya no existe.');
          }

          final latest = Reservation.fromDoc(
            reservationSnap as DocumentSnapshot<Map<String, dynamic>>,
          );

          if (latest.state != 'pending') {
            throw StateError(
              'Solo se pueden rechazar reservas en estado pendiente.',
            );
          }

          tx.update(reservationRef, {
            'state': 'cancelled',
            'providerApprovalStatus': 'rejected',
            'endedAt': Timestamp.fromDate(now),
            'cancellationReason': 'Rechazada por el propietario',
          });

          final spaceData = spaceSnap.data() as Map<String, dynamic>? ?? {};
          final currentStatus =
              (spaceData['status'] ?? 'free').toString().toLowerCase().trim();

          // Free the space if it was reserved for this reservation
          if (currentStatus == 'requested' &&
              spaceData['currentReservationId'] == reservation.id) {
            tx.set(spaceRef, {
              'status': 'free',
              'currentReservationId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        });
      };
    });
