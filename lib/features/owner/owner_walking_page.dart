// lib/features/owner/pages/owner_walkin_page.dart
//
// Walk-in Management — assign a parking space to a customer who arrived
// without an online reservation. Records entry time, calculates billing
// at checkout, and marks the space as occupied/free in Firestore.
//
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_button.dart';
import 'package:mapbox_api/common/ui/components/my_text.dart';
import 'package:mapbox_api/features/core/roles/role_utils.dart';
import 'package:mapbox_api/features/owner/widgets/app_header.dart';
import 'package:mapbox_api/features/owner/providers/dashboard_providers.dart';

// ─── Firestore helpers ────────────────────────────────────────────────────────

Future<String?> _getOwnerParkingId() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  final snap =
      await FirebaseFirestore.instance
          .collection('parkings')
          .where('ownerID', isEqualTo: uid)
          .limit(1)
          .get();
  return snap.docs.isEmpty ? null : snap.docs.first.id;
}

Future<double?> _getParkingPricePerHour(String parkingId) async {
  final doc =
      await FirebaseFirestore.instance
          .collection('parkings')
          .doc(parkingId)
          .get();
  return (doc.data()?['pricePerHour'] as num?)?.toDouble();
}

// ─── Walk-in record model ─────────────────────────────────────────────────────

class _WalkIn {
  final String docId;
  final String spaceId;
  final int spaceNumber;
  final String plate;
  final DateTime enteredAt;
  final double? pricePerHour;

  const _WalkIn({
    required this.docId,
    required this.spaceId,
    required this.spaceNumber,
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

  // Space data
  List<Map<String, dynamic>> _spaces = [];
  // Active walk-ins: spaceId → WalkIn
  final Map<String, _WalkIn> _walkIns = {};

  // Timer that rebuilds every second to keep elapsed time live
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _init();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _walkIns.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final pid = await _getOwnerParkingId();
      if (pid == null) {
        setState(() {
          _error = 'No se encontró tu parqueo.';
          _loading = false;
        });
        return;
      }
      final price = await _getParkingPricePerHour(pid);
      final snap =
          await FirebaseFirestore.instance
              .collection('parkings')
              .doc(pid)
              .collection('spaces')
              .orderBy('spaceNumber')
              .get();

      setState(() {
        _parkingId = pid;
        _pricePerHour = price;
        _spaces = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loading = false;
      });

      // Also load active walk-ins from Firestore (survive app restarts)
      _loadActiveWalkIns(pid);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadActiveWalkIns(String parkingId) async {
    final snap =
        await FirebaseFirestore.instance
            .collection('parkings')
            .doc(parkingId)
            .collection('walk_ins')
            .where('status', isEqualTo: 'active')
            .get();

    for (final doc in snap.docs) {
      final d = doc.data();
      final spaceId = d['spaceId'] as String? ?? '';
      _walkIns[spaceId] = _WalkIn(
        docId: doc.id,
        spaceId: spaceId,
        spaceNumber: (d['spaceNumber'] as num?)?.toInt() ?? 0,
        plate: d['plate'] as String? ?? '',
        enteredAt: (d['enteredAt'] as Timestamp).toDate(),
        pricePerHour: (d['pricePerHour'] as num?)?.toDouble(),
      );
    }
    if (mounted) setState(() {});
  }

  // ── Assign walk-in ──────────────────────────────────────────────────────────
  Future<void> _assignWalkIn(Map<String, dynamic> space) async {
    final spaceId = space['id'] as String;
    final spaceNumber = (space['spaceNumber'] as num?)?.toInt() ?? 0;

    final plate = await _showPlateDialog(spaceNumber);
    if (plate == null || plate.trim().isEmpty) return;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final now = DateTime.now();

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
        'plate': plate.trim().toUpperCase(),
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
          plate: plate.trim().toUpperCase(),
          enteredAt: now,
          pricePerHour: _pricePerHour,
        );
      });

      if (mounted) {
        _showSnack(
          '✓ Espacio $spaceNumber asignado a ${plate.trim().toUpperCase()}',
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

  Future<String?> _showPlateDialog(int spaceNumber) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.headerBottom.withOpacity(0.18),
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
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
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
                        Text(
                          'Registrar entrada',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Espacio No. $spaceNumber',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
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
                        const Text(
                          'Placa del vehículo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: ctrl,
                          autofocus: true,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]'),
                            ),
                            LengthLimitingTextInputFormatter(8),
                          ],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'P123ABC',
                            hintStyle: TextStyle(
                              fontSize: 20,
                              letterSpacing: 2,
                              color: Colors.grey.shade300,
                              fontWeight: FontWeight.w700,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF1F5F9),
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
                              borderSide: BorderSide(
                                color: AppColors.headerBottom,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Solo letras y números, sin guiones',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
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
                                      color: AppColors.headerBottom.withOpacity(
                                        0.35,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: Colors.white,
                                  ),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.headerBottom,
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
                                onTap: () => Navigator.pop(ctx, ctrl.text),
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
          ),
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
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.headerBottom.withOpacity(0.18),
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
                        colors: [Color(0xFF16A34A), Color(0xFF15803D)],
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
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
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
                          'Checkout',
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
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderSoft),
                          ),
                          child: Column(
                            children: [
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total a cobrar',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
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
                                      color: AppColors.headerBottom.withOpacity(
                                        0.35,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: Colors.white,
                                  ),
                                  child: const Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.headerBottom,
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
                                    backgroundColor: const Color(0xFF16A34A),
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
          ),
    );
  }

  void _showCheckoutSummary(_WalkIn walkIn, Duration elapsed, double amount) {
    final h = elapsed.inHours;
    final m = elapsed.inMinutes % 60;
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF16A34A), Color(0xFF15803D)],
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
                          '¡Checkout completado!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
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
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF16A34A).withOpacity(0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Q ${amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF16A34A),
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${walkIn.plate}  •  ${h > 0 ? '${h}h ${m}m' : '${m}m'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
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
          ),
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
    return OwnerOnly(
      builder:
          (_) => Column(
            children: [
              const AppHeader(
                title: 'Acceso Directo',
                subtitle: 'Registra clientes sin reserva en línea',
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
                        child: Transform.translate(
                          offset: const Offset(0, -20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _StatsBanner(
                              spaces: _spaces,
                              walkIns: _walkIns,
                              pricePerHour: _pricePerHour,
                            ),
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
                                  'EN PROCESO',
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
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.grid_view_rounded,
                                size: 13,
                                color: AppColors.headerBottom,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ESPACIOS'.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.headerBottom,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_spaces.length} total',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate((_, i) {
                            final space = _spaces[i];
                            final spaceId = space['id'] as String;
                            final status = space['status'] as String? ?? 'free';
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
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.85,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.08),
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
              label: 'Walk-ins',
              value: '${walkIns.length}',
              color: AppColors.headerBottom,
              icon: Icons.directions_walk_rounded,
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
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF8A94A6),
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
    color: AppColors.borderSoft,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
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
    Color bg, border, iconColor, textColor;
    IconData icon;
    String label;

    if (status == 'free') {
      bg = const Color(0xFFF0FDF4);
      border = const Color(0xFF16A34A);
      iconColor = const Color(0xFF16A34A);
      textColor = const Color(0xFF16A34A);
      icon = Icons.add_rounded;
      label = 'Libre';
    } else if (isWalkIn) {
      bg = AppColors.headerBottom.withOpacity(0.06);
      border = AppColors.headerBottom;
      iconColor = AppColors.headerBottom;
      textColor = AppColors.headerBottom;
      icon = Icons.directions_walk_rounded;
      label = 'Walk-in';
    } else {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFDC2626);
      iconColor = const Color(0xFFDC2626);
      textColor = const Color(0xFFDC2626);
      icon = Icons.local_parking_rounded;
      label = 'Ocupado';
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: border.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Space number
            Text(
              '$number',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: textColor,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 6),
            // Label / elapsed
            Text(
              isWalkIn && elapsedLabel != null ? elapsedLabel! : label,
              style: TextStyle(
                fontSize: isWalkIn ? 10 : 11,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            if (isWalkIn && walkIn != null) ...[
              const SizedBox(height: 2),
              Text(
                walkIn!.plate,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: textColor.withOpacity(0.6),
                ),
              ),
            ],
            if (status == 'free') ...[
              const SizedBox(height: 2),
              Text(
                'Toca para asignar',
                style: TextStyle(
                  fontSize: 8,
                  color: textColor.withOpacity(0.5),
                ),
              ),
            ],
          ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.06),
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
                  Icons.directions_walk_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Espacio ${walkIn.spaceNumber}  •  ${walkIn.plate}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'WALK-IN',
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
                          color: Colors.grey.shade400,
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
                            color: Colors.grey.shade400,
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
                // Checkout button
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: onCheckout,
                    icon: const Icon(Icons.logout_rounded, size: 15),
                    label: const Text(
                      'Checkout',
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
          decoration: const BoxDecoration(
            color: AppColors.iconCircle,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: AppColors.headerBottom),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8A94A6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
