import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_api/features/core/providers/firebase_providers.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';
import 'package:mapbox_api/features/reservations/models/parking.dart';
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';

// ─── Owner's single parking (stream) ─────────────────────────────────────────
final ownerParkingProvider = StreamProvider<Parking?>((ref) {
  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final uid = auth.currentUser?.uid;
  if (uid == null) return const Stream.empty();

  return db
      .collection('parkings')
      .where('ownerID', isEqualTo: uid)
      .limit(1)
      .snapshots()
      .map((snap) {
        if (snap.docs.isEmpty) return null;
        return Parking.fromDoc(
          snap.docs.first as DocumentSnapshot<Map<String, dynamic>>,
        );
      });
});

// ─── Dashboard stats model ────────────────────────────────────────────────────
class OwnerDashboardStats {
  final int activeReservations;
  final int pendingApproval;
  final int exitRequests;
  final int cancellationRequests;
  final int completedToday;
  final int completedThisMonth;
  final double revenueToday;
  final double revenueThisMonth;
  final double revenueAllTime;
  final int totalSpaces;
  final int occupiedSpaces;
  final int cancelledTotal;
  final List<Reservation> recentActivity;

  const OwnerDashboardStats({
    this.activeReservations = 0,
    this.pendingApproval = 0,
    this.exitRequests = 0,
    this.cancellationRequests = 0,
    this.completedToday = 0,
    this.completedThisMonth = 0,
    this.revenueToday = 0,
    this.revenueThisMonth = 0,
    this.revenueAllTime = 0,
    this.totalSpaces = 0,
    this.occupiedSpaces = 0,
    this.cancelledTotal = 0,
    this.recentActivity = const [],
  });

  double get occupancyRate =>
      totalSpaces == 0 ? 0 : (occupiedSpaces / totalSpaces) * 100;
}

// ─── Dashboard stats provider ─────────────────────────────────────────────────
final ownerDashboardStatsProvider = StreamProvider<OwnerDashboardStats>((
  ref,
) async* {
  final allAsync = ref.watch(ownerAllReservationsProvider);
  final parkingAsync = ref.watch(ownerParkingProvider);

  // Emit loading state until both are ready
  final allReservations = allAsync.asData?.value;
  final parking = parkingAsync.asData?.value;

  if (allReservations == null) return;

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final monthStart = DateTime(now.year, now.month, 1);

  // Active
  final active = allReservations.where((r) => r.state == 'active').toList();

  // Pending owner approval
  final pending =
      allReservations
          .where(
            (r) =>
                r.state == 'pending' && r.providerApprovalStatus == 'pending',
          )
          .toList();

  // Exit requests
  final exitRequests =
      allReservations.where((r) => r.exitStatus == 'requested').toList();

  // Cancellation requests
  final cancellationRequests =
      allReservations
          .where((r) => r.state == 'cancellation_requested')
          .toList();

  // Completed today
  final completedToday =
      allReservations.where((r) {
        if (r.state != 'completed') return false;
        final end = r.endedAt;
        if (end == null) return false;
        return !end.isBefore(todayStart);
      }).toList();

  // Completed this month
  final completedMonth =
      allReservations.where((r) {
        if (r.state != 'completed') return false;
        final end = r.endedAt;
        if (end == null) return false;
        return !end.isBefore(monthStart);
      }).toList();

  // Revenue today
  final revenueToday = completedToday.fold<double>(
    0,
    (sum, r) => sum + (r.amount?.toDouble() ?? 0),
  );

  // Revenue this month
  final revenueMonth = completedMonth.fold<double>(
    0,
    (sum, r) => sum + (r.amount?.toDouble() ?? 0),
  );

  // Revenue all time
  final revenueAll = allReservations
      .where((r) => r.state == 'completed')
      .fold<double>(0, (sum, r) => sum + (r.amount?.toDouble() ?? 0));

  // Cancelled
  final cancelled = allReservations.where((r) => r.state == 'cancelled').length;

  // Recent activity (last 5 any state)
  final sorted = [...allReservations]
    ..sort((a, b) => b.reservedAt.compareTo(a.reservedAt));
  final recent = sorted.take(5).toList();

  // Spaces from parking
  final totalSpaces = parking?.spaces ?? 0;
  final occupiedSpaces = active.length;

  yield OwnerDashboardStats(
    activeReservations: active.length,
    pendingApproval: pending.length,
    exitRequests: exitRequests.length,
    cancellationRequests: cancellationRequests.length,
    completedToday: completedToday.length,
    completedThisMonth: completedMonth.length,
    revenueToday: revenueToday,
    revenueThisMonth: revenueMonth,
    revenueAllTime: revenueAll,
    totalSpaces: totalSpaces,
    occupiedSpaces: occupiedSpaces,
    cancelledTotal: cancelled,
    recentActivity: recent,
  );
});
