// lib/features/users/pages/edit_vehicles_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/users/users.dart';

class EditVehiclesPage extends StatefulWidget {
  const EditVehiclesPage({super.key});

  @override
  State<EditVehiclesPage> createState() => _EditVehiclesPageState();
}

class _EditVehiclesPageState extends State<EditVehiclesPage> {
  final _auth = FirebaseAuth.instance;
  bool _loading = true;
  bool _saving = false;

  final List<_VehicleEditEntry> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    for (final v in _vehicles) v.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final db = FirebaseFirestore.instance;
      final snap =
          await db.collection('users').doc(uid).collection('vehicles').get();

      if (snap.docs.isNotEmpty) {
        final entries =
            snap.docs.map((doc) {
              final data = doc.data();
              final plate = (data['plate'] as String?) ?? '';
              final typeStr = (data['type'] as String?) ?? 'car';
              final correlative = plate.length > 1 ? plate.substring(1) : plate;
              return _VehicleEditEntry(
                firestoreId: doc.id,
                type: vehicleTypeFromString(typeStr),
                correlative: correlative,
                isPrimary: (data['isPrimary'] as bool?) ?? false,
              );
            }).toList();

        // Primary first
        entries.sort((a, b) => b.isPrimary ? 1 : -1);
        _vehicles.addAll(entries);
      } else {
        // Fallback from main doc
        final userDoc = await db.collection('users').doc(uid).get();
        final data = userDoc.data() ?? {};
        final plate = (data['vehiclePlate'] as String?) ?? '';
        final typeStr = (data['vehicleType'] as String?) ?? 'car';
        if (plate.isNotEmpty) {
          _vehicles.add(
            _VehicleEditEntry(
              type: vehicleTypeFromString(typeStr),
              correlative: plate.length > 1 ? plate.substring(1) : plate,
              isPrimary: true,
            ),
          );
        } else {
          _vehicles.add(_VehicleEditEntry(isPrimary: true));
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addVehicle() {
    if (_vehicles.length >= 4) return;
    setState(() => _vehicles.add(_VehicleEditEntry()));
  }

  Future<void> _deleteVehicle(int index) async {
    if (_vehicles.length <= 1) {
      _showSnack('Debes tener al menos un vehículo.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: context.appCardBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Eliminar vehículo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      children: [
                        Text(
                          '¿Seguro que deseas eliminar el vehículo ${_vehicles[index].fullPlate}?',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5A6478),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: AppColors.headerBottom.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: Colors.white,
                                  ),
                                  child: Text(
                                    'Cancelar',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.headerBottom,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    'Eliminar',
                                    style: TextStyle(
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

    if (confirmed != true) return;

    setState(() {
      _vehicles[index].dispose();
      _vehicles.removeAt(index);
      // Ensure first stays primary
      if (_vehicles.isNotEmpty) _vehicles[0].isPrimary = true;
    });
  }

  Future<void> _save() async {
    for (int i = 0; i < _vehicles.length; i++) {
      if (!_vehicles[i].isValid) {
        _showSnack(
          'El vehículo ${i + 1} tiene un correlativo inválido (mín. 4 caracteres).',
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw StateError('No session');

      final db = FirebaseFirestore.instance;
      final userRef = db.collection('users').doc(uid);
      final batch = db.batch();

      // Mark first as primary
      for (int i = 0; i < _vehicles.length; i++) {
        _vehicles[i].isPrimary = i == 0;
      }

      // Delete removed vehicles
      final existingIds =
          _vehicles.map((v) => v.firestoreId).whereType<String>().toSet();
      final oldDocs = await userRef.collection('vehicles').get();
      for (final doc in oldDocs.docs) {
        if (!existingIds.contains(doc.id)) {
          batch.delete(doc.reference);
        }
      }

      // Upsert vehicles
      for (int i = 0; i < _vehicles.length; i++) {
        final v = _vehicles[i];
        final docId =
            v.firestoreId ?? 'v${DateTime.now().millisecondsSinceEpoch}_$i';
        batch.set(userRef.collection('vehicles').doc(docId), {
          'type': v.type.value,
          'plate': v.fullPlate,
          'isPrimary': i == 0,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Update main doc for backwards compat
      batch.set(userRef, {
        'vehiclePlate': _vehicles.first.fullPlate,
        'vehicleType': _vehicles.first.type.value,
        'plateType': _vehicles.first.type.platePrefix,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;
      _showSnack('Vehículos actualizados ✓');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final headerGradient =
        isDark
            ? const [Color(0xFF111827), Color(0xFF0F172A), Color(0xFF0B1220)]
            : const [AppColors.headerTop, AppColors.headerBottom];

    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: SafeArea(
        bottom: false,
        top: false,
        child: Column(
          children: [
            // ── Gradient header ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: headerGradient,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Mis vehículos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                        children: [
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                // ── Info alert ──
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.headerBottom.withValues(
                                          alpha: 0.08,
                                        ),
                                        AppColors.headerTop.withValues(
                                          alpha: 0.04,
                                        ),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.headerBottom.withValues(
                                        alpha: 0.20,
                                      ),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: AppColors.headerBottom
                                              .withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.info_outline_rounded,
                                          size: 17,
                                          color: AppColors.headerBottom,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Correlativo de placa',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    context.appTextPrimaryColor,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Solo ingresa el número/letras — el prefijo (P, M, C) se agrega automáticamente.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    context
                                                        .appTextSecondaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // ── Add vehicle button (above first card) ──
                                if (_vehicles.length < 4) ...[
                                  GestureDetector(
                                    onTap: _addVehicle,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 13,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.appCardBackground,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AppColors.headerBottom
                                              .withValues(alpha: 0.25),
                                          width: 1.4,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: AppColors.headerBottom
                                                  .withValues(alpha: 0.10),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.add_rounded,
                                              size: 17,
                                              color: AppColors.headerBottom,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Agregar vehículo',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.headerBottom,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                // ── Vehicle cards ──
                                ...List.generate(_vehicles.length, (i) {
                                  return _VehicleCard(
                                    entry: _vehicles[i],
                                    index: i,
                                    isPrimary: i == 0,
                                    onDelete: () => _deleteVehicle(i),
                                    onChanged: () => setState(() {}),
                                  );
                                }),

                                if (_vehicles.isEmpty)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.directions_car_outlined,
                                            size: 48,
                                            color: AppColors.headerBottom
                                                .withValues(alpha: 0.3),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No hay vehículos registrados',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  context
                                                      .appTextSecondaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // ── Save button ──
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            color: context.appSectionBackground,
                            child: MyButton(
                              text:
                                  _saving ? 'Guardando...' : 'Guardar cambios',
                              loading: _saving,
                              onTap: _saving ? null : _save,
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
  }
}

// ─── Vehicle edit entry ────────────────────────────────────────────────────────
class _VehicleEditEntry {
  final String? firestoreId;
  VehicleType type;
  final TextEditingController correlativeController;
  bool isPrimary;

  _VehicleEditEntry({
    this.firestoreId,
    this.type = VehicleType.car,
    String correlative = '',
    this.isPrimary = false,
  }) : correlativeController = TextEditingController(text: correlative);

  void dispose() => correlativeController.dispose();

  String get fullPlate {
    final body = correlativeController.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    return '${type.platePrefix}$body';
  }

  bool get isValid =>
      correlativeController.text
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]'), '')
          .length >=
      4;
}

// ─── Vehicle card ──────────────────────────────────────────────────────────────
class _VehicleCard extends StatefulWidget {
  final _VehicleEditEntry entry;
  final int index;
  final bool isPrimary;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _VehicleCard({
    required this.entry,
    required this.index,
    required this.isPrimary,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends State<_VehicleCard> {
  @override
  void initState() {
    super.initState();
    widget.entry.correlativeController.addListener(() => setState(() {}));
  }

  String get _platePreview {
    final raw = widget.entry.correlativeController.text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (raw.isEmpty) return '${widget.entry.type.platePrefix}···';
    return '${widget.entry.type.platePrefix}$raw';
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              widget.isPrimary
                  ? AppColors.headerBottom.withValues(alpha: 0.30)
                  : context.appBorderColor,
          width: widget.isPrimary ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.16 : 0.05,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color:
                  widget.isPrimary
                      ? AppColors.headerBottom.withValues(alpha: 0.05)
                      : context.appCardBackgroundSoft,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.headerBottom.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    entry.type == VehicleType.car
                        ? Icons.directions_car_outlined
                        : entry.type == VehicleType.motorcycle
                        ? Icons.two_wheeler_outlined
                        : Icons.directions_bus_outlined,
                    size: 17,
                    color: AppColors.headerBottom,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.isPrimary
                      ? 'Vehículo principal'
                      : 'Vehículo ${widget.index + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        widget.isPrimary
                            ? AppColors.headerBottom
                            : context.appTextPrimaryColor,
                  ),
                ),
                if (widget.isPrimary) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.headerBottom.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PRINCIPAL',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.headerBottom,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Body ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                // Type selector
                Row(
                  children:
                      VehicleType.values.map((t) {
                        final selected = entry.type == t;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => entry.type = t);
                              widget.onChanged();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: EdgeInsets.only(
                                right: t == VehicleType.other ? 0 : 8,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color:
                                    selected
                                        ? AppColors.headerBottom
                                        : context.appInputBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    t == VehicleType.car
                                        ? Icons.directions_car_rounded
                                        : t == VehicleType.motorcycle
                                        ? Icons.two_wheeler_rounded
                                        : Icons.directions_bus_rounded,
                                    size: 20,
                                    color:
                                        selected
                                            ? Colors.white
                                            : context.appTextSecondaryColor,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          selected
                                              ? Colors.white
                                              : context.appTextSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),

                const SizedBox(height: 14),

                // Correlative input
                Container(
                  decoration: BoxDecoration(
                    color: context.appInputBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.headerBottom,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(14),
                            bottomLeft: Radius.circular(14),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            entry.type.platePrefix,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: entry.correlativeController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]'),
                            ),
                            LengthLimitingTextInputFormatter(8),
                          ],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.appTextPrimaryColor,
                            letterSpacing: 2,
                          ),
                          decoration: InputDecoration(
                            hintText: '123ABC',
                            hintStyle: TextStyle(
                              fontSize: 16,
                              color: context.appTextSecondaryColor,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Plate preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.headerBottom.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.headerBottom.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.credit_card_rounded,
                        size: 14,
                        color: AppColors.headerBottom.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Placa: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.headerBottom.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _platePreview,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.headerBottom,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  entry.type.hint,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.appTextSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
