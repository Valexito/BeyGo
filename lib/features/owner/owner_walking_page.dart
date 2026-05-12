// lib/features/owner/pages/owner_walkin_page.dart
//
// Walk-in Management — assign a parking space to a customer who arrived
// without an online reservation. Records entry time, calculates billing
// at checkout, and marks the space as occupied/free in Firestore.
//
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/owner/owner.dart';

// ─── Walk-in record model ─────────────────────────────────────────────────────

class _WalkIn {
  final String docId;
  final String spaceId;
  final int spaceNumber;
  final String reservationNumber;
  final String customerName;
  final String plate;
  final DateTime enteredAt;
  final double? pricePerHour;

  const _WalkIn({
    required this.docId,
    required this.spaceId,
    required this.spaceNumber,
    required this.reservationNumber,
    required this.customerName,
    required this.plate,
    required this.enteredAt,
    this.pricePerHour,
  });

  Duration get elapsed => DateTime.now().difference(enteredAt);

  double? estimatedAmount(Duration dur) {
    if (pricePerHour == null) return null;
    final hours = dur.inMinutes / 60.0;
    return (hours * pricePerHour!);
  }
}

String _generateManualReservationNumber() {
  final now = DateTime.now();
  final shortCode = 100 + (now.microsecondsSinceEpoch % 900);
  return 'MAN-$shortCode';
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class OwnerWalkInPage extends ConsumerStatefulWidget {
  const OwnerWalkInPage({super.key});

  @override
  ConsumerState<OwnerWalkInPage> createState() => _OwnerWalkInPageState();
}

class _OwnerWalkInPageState extends ConsumerState<OwnerWalkInPage>
    with TickerProviderStateMixin {
  String? _parkingId;
  double? _pricePerHour;
  bool _loading = true;
  String? _error;
  String? _boundParkingId;

  // Space data
  List<Map<String, dynamic>> _spaces = [];
  // Active walk-ins: spaceId → WalkIn
  final Map<String, _WalkIn> _walkIns = {};

  // Timer that rebuilds every second to keep elapsed time live
  Timer? _ticker;
  ProviderSubscription<AsyncValue<dynamic>>? _parkingSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _spacesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _walkInsSub;

  @override
  void initState() {
    super.initState();
    _parkingSub = ref.listenManual<AsyncValue<dynamic>>(ownerParkingProvider, (
      _,
      next,
    ) {
      next.whenData((parking) {
        if (parking == null) {
          _unbindStreams();
          if (!mounted) return;
          setState(() {
            _parkingId = null;
            _boundParkingId = null;
            _spaces = [];
            _walkIns.clear();
            _pricePerHour = null;
            _error = 'No se encontró tu parqueo.';
            _loading = false;
          });
          return;
        }
        _bindParking(parking.id, parking.pricePerHour.toDouble());
      });

      if (next.hasError) {
        if (!mounted) return;
        setState(() {
          _error = next.error.toString();
          _loading = false;
        });
      }
    }, fireImmediately: true);

    Future<void>(() async {
      try {
        final parking = await ref.read(ownerParkingProvider.future);
        if (!mounted) return;
        if (parking == null) {
          setState(() {
            _error = 'No se encontró tu parqueo.';
            _loading = false;
          });
          return;
        }
        _bindParking(parking.id, parking.pricePerHour.toDouble());
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _walkIns.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _parkingSub?.close();
    _unbindStreams();
    super.dispose();
  }

  void _unbindStreams() {
    _spacesSub?.cancel();
    _walkInsSub?.cancel();
    _spacesSub = null;
    _walkInsSub = null;
  }

  void _bindParking(String parkingId, double pricePerHour) {
    if (_boundParkingId == parkingId) {
      if (!mounted) return;
      setState(() {
        _parkingId = parkingId;
        _pricePerHour = pricePerHour;
        _error = null;
      });
      return;
    }

    _unbindStreams();

    if (!mounted) return;
    setState(() {
      _boundParkingId = parkingId;
      _parkingId = parkingId;
      _pricePerHour = pricePerHour;
      _spaces = [];
      _walkIns.clear();
      _error = null;
      _loading = true;
    });

    final db = FirebaseFirestore.instance;

    _spacesSub = db
        .collection('parkings')
        .doc(parkingId)
        .collection('spaces')
        .snapshots()
        .listen(
          (snap) {
            final spaces =
                snap.docs.map((d) {
                    final data = d.data();
                    final parsedNumber =
                        (data['spaceNumber'] as num?)?.toInt() ??
                        int.tryParse(d.id) ??
                        0;
                    return {'id': d.id, ...data, 'spaceNumber': parsedNumber};
                  }).toList()
                  ..sort(
                    (a, b) => ((a['spaceNumber'] as int?) ?? 0).compareTo(
                      (b['spaceNumber'] as int?) ?? 0,
                    ),
                  );

            if (!mounted) return;
            setState(() {
              _spaces = spaces;
              _loading = false;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _error = 'No se pudieron cargar los espacios: $error';
              _loading = false;
            });
          },
        );

    _walkInsSub = db
        .collection('parkings')
        .doc(parkingId)
        .collection('walk_ins')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen(
          (snap) {
            final next = <String, _WalkIn>{};
            for (final doc in snap.docs) {
              final d = doc.data();
              final spaceId = d['spaceId'] as String? ?? '';
              if (spaceId.isEmpty) continue;
              next[spaceId] = _WalkIn(
                docId: doc.id,
                spaceId: spaceId,
                spaceNumber: (d['spaceNumber'] as num?)?.toInt() ?? 0,
                reservationNumber:
                    d['reservationNumber'] as String? ?? 'MAN-SIN-NUMERO',
                customerName: d['customerName'] as String? ?? 'Cliente',
                plate: d['plate'] as String? ?? '',
                enteredAt: (d['enteredAt'] as Timestamp).toDate(),
                pricePerHour: (d['pricePerHour'] as num?)?.toDouble(),
              );
            }
            if (!mounted) return;
            setState(() {
              _walkIns
                ..clear()
                ..addAll(next);
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            _showSnack(
              'No se pudieron cargar los walk-ins activos. Verifica reglas de Firestore.',
              isError: true,
            );
            setState(() {
              _walkIns.clear();
            });
          },
        );
  }

  // ── Assign walk-in ──────────────────────────────────────────────────────────
  Future<void> _assignWalkIn(Map<String, dynamic> space) async {
    final spaceId = space['id'] as String;
    final spaceNumber = (space['spaceNumber'] as num?)?.toInt() ?? 0;

    final payload = await _showWalkInDialog(spaceNumber);
    if (payload == null) return;

    final customerName = payload.name.trim();
    final plate = payload.plate.trim().toUpperCase();
    if (customerName.isEmpty || plate.isEmpty) return;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final now = DateTime.now();
      final reservationNumber = _generateManualReservationNumber();

      // 1. Mark space as occupied
      batch.update(
        db
            .collection('parkings')
            .doc(_parkingId)
            .collection('spaces')
            .doc(spaceId),
        {'status': 'occupied', 'updatedAt': FieldValue.serverTimestamp()},
      );

      // 2. Create walk-in record
      final walkInRef =
          db
              .collection('parkings')
              .doc(_parkingId)
              .collection('walk_ins')
              .doc();

      batch.set(walkInRef, {
        'spaceId': spaceId,
        'spaceNumber': spaceNumber,
        'reservationNumber': reservationNumber,
        'customerName': customerName,
        'plate': plate,
        'enteredAt': Timestamp.fromDate(now),
        'pricePerHour': _pricePerHour,
        'status': 'active',
        'type': 'walk_in',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      setState(() {
        // Update local space status
        final idx = _spaces.indexWhere((s) => s['id'] == spaceId);
        if (idx != -1) _spaces[idx] = {..._spaces[idx], 'status': 'occupied'};

        _walkIns[spaceId] = _WalkIn(
          docId: walkInRef.id,
          spaceId: spaceId,
          spaceNumber: spaceNumber,
          reservationNumber: reservationNumber,
          customerName: customerName,
          plate: plate,
          enteredAt: now,
          pricePerHour: _pricePerHour,
        );
      });

      if (mounted) {
        _showSnack(
          '✓ Espacio $spaceNumber asignado a $customerName • $reservationNumber',
        );
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    }
  }

  // ── Checkout walk-in ────────────────────────────────────────────────────────
  Future<void> _checkoutWalkIn(_WalkIn walkIn) async {
    final confirmed = await _showCheckoutDialog(walkIn);
    if (confirmed != true) return;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final now = DateTime.now();
      final elapsed = now.difference(walkIn.enteredAt);
      final hours = elapsed.inMinutes / 60.0;
      final amount = (_pricePerHour ?? 0) * hours;

      // 1. Free the space
      batch.update(
        db
            .collection('parkings')
            .doc(_parkingId)
            .collection('spaces')
            .doc(walkIn.spaceId),
        {'status': 'free', 'updatedAt': FieldValue.serverTimestamp()},
      );

      // 2. Close walk-in record
      batch.update(
        db
            .collection('parkings')
            .doc(_parkingId)
            .collection('walk_ins')
            .doc(walkIn.docId),
        {
          'status': 'completed',
          'exitAt': Timestamp.fromDate(now),
          'durationMinutes': elapsed.inMinutes,
          'amount': double.parse(amount.toStringAsFixed(2)),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      setState(() {
        final idx = _spaces.indexWhere((s) => s['id'] == walkIn.spaceId);
        if (idx != -1) _spaces[idx] = {..._spaces[idx], 'status': 'free'};
        _walkIns.remove(walkIn.spaceId);
      });

      if (mounted) {
        _showCheckoutSummary(walkIn, elapsed, amount);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    }
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  Future<_WalkInFormData?> _showWalkInDialog(int spaceNumber) {
    final nameCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    return showDialog<_WalkInFormData>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dialogBg = ctx.appCardBackground;
        final fieldBg = ctx.appInputBackground;
        final primaryText = ctx.appTextPrimaryColor;
        final secondaryText = ctx.appTextSecondaryColor;
        final brand = ctx.appBrandIconColor;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: ctx.appBorderColor),
              boxShadow: [
                BoxShadow(
                  color: AppColors.headerBottom.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.headerTop, AppColors.headerBottom],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Registrar entrada',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Espacio No. $spaceNumber',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nombre del cliente',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ej: Juan Pérez',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: brand, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Placa del vehículo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: plateCtrl,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(8),
                        ],
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: primaryText,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: 'P123ABC',
                          hintStyle: TextStyle(
                            fontSize: 20,
                            letterSpacing: 2,
                            color: secondaryText.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w700,
                          ),
                          filled: true,
                          fillColor: fieldBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: brand, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Solo letras y números, sin guiones',
                        style: TextStyle(fontSize: 11, color: secondaryText),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: brand.withValues(alpha: 0.35),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  backgroundColor: ctx.appCardBackgroundSoft,
                                ),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: ctx.appBrandTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: MyButton(
                              text: 'Asignar',
                              height: 46,
                              margin: EdgeInsets.zero,
                              onTap:
                                  () => Navigator.pop(
                                    ctx,
                                    _WalkInFormData(
                                      name: nameCtrl.text,
                                      plate: plateCtrl.text,
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showCheckoutDialog(_WalkIn walkIn) {
    final elapsed = DateTime.now().difference(walkIn.enteredAt);
    final hours = elapsed.inMinutes / 60.0;
    final amount = (_pricePerHour ?? 0) * hours;
    final h = elapsed.inHours;
    final m = elapsed.inMinutes % 60;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final dialogBg = ctx.appCardBackground;
        final cardBg = ctx.appCardBackgroundSoft;
        final primaryText = ctx.appTextPrimaryColor;
        final brand = ctx.appBrandIconColor;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: ctx.appBorderColor),
              boxShadow: [
                BoxShadow(
                  color: AppColors.headerBottom.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.headerTop, AppColors.headerBottom],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Registrar salida',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Espacio No. ${walkIn.spaceNumber}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No. ${walkIn.reservationNumber}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Summary card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: ctx.appBorderColor),
                        ),
                        child: Column(
                          children: [
                            _SummaryRow(
                              icon: Icons.receipt_long_rounded,
                              label: 'Reservación',
                              value: walkIn.reservationNumber,
                            ),
                            const SizedBox(height: 10),
                            _SummaryRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Cliente',
                              value: walkIn.customerName,
                            ),
                            const SizedBox(height: 10),
                            _SummaryRow(
                              icon: Icons.directions_car_rounded,
                              label: 'Placa',
                              value: walkIn.plate,
                            ),
                            const SizedBox(height: 10),
                            _SummaryRow(
                              icon: Icons.login_rounded,
                              label: 'Entrada',
                              value: _fmtTime(walkIn.enteredAt),
                            ),
                            const SizedBox(height: 10),
                            _SummaryRow(
                              icon: Icons.timelapse_rounded,
                              label: 'Tiempo',
                              value: h > 0 ? '${h}h ${m}m' : '${m}m',
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total a cobrar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: primaryText,
                                  ),
                                ),
                                Text(
                                  'Q ${amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: brand.withValues(alpha: 0.35),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  backgroundColor: ctx.appCardBackgroundSoft,
                                ),
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: ctx.appBrandTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.headerBottom,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Confirmar cobro',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCheckoutSummary(_WalkIn walkIn, Duration elapsed, double amount) {
    showDialog(
      context: context,
      builder: (ctx) {
        final dialogBg = ctx.appCardBackground;
        final cardBg =
            ctx.isDarkMode ? const Color(0xFF162033) : const Color(0xFFF4F8FD);
        final borderColor = ctx.appBorderColor;
        final secondaryText = ctx.appTextSecondaryColor;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.headerTop, AppColors.headerBottom],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 52,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '¡Salida registrada!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No. ${walkIn.reservationNumber}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Big amount
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Q ${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color:
                                    context.isDarkMode
                                        ? Colors.white
                                        : AppColors.headerBottom,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${walkIn.customerName}  •  ${walkIn.plate}',
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: MyButton(
                          text: 'Listo',
                          onTap: () => Navigator.pop(ctx),
                          margin: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _fmtTime(DateTime v) {
    final h = v.hour.toString().padLeft(2, '0');
    final m = v.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _elapsedLabel(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount =
        width >= 520
            ? 5
            : width >= 390
            ? 4
            : 3;

    return OwnerOnly(
      builder:
          (_) => Column(
            children: [
              const AppHeader(
                title: 'Reservas manuales',
                subtitle: 'Registra clientes sin reservación en línea',
                showBack: true,
              ),

              if (_loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFDC2626)),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // ── Stats banner ──────────────────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                          child: _StatsBanner(
                            spaces: _spaces,
                            walkIns: _walkIns,
                            pricePerHour: _pricePerHour,
                          ),
                        ),
                      ),

                      // ── Active walk-ins ───────────────────────────────────────
                      if (_walkIns.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'EN CURSO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF16A34A),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((_, i) {
                              final walkIn = _walkIns.values.toList()[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ActiveWalkInCard(
                                  walkIn: walkIn,
                                  elapsed: walkIn.elapsed,
                                  elapsedLabel: _elapsedLabel(walkIn.elapsed),
                                  onCheckout: () => _checkoutWalkIn(walkIn),
                                ),
                              );
                            }, childCount: _walkIns.length),
                          ),
                        ),
                      ],

                      // ── Spaces grid ───────────────────────────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                          child: _QuickAssignCard(
                            spaces: _spaces,
                            walkIns: _walkIns,
                            onAssign: (space) => _assignWalkIn(space),
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.grid_view_rounded,
                                    size: 13,
                                    color: context.appBrandIconColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ESPACIOS'.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: context.appBrandTextColor,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_spaces.length} total',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.appTextSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 14,
                                runSpacing: 10,
                                children: const [
                                  _SpaceLegendDot(
                                    color: Color(0xFF16A34A),
                                    label: 'Libre',
                                  ),
                                  _SpaceLegendDot(
                                    color: Color(0xFFEF4444),
                                    label: 'Ocupado',
                                  ),
                                  _SpaceLegendDot(
                                    color: AppColors.headerBottom,
                                    label: 'Manual',
                                    filled: true,
                                  ),
                                  _SpaceLegendDot(
                                    color: Color(0xFFF59E0B),
                                    label: 'Solicitado',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_spaces.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 40),
                            child: _EmptySpacesState(),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate((_, i) {
                              final space = _spaces[i];
                              final spaceId = space['id'] as String;
                              final status =
                                  space['status'] as String? ?? 'free';
                              final number =
                                  (space['spaceNumber'] as num?)?.toInt() ??
                                  (i + 1);
                              final walkIn = _walkIns[spaceId];

                              return _SpaceTile(
                                number: number,
                                status: status,
                                isWalkIn: walkIn != null,
                                walkIn: walkIn,
                                elapsedLabel:
                                    walkIn != null
                                        ? _elapsedLabel(walkIn.elapsed)
                                        : null,
                                onTap:
                                    status == 'free'
                                        ? () => _assignWalkIn(space)
                                        : walkIn != null
                                        ? () => _checkoutWalkIn(walkIn)
                                        : null,
                              );
                            }, childCount: _spaces.length),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 1.02,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
    );
  }
}

class _WalkInFormData {
  final String name;
  final String plate;

  const _WalkInFormData({required this.name, required this.plate});
}

class _QuickAssignCard extends StatelessWidget {
  final List<Map<String, dynamic>> spaces;
  final Map<String, _WalkIn> walkIns;
  final ValueChanged<Map<String, dynamic>> onAssign;

  const _QuickAssignCard({
    required this.spaces,
    required this.walkIns,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final freeSpaces =
        spaces
            .where((s) => (s['status'] as String? ?? 'free') == 'free')
            .toList()
          ..sort(
            (a, b) => ((a['spaceNumber'] as num?)?.toInt() ?? 0).compareTo(
              (b['spaceNumber'] as num?)?.toInt() ?? 0,
            ),
          );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.18 : 0.05,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color:
                      context.isDarkMode
                          ? context.appCardBackgroundSoft
                          : AppColors.headerBottom.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.flash_on_rounded,
                  color:
                      context.isDarkMode
                          ? context.appBrandIconColor
                          : AppColors.headerBottom,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asignación rápida',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Selecciona un espacio libre para registrar un cliente presencial.',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appTextSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (freeSpaces.isEmpty)
            const Text(
              'No hay espacios libres en este momento.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  freeSpaces.take(8).map((space) {
                    final number = (space['spaceNumber'] as num?)?.toInt() ?? 0;
                    return ActionChip(
                      onPressed: () => onAssign(space),
                      avatar: Icon(
                        Icons.directions_car_rounded,
                        size: 16,
                        color:
                            context.isDarkMode
                                ? context.appBrandIconColor
                                : AppColors.headerBottom,
                      ),
                      label: Text(
                        'Espacio $number',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimaryColor,
                        ),
                      ),
                      side: BorderSide(
                        color:
                            context.isDarkMode
                                ? context.appBorderColor
                                : AppColors.headerBottom.withValues(
                                  alpha: 0.16,
                                ),
                      ),
                      backgroundColor: context.appCardBackgroundSoft,
                    );
                  }).toList(),
            ),
          if (walkIns.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${walkIns.length} cliente(s) presenciales activos ahora mismo.',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF16A34A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySpacesState extends StatelessWidget {
  const _EmptySpacesState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.local_parking_outlined,
            size: 34,
            color: context.appTextSecondaryColor,
          ),
          const SizedBox(height: 10),
          Text(
            'Aún no hay espacios configurados',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cuando existan espacios en tu parqueo, aparecerán aquí para asignarlos manualmente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.appTextSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats banner ──────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  final List<Map<String, dynamic>> spaces;
  final Map<String, _WalkIn> walkIns;
  final double? pricePerHour;

  const _StatsBanner({
    required this.spaces,
    required this.walkIns,
    required this.pricePerHour,
  });

  @override
  Widget build(BuildContext context) {
    final free = spaces.where((s) => s['status'] == 'free').length;
    final occupied = spaces.length - free;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.20 : 0.08,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _BannerStat(
              label: 'Libres',
              value: '$free',
              color: const Color(0xFF16A34A),
              icon: Icons.check_circle_outline_rounded,
            ),
          ),
          _VertDivider(),
          Expanded(
            child: _BannerStat(
              label: 'Ocupados',
              value: '$occupied',
              color: const Color(0xFFDC2626),
              icon: Icons.local_parking_rounded,
            ),
          ),
          _VertDivider(),
          Expanded(
            child: _BannerStat(
              label: 'Manuales',
              value: '${walkIns.length}',
              color:
                  context.isDarkMode
                      ? context.appBrandTextColor
                      : AppColors.headerBottom,
              icon: Icons.directions_car_filled_rounded,
            ),
          ),
          if (pricePerHour != null) ...[
            _VertDivider(),
            Expanded(
              child: _BannerStat(
                label: 'Por hora',
                value: 'Q${pricePerHour!.toStringAsFixed(0)}',
                color: const Color(0xFF7C3AED),
                icon: Icons.attach_money_rounded,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _BannerStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: context.appTextSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 44,
    color: context.appBorderColor,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

class _SpaceLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool filled;

  const _SpaceLegendDot({
    required this.color,
    required this.label,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.appTextPrimaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Space tile ────────────────────────────────────────────────────────────────

class _SpaceTile extends StatelessWidget {
  final int number;
  final String status;
  final bool isWalkIn;
  final _WalkIn? walkIn;
  final String? elapsedLabel;
  final VoidCallback? onTap;

  const _SpaceTile({
    required this.number,
    required this.status,
    required this.isWalkIn,
    this.walkIn,
    this.elapsedLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoration =
        status == 'requested'
            ? BoxDecoration(
              color: context.appCardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.4),
            )
            : status == 'occupied' && !isWalkIn
            ? BoxDecoration(
              color:
                  context.isDarkMode
                      ? const Color(0xFF2A1619)
                      : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
            )
            : isWalkIn
            ? BoxDecoration(
              color:
                  context.isDarkMode
                      ? context.appCardBackgroundSoft
                      : AppColors.headerBottom.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    context.isDarkMode
                        ? context.appBrandIconColor.withValues(alpha: 0.75)
                        : AppColors.headerBottom,
                width: 1.3,
              ),
            )
            : BoxDecoration(
              color:
                  context.isDarkMode
                      ? const Color(0xFF12261A)
                      : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
            );

    final Color iconColor =
        status == 'requested'
            ? const Color(0xFFF59E0B)
            : status == 'occupied' && !isWalkIn
            ? const Color(0xFFDC2626)
            : isWalkIn
            ? (context.isDarkMode
                ? context.appBrandTextColor
                : AppColors.headerBottom)
            : const Color(0xFF16A34A);

    final Color labelColor = iconColor;

    final String title =
        isWalkIn && elapsedLabel != null ? elapsedLabel! : 'Espacio $number';

    final String subtitle =
        status == 'requested'
            ? 'Solicitado'
            : status == 'occupied' && !isWalkIn
            ? 'Ocupado'
            : isWalkIn
            ? (walkIn?.plate ?? 'Manual')
            : 'Libre';

    final String? footer =
        isWalkIn
            ? walkIn?.customerName
            : status == 'free'
            ? null
            : null;

    return Opacity(
      opacity:
          (status == 'occupied' || status == 'requested') && !isWalkIn
              ? 0.96
              : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: decoration,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car_outlined, size: 18, color: iconColor),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: isWalkIn ? 10 : 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: labelColor.withValues(alpha: 0.85),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    footer,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: labelColor.withValues(alpha: 0.72),
                      fontSize: 7.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Active walk-in card ───────────────────────────────────────────────────────

class _ActiveWalkInCard extends StatelessWidget {
  final _WalkIn walkIn;
  final Duration elapsed;
  final String elapsedLabel;
  final VoidCallback onCheckout;

  const _ActiveWalkInCard({
    required this.walkIn,
    required this.elapsed,
    required this.elapsedLabel,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final hours = elapsed.inMinutes / 60.0;
    final amount = (walkIn.pricePerHour ?? 0) * hours;

    return Container(
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.18 : 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.headerTop, AppColors.headerBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.directions_car_filled_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No. ${walkIn.reservationNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Espacio ${walkIn.spaceNumber}  •  ${walkIn.customerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'MANUAL',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                // Elapsed
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tiempo transcurrido',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.appTextSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        elapsedLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                // Estimated
                if (walkIn.pricePerHour != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimado',
                          style: TextStyle(
                            fontSize: 10,
                            color: context.appTextSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Q ${amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Boton de salida
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: onCheckout,
                    icon: const Icon(Icons.logout_rounded, size: 15),
                    label: const Text(
                      'Salida',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: context.appIconCircleColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: context.appBrandIconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.appTextSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimaryColor,
          ),
        ),
      ],
    );
  }
}
