// lib/features/users/pages/configure_profile_page.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_button.dart';
import 'package:mapbox_api/features/users/models/vehicule.dart';
import 'package:mapbox_api/features/users/providers/user_providers.dart';
import 'package:mapbox_api/features/users/pages/edit_vehicles_page.dart';

// ─── Country code model ────────────────────────────────────────────────────────
class _CountryCode {
  final String flag;
  final String name;
  final String code;
  const _CountryCode(this.flag, this.name, this.code);
}

const _kCountryCodes = [
  _CountryCode('🇬🇹', 'Guatemala', '+502'),
  _CountryCode('🇲🇽', 'México', '+52'),
  _CountryCode('🇺🇸', 'Estados Unidos', '+1'),
  _CountryCode('🇸🇻', 'El Salvador', '+503'),
  _CountryCode('🇭🇳', 'Honduras', '+504'),
  _CountryCode('🇳🇮', 'Nicaragua', '+505'),
  _CountryCode('🇨🇷', 'Costa Rica', '+506'),
  _CountryCode('🇵🇦', 'Panamá', '+507'),
  _CountryCode('🇨🇴', 'Colombia', '+57'),
  _CountryCode('🇪🇸', 'España', '+34'),
  _CountryCode('🇦🇷', 'Argentina', '+54'),
  _CountryCode('🇨🇱', 'Chile', '+56'),
  _CountryCode('🇵🇪', 'Perú', '+51'),
  _CountryCode('🇻🇪', 'Venezuela', '+58'),
  _CountryCode('🇧🇷', 'Brasil', '+55'),
];

// ─── Vehicle edit entry ────────────────────────────────────────────────────────
class _VehicleEditEntry {
  final String? firestoreId;
  VehicleType type;
  final TextEditingController correlativeController;
  bool isPrimary;
  bool isNew;

  _VehicleEditEntry({
    this.firestoreId,
    this.type = VehicleType.car,
    String correlative = '',
    this.isPrimary = false,
    this.isNew = false,
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

class ConfigureProfilePage extends ConsumerStatefulWidget {
  const ConfigureProfilePage({super.key});

  @override
  ConsumerState<ConfigureProfilePage> createState() =>
      _ConfigureProfilePageState();
}

class _ConfigureProfilePageState extends ConsumerState<ConfigureProfilePage>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;

  final _nameCtrl = TextEditingController();
  final _phoneNumberCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  _CountryCode _selectedCountry = _kCountryCodes.first; // GT default
  String _gender = 'male';
  bool _saving = false;
  bool _loadingProfile = true;

  File? _imageFile;
  String _existingPhotoUrl = '';

  final List<_VehicleEditEntry> _vehicles = [];

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadUserData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneNumberCtrl.dispose();
    _dobCtrl.dispose();
    for (final v in _vehicles) {
      v.dispose();
    }
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final u = _auth.currentUser;
      if (u == null) return;

      final db = FirebaseFirestore.instance;
      final doc = await db.collection('users').doc(u.uid).get();
      final data = doc.data() ?? {};

      _nameCtrl.text = (data['name'] as String? ?? u.displayName ?? '').trim();
      _dobCtrl.text = (data['dob'] as String?) ?? '';
      _gender =
          ((data['gender'] as String?) ?? 'male').isNotEmpty
              ? (data['gender'] as String)
              : 'male';
      _existingPhotoUrl =
          (data['photoURL'] as String? ?? u.photoURL ?? '').trim();

      // Parse phone — split country code from number
      final rawPhone = (data['phone'] as String?) ?? '';
      _CountryCode matched = _kCountryCodes.first;
      String numberPart = rawPhone;
      for (final c in _kCountryCodes) {
        if (rawPhone.startsWith(c.code)) {
          matched = c;
          numberPart = rawPhone.substring(c.code.length).trim();
          break;
        }
      }
      _selectedCountry = matched;
      _phoneNumberCtrl.text = numberPart;

      // Load vehicles
      final vehicleSnap =
          await db.collection('users').doc(u.uid).collection('vehicles').get();

      if (vehicleSnap.docs.isNotEmpty) {
        for (final vDoc in vehicleSnap.docs) {
          final vData = vDoc.data();
          final plate = (vData['plate'] as String?) ?? '';
          final typeStr = (vData['type'] as String?) ?? 'car';
          final vType = vehicleTypeFromString(typeStr);
          // Strip prefix to get correlative
          final correlative =
              plate.isNotEmpty && plate.length > 1 ? plate.substring(1) : plate;

          _vehicles.add(
            _VehicleEditEntry(
              firestoreId: vDoc.id,
              type: vType,
              correlative: correlative,
              isPrimary: (vData['isPrimary'] as bool?) ?? false,
            ),
          );
        }
        // Sort: primary first
        _vehicles.sort((a, b) => b.isPrimary ? 1 : -1);
      } else {
        // Fallback to main doc vehiclePlate
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
          _vehicles.add(_VehicleEditEntry(isPrimary: true, isNew: true));
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loadingProfile = false);
        _fadeCtrl.forward();
      }
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Fecha de nacimiento',
      builder:
          (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.light(primary: AppColors.headerBottom),
            ),
            child: child!,
          ),
    );
    if (selected != null && mounted) {
      _dobCtrl.text =
          '${selected.day.toString().padLeft(2, '0')}/${selected.month.toString().padLeft(2, '0')}/${selected.year}';
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<String?> _uploadImage(String uid) async {
    if (_imageFile == null) return null;
    final ref = FirebaseStorage.instance.ref().child('users/$uid/profile.jpg');
    await ref.putFile(_imageFile!);
    return ref.getDownloadURL();
  }

  void _addVehicle() {
    if (_vehicles.length >= 4) return;
    setState(() => _vehicles.add(_VehicleEditEntry(isNew: true)));
  }

  void _removeVehicle(int index) {
    if (_vehicles.length <= 1) return;
    setState(() {
      _vehicles[index].dispose();
      _vehicles.removeAt(index);
      // Ensure first is primary
      if (_vehicles.isNotEmpty) _vehicles[0].isPrimary = true;
    });
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.4,
          maxChildSize: 0.75,
          expand: false,
          builder: (_, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle + title — fixed
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Código de país',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Divider(color: Colors.grey.shade100, height: 1),
                      ],
                    ),
                  ),
                  // Scrollable list
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: _kCountryCodes.length,
                      itemBuilder: (_, i) {
                        final c = _kCountryCodes[i];
                        final selected = c.code == _selectedCountry.code;
                        return InkWell(
                          onTap: () {
                            setState(() => _selectedCountry = c);
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  selected
                                      ? AppColors.headerBottom.withOpacity(0.07)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    selected
                                        ? AppColors.headerBottom.withOpacity(
                                          0.25,
                                        )
                                        : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  c.flag,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          selected
                                              ? AppColors.headerBottom
                                              : const Color(0xFF3D4554),
                                    ),
                                  ),
                                ),
                                Text(
                                  c.code,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        selected
                                            ? AppColors.headerBottom
                                            : const Color(0xFF6B7280),
                                  ),
                                ),
                                if (selected) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.check_rounded,
                                    color: AppColors.headerBottom,
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    // Validate vehicles
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
      final user = _auth.currentUser!;
      String? uploadedPhotoUrl;

      if (_imageFile != null) {
        uploadedPhotoUrl = await _uploadImage(user.uid);
        await user.updatePhotoURL(uploadedPhotoUrl);
      }
      if (_nameCtrl.text.trim().isNotEmpty) {
        await user.updateDisplayName(_nameCtrl.text.trim());
      }

      final fullPhone =
          '${_selectedCountry.code} ${_phoneNumberCtrl.text.trim()}';

      await ref.read(updateBasicProfileProvider)(
        name: _nameCtrl.text.trim(),
        phone: fullPhone,
        email: user.email ?? '',
        dob: _dobCtrl.text.trim(),
        gender: _gender,
        photoUrl: uploadedPhotoUrl,
      );

      // Save vehicles
      final db = FirebaseFirestore.instance;
      final userRef = db.collection('users').doc(user.uid);
      final batch = db.batch();

      // Ensure first vehicle is primary
      for (int i = 0; i < _vehicles.length; i++) {
        _vehicles[i].isPrimary = i == 0;
      }

      // Delete old vehicle docs not in current list
      final existingIds =
          _vehicles.map((v) => v.firestoreId).whereType<String>().toSet();
      final oldDocs = await userRef.collection('vehicles').get();
      for (final doc in oldDocs.docs) {
        if (!existingIds.contains(doc.id)) {
          batch.delete(doc.reference);
        }
      }

      // Upsert current vehicles
      for (int i = 0; i < _vehicles.length; i++) {
        final v = _vehicles[i];
        final docId = v.firestoreId ?? 'v${i + 1}';
        batch.set(userRef.collection('vehicles').doc(docId), {
          'type': v.type.value,
          'plate': v.fullPlate,
          'isPrimary': i == 0,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Update main doc primary vehicle for backwards compat
      batch.set(userRef, {
        'vehiclePlate': _vehicles.first.fullPlate,
        'vehicleType': _vehicles.first.type.value,
        'plateType': _vehicles.first.type.platePrefix,
      }, SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;
      _showSnack('Perfil actualizado ✓');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnack('No se pudo guardar: $e');
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
    final user = _auth.currentUser;
    final screen = MediaQuery.of(context).size;

    final ImageProvider<Object>? avatarProvider =
        _imageFile != null
            ? FileImage(_imageFile!)
            : (_existingPhotoUrl.isNotEmpty
                ? NetworkImage(_existingPhotoUrl)
                : null);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        top: false,
        child: SizedBox(
          height: screen.height,
          child: Stack(
            children: [
              // ── Gradient header ──
              Container(
                height: screen.height * 0.40,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.headerTop, AppColors.headerBottom],
                  ),
                ),
              ),
              Positioned(top: 40, left: -20, child: _blob(90, 0.12)),
              Positioned(top: -10, right: -10, child: _blob(120, 0.10)),

              // Back button
              Positioned(
                top: 15,
                left: 18,
                child: SafeArea(
                  child: TextButton.icon(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                    ),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                    ),
                    label: const Text('Regresar'),
                  ),
                ),
              ),

              // Avatar
              Positioned(
                top: screen.height * 0.09,
                left: 28,
                right: 28,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child:
                              avatarProvider != null
                                  ? Image(
                                    image: avatarProvider,
                                    fit: BoxFit.cover,
                                  )
                                  : Container(
                                    color: Colors.white,
                                    child: const Icon(
                                      Icons.person_rounded,
                                      size: 58,
                                      color: AppColors.headerBottom,
                                    ),
                                  ),
                        ),
                      ),
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: InkWell(
                            onTap: _saving ? null : _pickImage,
                            customBorder: const CircleBorder(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.camera_alt_outlined,
                                color: AppColors.headerBottom,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Sheet ──
              Positioned(
                top: screen.height * 0.26,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(34),
                      topRight: Radius.circular(34),
                    ),
                  ),
                  child:
                      _loadingProfile
                          ? const Center(child: CircularProgressIndicator())
                          : FadeTransition(
                            opacity: _fadeAnim,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                28,
                                24,
                                40,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Editar perfil',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.headerBottom,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Actualiza tu información y vehículos.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF8A94A6),
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    // ── Personal info ──
                                    _SectionHeader(
                                      icon: Icons.person_outline_rounded,
                                      title: 'Información personal',
                                    ),
                                    const SizedBox(height: 14),

                                    _FieldLabel(
                                      label: 'Nombre completo',
                                      hint:
                                          'Escribe tu nombre como aparece en tu DPI',
                                    ),
                                    const SizedBox(height: 6),
                                    _StyledField(
                                      controller: _nameCtrl,
                                      hint: 'Ej: Juan Carlos Pérez',
                                      icon: Icons.person_outline,
                                      validator:
                                          (v) =>
                                              (v?.trim().isEmpty ?? true)
                                                  ? 'Ingresa tu nombre'
                                                  : null,
                                    ),

                                    const SizedBox(height: 16),
                                    _FieldLabel(
                                      label: 'Fecha de nacimiento',
                                      hint: 'Usada para verificar tu edad',
                                    ),
                                    const SizedBox(height: 6),
                                    _ReadonlyField(
                                      controller: _dobCtrl,
                                      hint: 'DD/MM/AAAA',
                                      icon: Icons.calendar_today_outlined,
                                      onTap: _pickDob,
                                    ),

                                    const SizedBox(height: 16),
                                    _FieldLabel(
                                      label: 'Correo electrónico',
                                      hint:
                                          'No editable — asociado a tu cuenta',
                                    ),
                                    const SizedBox(height: 6),
                                    _ReadonlyField(
                                      controller: TextEditingController(
                                        text: user?.email ?? '',
                                      ),
                                      hint: 'correo@ejemplo.com',
                                      icon: Icons.mail_outline_rounded,
                                      onTap: null,
                                      muted: true,
                                    ),

                                    const SizedBox(height: 16),
                                    _FieldLabel(
                                      label: 'Número de teléfono',
                                      hint:
                                          'Incluye tu código de país y número',
                                    ),
                                    const SizedBox(height: 6),
                                    _PhoneField(
                                      numberCtrl: _phoneNumberCtrl,
                                      selectedCountry: _selectedCountry,
                                      onPickCountry: _showCountryPicker,
                                    ),

                                    const SizedBox(height: 16),
                                    _FieldLabel(
                                      label: 'Género',
                                      hint:
                                          'Opcional — ayuda a personalizar tu experiencia',
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _GenderChip(
                                          label: 'Masculino',
                                          icon: Icons.male_rounded,
                                          selected: _gender == 'male',
                                          onTap:
                                              () => setState(
                                                () => _gender = 'male',
                                              ),
                                        ),
                                        const SizedBox(width: 10),
                                        _GenderChip(
                                          label: 'Femenino',
                                          icon: Icons.female_rounded,
                                          selected: _gender == 'female',
                                          onTap:
                                              () => setState(
                                                () => _gender = 'female',
                                              ),
                                        ),
                                        const SizedBox(width: 10),
                                        _GenderChip(
                                          label: 'Otro',
                                          icon: Icons.person_outline_rounded,
                                          selected: _gender == 'other',
                                          onTap:
                                              () => setState(
                                                () => _gender = 'other',
                                              ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 28),

                                    // ── Vehicles nav ──
                                    _SectionHeader(
                                      icon: Icons.directions_car_outlined,
                                      title: 'Mis vehículos',
                                    ),
                                    const SizedBox(height: 10),
                                    InkWell(
                                      onTap:
                                          () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) =>
                                                      const EditVehiclesPage(),
                                            ),
                                          ),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: AppColors.borderSoft,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.headerBottom
                                                  .withOpacity(0.04),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: AppColors.headerBottom
                                                    .withOpacity(0.08),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.directions_car_outlined,
                                                size: 18,
                                                color: AppColors.headerBottom,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Editar vehículos',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    'Agrega, edita o elimina tus vehículos',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF8A94A6),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: Colors.grey.shade400,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 32),

                                    MyButton(
                                      text:
                                          _saving
                                              ? 'Guardando...'
                                              : 'Guardar cambios',
                                      loading: _saving,
                                      onTap: _saving ? null : _save,
                                      margin: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blob(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(opacity),
      shape: BoxShape.circle,
    ),
  );
}

// ─── Vehicle edit card ─────────────────────────────────────────────────────────
class _VehicleEditCard extends StatefulWidget {
  final _VehicleEditEntry entry;
  final int index;
  final bool isPrimary;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _VehicleEditCard({
    required this.entry,
    required this.index,
    required this.isPrimary,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_VehicleEditCard> createState() => _VehicleEditCardState();
}

class _VehicleEditCardState extends State<_VehicleEditCard> {
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              widget.isPrimary
                  ? AppColors.headerBottom.withOpacity(0.30)
                  : AppColors.borderSoft,
          width: widget.isPrimary ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color:
                  widget.isPrimary
                      ? AppColors.headerBottom.withOpacity(0.05)
                      : const Color(0xFFF8FAFC),
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
                    color: AppColors.headerBottom.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.directions_car_outlined,
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
                            : const Color(0xFF3D4554),
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
                      color: AppColors.headerBottom.withOpacity(0.10),
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
                if (widget.canRemove)
                  GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
              ],
            ),
          ),

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
                                        : const Color(0xFFF1F5F9),
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
                                            : const Color(0xFF6B7280),
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
                                              : const Color(0xFF6B7280),
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
                    color: const Color(0xFFF1F5F9),
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                            letterSpacing: 2,
                          ),
                          decoration: InputDecoration(
                            hintText: '123ABC',
                            hintStyle: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade400,
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
                    color: AppColors.headerBottom.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.headerBottom.withOpacity(0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.credit_card_rounded,
                        size: 15,
                        color: AppColors.headerBottom.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Placa: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.headerBottom.withOpacity(0.6),
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
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8A94A6),
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

// ─── Reusable field helpers ────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final String hint;

  const _FieldLabel({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: const TextStyle(fontSize: 11, color: Color(0xFF8A94A6)),
        ),
      ],
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const _StyledField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8A94A6)),
        prefixIcon: Icon(icon, size: 18, color: AppColors.headerBottom),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.headerBottom, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
        ),
      ),
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final VoidCallback? onTap;
  final bool muted;

  const _ReadonlyField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: muted ? const Color(0xFF8A94A6) : const Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8A94A6)),
        prefixIcon: Icon(
          icon,
          size: 18,
          color: muted ? const Color(0xFF8A94A6) : AppColors.headerBottom,
        ),
        suffixIcon:
            onTap != null && !muted
                ? Icon(
                  Icons.edit_calendar_outlined,
                  size: 16,
                  color: AppColors.headerBottom.withOpacity(0.5),
                )
                : muted
                ? const Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: Color(0xFF8A94A6),
                )
                : null,
        filled: true,
        fillColor: muted ? const Color(0xFFF1F5F9) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.borderSoft),
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  final TextEditingController numberCtrl;
  final _CountryCode selectedCountry;
  final VoidCallback onPickCountry;

  const _PhoneField({
    required this.numberCtrl,
    required this.selectedCountry,
    required this.onPickCountry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          // Country code button
          GestureDetector(
            onTap: onPickCountry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.borderSoft)),
              ),
              child: Row(
                children: [
                  Text(
                    selectedCountry.flag,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selectedCountry.code,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headerBottom,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.headerBottom.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
          // Number input
          Expanded(
            child: TextField(
              controller: numberCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\s\-]')),
              ],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              decoration: const InputDecoration(
                hintText: '5555 1234',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.headerBottom.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: AppColors.headerBottom),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.headerBottom : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
