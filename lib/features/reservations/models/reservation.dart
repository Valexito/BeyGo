import 'package:cloud_firestore/cloud_firestore.dart';

class Reservation {
  static const int maxCancellationAttemptsLimit = 2;
  static const int freeCancellationWindowMinutesLimit = 1;
  static const int reservationCooldownDaysLimit = 20;

  final String id;
  final String? reservationNumber;
  final String userId;
  final String parkingId;
  final String parkingName;
  final String ownerId;
  final String? userName;
  final String? plate;
  final int spaceNumber;

  final DateTime reservedAt;
  final DateTime? endedAt;

  /// pending | active | completed | cancelled | rejected | cancellation_requested
  final String state;

  final int? pricePerHour;
  final int? amount;
  final int? durationMinutes;
  final int? estimatedAmount;
  final int? estimatedDurationMinutes;

  /// Intentos acumulados del usuario al momento de esta reserva.
  final int cancelAttempts;

  /// Total acumulado de cancelaciones penalizadas del usuario.
  final int userCancelAttempts;

  /// Fin de la ventana de cancelación gratis.
  final DateTime? freeCancellationUntil;

  /// Momento en que el usuario solicitó cancelar.
  final DateTime? cancelRequestedAt;

  /// Motivo opcional de cancelación.
  final String? cancellationReason;

  /// true si la cancelación contó como penalizada.
  final bool cancellationPenaltyApplied;

  /// pending | approved | rejected
  final String? providerApprovalStatus;

  /// none | requested | approved | rejected
  final String exitStatus;
  final DateTime? exitRequestedAt;
  final DateTime? exitApprovedAt;
  final DateTime? exitLockedAt;
  final String? exitRequestedBy;
  final String? exitApprovedBy;

  /// Restricción futura para nuevas reservas.
  final DateTime? restrictedUntil;

  const Reservation({
    required this.id,
    this.reservationNumber,
    required this.userId,
    required this.parkingId,
    required this.parkingName,
    required this.ownerId,
    this.userName,
    this.plate,
    required this.spaceNumber,
    required this.reservedAt,
    this.endedAt,
    this.state = 'pending',
    this.pricePerHour,
    this.amount,
    this.durationMinutes,
    this.estimatedAmount,
    this.estimatedDurationMinutes,
    this.cancelAttempts = 0,
    this.userCancelAttempts = 0,
    this.freeCancellationUntil,
    this.cancelRequestedAt,
    this.cancellationReason,
    this.cancellationPenaltyApplied = false,
    this.providerApprovalStatus,
    this.exitStatus = 'none',
    this.exitRequestedAt,
    this.exitApprovedAt,
    this.exitLockedAt,
    this.exitRequestedBy,
    this.exitApprovedBy,
    this.restrictedUntil,
  });

  DateTime get startedAt => reservedAt;

  bool get hasFreeCancellationWindow => freeCancellationUntil != null;

  bool get isCancellationRequested => state == 'cancellation_requested';

  bool get isRestrictedNow {
    if (restrictedUntil == null) return false;
    final now = DateTime.now();
    return now.isBefore(restrictedUntil!) ||
        now.isAtSameMomentAs(restrictedUntil!);
  }

  int get attemptsLeft {
    final left = maxCancellationAttemptsLimit - userCancelAttempts;
    return left < 0 ? 0 : left;
  }

  bool get isExitRequested => exitStatus == 'requested';
  bool get isExitApproved => exitStatus == 'approved';
  bool get isExitRejected => exitStatus == 'rejected';
  bool get isPending => state == 'pending';
  bool get isRejected => state == 'rejected';
  bool get isActive => state == 'active';

  bool get isApproved => providerApprovalStatus == 'approved';
  bool get isRejectedByProvider => providerApprovalStatus == 'rejected';

  factory Reservation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    DateTime? parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return Reservation(
      id: doc.id,
      reservationNumber: data['reservationNumber'] as String?,
      userId: (data['userId'] as String?) ?? '',
      parkingId: (data['parkingId'] as String?) ?? '',
      parkingName: (data['parkingName'] as String?) ?? '',
      ownerId: (data['ownerId'] as String?) ?? '',
      userName: data['userName'] as String?,
      plate: data['plate'] as String?,
      spaceNumber: (data['spaceNumber'] as num?)?.toInt() ?? 0,
      reservedAt:
          parseTimestamp(data['reservedAt'] ?? data['startedAt']) ??
          Timestamp.now().toDate(),
      endedAt: parseTimestamp(data['endedAt']),
      state: (data['state'] as String?) ?? 'pending',
      pricePerHour: (data['pricePerHour'] as num?)?.toInt(),
      amount: (data['amount'] as num?)?.toInt(),
      durationMinutes: (data['durationMinutes'] as num?)?.toInt(),
      estimatedAmount: (data['estimatedAmount'] as num?)?.toInt(),
      estimatedDurationMinutes:
          (data['estimatedDurationMinutes'] as num?)?.toInt(),
      cancelAttempts: (data['cancelAttempts'] as num?)?.toInt() ?? 0,
      userCancelAttempts: (data['userCancelAttempts'] as num?)?.toInt() ?? 0,
      freeCancellationUntil: parseTimestamp(data['freeCancellationUntil']),
      cancelRequestedAt: parseTimestamp(data['cancelRequestedAt']),
      cancellationReason: data['cancellationReason'] as String?,
      cancellationPenaltyApplied:
          data['cancellationPenaltyApplied'] as bool? ?? false,
      providerApprovalStatus: data['providerApprovalStatus'] as String?,
      exitStatus: (data['exitStatus'] as String?) ?? 'none',
      exitRequestedAt: parseTimestamp(data['exitRequestedAt']),
      exitApprovedAt: parseTimestamp(data['exitApprovedAt']),
      exitLockedAt: parseTimestamp(data['exitLockedAt']),
      exitRequestedBy: data['exitRequestedBy'] as String?,
      exitApprovedBy: data['exitApprovedBy'] as String?,
      restrictedUntil: parseTimestamp(data['restrictedUntil']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'reservationNumber': reservationNumber,
      'parkingId': parkingId,
      'parkingName': parkingName,
      'ownerId': ownerId,
      'userName': userName,
      'plate': plate,
      'spaceNumber': spaceNumber,
      'reservedAt': Timestamp.fromDate(reservedAt),
      'startedAt': Timestamp.fromDate(reservedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'state': state,
      'pricePerHour': pricePerHour,
      'amount': amount,
      'durationMinutes': durationMinutes,
      'estimatedAmount': estimatedAmount,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'cancelAttempts': cancelAttempts,
      'userCancelAttempts': userCancelAttempts,
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
      'exitStatus': exitStatus,
      'exitRequestedAt':
          exitRequestedAt != null ? Timestamp.fromDate(exitRequestedAt!) : null,
      'exitApprovedAt':
          exitApprovedAt != null ? Timestamp.fromDate(exitApprovedAt!) : null,
      'exitLockedAt':
          exitLockedAt != null ? Timestamp.fromDate(exitLockedAt!) : null,
      'exitRequestedBy': exitRequestedBy,
      'exitApprovedBy': exitApprovedBy,
      'restrictedUntil':
          restrictedUntil != null ? Timestamp.fromDate(restrictedUntil!) : null,
    };
  }

  Reservation copyWith({
    String? id,
    String? reservationNumber,
    String? userId,
    String? parkingId,
    String? parkingName,
    String? ownerId,
    String? userName,
    String? plate,
    int? spaceNumber,
    DateTime? reservedAt,
    DateTime? endedAt,
    String? state,
    int? pricePerHour,
    int? amount,
    int? durationMinutes,
    int? estimatedAmount,
    int? estimatedDurationMinutes,
    int? cancelAttempts,
    int? userCancelAttempts,
    DateTime? freeCancellationUntil,
    DateTime? cancelRequestedAt,
    String? cancellationReason,
    bool? cancellationPenaltyApplied,
    String? providerApprovalStatus,
    String? exitStatus,
    DateTime? exitRequestedAt,
    DateTime? exitApprovedAt,
    DateTime? exitLockedAt,
    String? exitRequestedBy,
    String? exitApprovedBy,
    DateTime? restrictedUntil,
  }) {
    return Reservation(
      id: id ?? this.id,
      reservationNumber: reservationNumber ?? this.reservationNumber,
      userId: userId ?? this.userId,
      parkingId: parkingId ?? this.parkingId,
      parkingName: parkingName ?? this.parkingName,
      ownerId: ownerId ?? this.ownerId,
      userName: userName ?? this.userName,
      plate: plate ?? this.plate,
      spaceNumber: spaceNumber ?? this.spaceNumber,
      reservedAt: reservedAt ?? this.reservedAt,
      endedAt: endedAt ?? this.endedAt,
      state: state ?? this.state,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      amount: amount ?? this.amount,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      estimatedAmount: estimatedAmount ?? this.estimatedAmount,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      cancelAttempts: cancelAttempts ?? this.cancelAttempts,
      userCancelAttempts: userCancelAttempts ?? this.userCancelAttempts,
      freeCancellationUntil:
          freeCancellationUntil ?? this.freeCancellationUntil,
      cancelRequestedAt: cancelRequestedAt ?? this.cancelRequestedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancellationPenaltyApplied:
          cancellationPenaltyApplied ?? this.cancellationPenaltyApplied,
      providerApprovalStatus:
          providerApprovalStatus ?? this.providerApprovalStatus,
      exitStatus: exitStatus ?? this.exitStatus,
      exitRequestedAt: exitRequestedAt ?? this.exitRequestedAt,
      exitApprovedAt: exitApprovedAt ?? this.exitApprovedAt,
      exitLockedAt: exitLockedAt ?? this.exitLockedAt,
      exitRequestedBy: exitRequestedBy ?? this.exitRequestedBy,
      exitApprovedBy: exitApprovedBy ?? this.exitApprovedBy,
      restrictedUntil: restrictedUntil ?? this.restrictedUntil,
    );
  }
}
