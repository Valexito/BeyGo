import 'package:cloud_firestore/cloud_firestore.dart';

class Reservation {
  final String id;
  final String userId;
  final String parkingId;
  final String parkingName;
  final int spaceNumber;

  final DateTime reservedAt;
  final DateTime? endedAt;

  /// pending | active | completed | cancelled | cancellation_requested | rejected
  final String state;

  final int? pricePerHour;
  final int? amount;
  final int? durationMinutes;

  /// Cancel logic
  final int cancelAttempts;
  final DateTime? freeCancellationUntil;
  final DateTime? cancelRequestedAt;
  final String? cancellationReason;
  final bool cancellationPenaltyApplied;

  /// Provider approval (cancel flow)
  final String? providerApprovalStatus;

  /// ============================
  /// EXIT CONTROL (NEW)
  /// ============================

  /// none | requested | approved | rejected
  final String exitStatus;

  final DateTime? exitRequestedAt;
  final DateTime? exitApprovedAt;

  final String? exitRequestedBy; // userId
  final String? exitApprovedBy; // providerId

  Reservation({
    required this.id,
    required this.userId,
    required this.parkingId,
    required this.parkingName,
    required this.spaceNumber,
    required this.reservedAt,
    this.endedAt,
    this.state = 'pending',
    this.pricePerHour,
    this.amount,
    this.durationMinutes,
    this.cancelAttempts = 0,
    this.freeCancellationUntil,
    this.cancelRequestedAt,
    this.cancellationReason,
    this.cancellationPenaltyApplied = false,
    this.providerApprovalStatus,

    /// NEW
    this.exitStatus = 'none',
    this.exitRequestedAt,
    this.exitApprovedAt,
    this.exitRequestedBy,
    this.exitApprovedBy,
  });

  DateTime get startedAt => reservedAt;

  bool get hasFreeCancellationWindow => freeCancellationUntil != null;

  bool get isCancellationRequested => state == 'cancellation_requested';

  bool get isExitRequested => exitStatus == 'requested';
  bool get isExitApproved => exitStatus == 'approved';

  factory Reservation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime? parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return Reservation(
      id: doc.id,
      userId: data['userId'] ?? '',
      parkingId: data['parkingId'] ?? '',
      parkingName: data['parkingName'] ?? '',
      spaceNumber: (data['spaceNumber'] ?? 0) as int,
      reservedAt:
          parseTimestamp(data['reservedAt'] ?? data['startedAt']) ??
          Timestamp.now().toDate(),
      endedAt: parseTimestamp(data['endedAt']),
      state: data['state'] ?? 'pending',
      pricePerHour: (data['pricePerHour'] as num?)?.toInt(),
      amount: (data['amount'] as num?)?.toInt(),
      durationMinutes: (data['durationMinutes'] as num?)?.toInt(),
      cancelAttempts: (data['cancelAttempts'] as num?)?.toInt() ?? 0,
      freeCancellationUntil: parseTimestamp(data['freeCancellationUntil']),
      cancelRequestedAt: parseTimestamp(data['cancelRequestedAt']),
      cancellationReason: data['cancellationReason'] as String?,
      cancellationPenaltyApplied:
          data['cancellationPenaltyApplied'] as bool? ?? false,
      providerApprovalStatus: data['providerApprovalStatus'] as String?,

      /// NEW
      exitStatus: data['exitStatus'] ?? 'none',
      exitRequestedAt: parseTimestamp(data['exitRequestedAt']),
      exitApprovedAt: parseTimestamp(data['exitApprovedAt']),
      exitRequestedBy: data['exitRequestedBy'] as String?,
      exitApprovedBy: data['exitApprovedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'parkingId': parkingId,
      'parkingName': parkingName,
      'spaceNumber': spaceNumber,
      'reservedAt': Timestamp.fromDate(reservedAt),
      'startedAt': Timestamp.fromDate(reservedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'state': state,
      'pricePerHour': pricePerHour,
      'amount': amount,
      'durationMinutes': durationMinutes,
      'cancelAttempts': cancelAttempts,
      'freeCancellationUntil':
          freeCancellationUntil != null
              ? Timestamp.fromDate(freeCancellationUntil!)
              : null,
      'cancelRequestedAt':
          cancelRequestedAt != null
              ? Timestamp.fromDate(cancelRequestedAt!)
              : null,
      'cancellationReason': cancellationReason,
      'cancellationPenaltyApplied': cancellationPenaltyApplied,
      'providerApprovalStatus': providerApprovalStatus,

      /// NEW
      'exitStatus': exitStatus,
      'exitRequestedAt':
          exitRequestedAt != null ? Timestamp.fromDate(exitRequestedAt!) : null,
      'exitApprovedAt':
          exitApprovedAt != null ? Timestamp.fromDate(exitApprovedAt!) : null,
      'exitRequestedBy': exitRequestedBy,
      'exitApprovedBy': exitApprovedBy,
    };
  }

  Reservation copyWith({
    String? id,
    String? userId,
    String? parkingId,
    String? parkingName,
    int? spaceNumber,
    DateTime? reservedAt,
    DateTime? endedAt,
    String? state,
    int? pricePerHour,
    int? amount,
    int? durationMinutes,
    int? cancelAttempts,
    DateTime? freeCancellationUntil,
    DateTime? cancelRequestedAt,
    String? cancellationReason,
    bool? cancellationPenaltyApplied,
    String? providerApprovalStatus,

    /// NEW
    String? exitStatus,
    DateTime? exitRequestedAt,
    DateTime? exitApprovedAt,
    String? exitRequestedBy,
    String? exitApprovedBy,
  }) {
    return Reservation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      parkingId: parkingId ?? this.parkingId,
      parkingName: parkingName ?? this.parkingName,
      spaceNumber: spaceNumber ?? this.spaceNumber,
      reservedAt: reservedAt ?? this.reservedAt,
      endedAt: endedAt ?? this.endedAt,
      state: state ?? this.state,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      amount: amount ?? this.amount,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      cancelAttempts: cancelAttempts ?? this.cancelAttempts,
      freeCancellationUntil:
          freeCancellationUntil ?? this.freeCancellationUntil,
      cancelRequestedAt: cancelRequestedAt ?? this.cancelRequestedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancellationPenaltyApplied:
          cancellationPenaltyApplied ?? this.cancellationPenaltyApplied,
      providerApprovalStatus:
          providerApprovalStatus ?? this.providerApprovalStatus,

      /// NEW
      exitStatus: exitStatus ?? this.exitStatus,
      exitRequestedAt: exitRequestedAt ?? this.exitRequestedAt,
      exitApprovedAt: exitApprovedAt ?? this.exitApprovedAt,
      exitRequestedBy: exitRequestedBy ?? this.exitRequestedBy,
      exitApprovedBy: exitApprovedBy ?? this.exitApprovedBy,
    );
  }
}
