// lib/features/users/pages/configure_profile_page.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/users/users.dart';

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

  AppCountryCode _selectedCountry = AppCountryCodes.defaultCode; // GT default
  String _gender = 'male';
  bool _saving = false;
  bool _loadingProfile = true;

  File? _imageFile;
  String _existingPhotoUrl = '';
  bool _pickingImage = false;

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

  void _applyPhoneValue(String rawPhone) {
    final parsed = AppCountryCode.parse(
      rawPhone,
      fallback: AppCountryCodes.defaultCode,
    );
    _selectedCountry = parsed.country;
    _phoneNumberCtrl.text = parsed.number;
  }

  _VehicleEditEntry? _resolvePrimaryVehicleEntry() {
    if (_vehicles.isNotEmpty) return _vehicles.first;
    return null;
  }

  Future<void> _loadUserData() async {
    try {
      final u = _auth.currentUser;
      if (u == null) return;
      await u.reload();
      final refreshedUser = _auth.currentUser ?? u;

      final db = FirebaseFirestore.instance;
      final doc = await db.collection('users').doc(refreshedUser.uid).get();
      final data = doc.data() ?? {};
      final rawGender = (data['gender'] as String?)?.trim() ?? '';
      final firestorePhoto = (data['photoURL'] as String?)?.trim() ?? '';
      final authPhoto = (refreshedUser.photoURL ?? u.photoURL ?? '').trim();
      final firestorePhone = (data['phone'] as String?)?.trim() ?? '';
      final authPhone =
          (refreshedUser.phoneNumber ?? u.phoneNumber ?? '').trim();

      _nameCtrl.text =
          (data['name'] as String? ?? refreshedUser.displayName ?? '').trim();
      _dobCtrl.text = (data['dob'] as String?) ?? '';
      _gender = rawGender.isNotEmpty ? rawGender : 'male';
      _existingPhotoUrl =
          firestorePhoto.isNotEmpty ? firestorePhoto : authPhoto;

      _applyPhoneValue(firestorePhone.isNotEmpty ? firestorePhone : authPhone);

      // Load vehicles
      final vehicleSnap =
          await db
              .collection('users')
              .doc(refreshedUser.uid)
              .collection('vehicles')
              .get();

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
            // Base this on ThemeData.light() instead of Theme.of(ctx): the
            // picker is always meant to render with light colors, but
            // copyWith-ing only colorScheme onto a dark ambient theme left
            // textTheme (e.g. the year-picker's text) dark-on-dark/unreadable.
            data: ThemeData.light().copyWith(
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
    if (_pickingImage) return; // guard: image_picker throws "already_active"
    _pickingImage = true;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _imageFile = File(picked.path));
      }
    } on PlatformException catch (e) {
      debugPrint('[ConfigureProfile] pickImage failed: ${e.code} ${e.message}');
    } finally {
      _pickingImage = false;
    }
  }

  Future<String?> _uploadImage(String uid) async {
    if (_imageFile == null) return null;
    final ref = FirebaseStorage.instance.ref().child('users/$uid/profile.jpg');
    await ref.putFile(_imageFile!);
    return ref.getDownloadURL();
  }

  Future<void> _showCountryPicker() async {
    final picked = await AppCountryPicker.show(
      context,
      selected: _selectedCountry,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedCountry = picked);
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

      // Update main doc primary vehicle for backwards compat when available.
      final primaryVehicle = _resolvePrimaryVehicleEntry();
      if (primaryVehicle != null) {
        batch.set(userRef, {
          'vehiclePlate': primaryVehicle.fullPlate,
          'vehicleType': primaryVehicle.type.value,
          'plateType': primaryVehicle.type.platePrefix,
        }, SetOptions(merge: true));
      }

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
      backgroundColor: context.appPageBackground,
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
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors:
                        context.isDarkMode
                            ? const [
                              Color(0xFF111827),
                              Color(0xFF0F172A),
                              Color(0xFF0B1220),
                            ]
                            : const [
                              AppColors.headerTop,
                              AppColors.headerBottom,
                            ],
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
                  decoration: BoxDecoration(
                    color: context.appSectionBackground,
                    borderRadius: const BorderRadius.only(
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
                                    Text(
                                      'Editar perfil',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            context.isDarkMode
                                                ? Colors.white
                                                : AppColors.headerBottom,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Actualiza tu información y vehículos.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: context.appTextSecondaryColor,
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
                                      hint: '',
                                    ),
                                    const SizedBox(height: 4),
                                    _StyledField(
                                      controller: _nameCtrl,
                                      hint: '',
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
                                      hint: '',
                                    ),
                                    const SizedBox(height: 4),
                                    _ReadonlyField(
                                      controller: _dobCtrl,
                                      hint: 'DD/MM/AAAA',
                                      icon: Icons.calendar_today_outlined,
                                      onTap: _pickDob,
                                    ),

                                    const SizedBox(height: 16),
                                    _FieldLabel(
                                      label: 'Correo electrónico',
                                      hint: '',
                                      trailing: _InfoIconButton(
                                        message:
                                            'No editable — asociado a tu cuenta',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
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
                                      hint: '',
                                    ),
                                    const SizedBox(height: 4),
                                    AppPhoneField(
                                      numberController: _phoneNumberCtrl,
                                      selectedCountry: _selectedCountry,
                                      onPickCountry: _showCountryPicker,
                                    ),

                                    const SizedBox(height: 16),
                                    _FieldLabel(label: 'Género', hint: ''),
                                    const SizedBox(height: 6),
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
                                          color: context.appCardBackgroundSoft,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: context.appBorderColor,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha:
                                                    context.isDarkMode
                                                        ? 0.14
                                                        : 0.04,
                                              ),
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
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.directions_car_outlined,
                                                size: 18,
                                                color:
                                                    context.appBrandIconColor,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
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
                                                      color:
                                                          context
                                                              .appTextPrimaryColor,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    'Agrega, edita o elimina tus vehículos',
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
                                            Icon(
                                              Icons.chevron_right_rounded,
                                              color: context.appBrandIconColor,
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
      color: Colors.white.withValues(alpha: opacity),
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
              alpha: context.isDarkMode ? 0.14 : 0.05,
            ),
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
                    Icons.directions_car_outlined,
                    size: 17,
                    color: context.appBrandIconColor,
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
                if (widget.canRemove)
                  GestureDetector(
                    onTap: widget.onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
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
                        size: 15,
                        color: AppColors.headerBottom.withValues(alpha: 0.6),
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

// ─── Reusable field helpers ────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  final String hint;
  final Widget? trailing;

  const _FieldLabel({
    required this.label,
    required this.hint,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimaryColor,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (hint.trim().isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            hint,
            style: TextStyle(
              fontSize: 11,
              color: context.appTextSecondaryColor,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoIconButton extends StatelessWidget {
  const _InfoIconButton({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        showDialog<void>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                backgroundColor: ctx.appCardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  'Correo electrónico',
                  style: TextStyle(
                    color: ctx.appTextPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: Text(
                  message,
                  style: TextStyle(color: ctx.appTextSecondaryColor),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: context.appTextSecondaryColor,
        ),
      ),
    );
  }
}

class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  const _StyledField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.appTextPrimaryColor,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13,
          color: context.appTextSecondaryColor,
        ),
        prefixIcon: Icon(icon, size: 18, color: context.appBrandIconColor),
        filled: true,
        fillColor: context.appInputBackgroundActive,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.appBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.appBorderColor),
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
        color:
            muted ? context.appTextSecondaryColor : context.appTextPrimaryColor,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13,
          color: context.appTextSecondaryColor,
        ),
        prefixIcon: Icon(
          icon,
          size: 18,
          color:
              muted
                  ? context.appTextSecondaryColor
                  : (context.isDarkMode &&
                          icon == Icons.calendar_today_outlined)
                  ? Colors.white
                  : AppColors.headerBottom,
        ),
        suffixIcon:
            onTap != null && !muted
                ? Icon(
                  Icons.edit_calendar_outlined,
                  size: 16,
                  color: AppColors.headerBottom.withValues(alpha: 0.5),
                )
                : muted
                ? Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: context.appTextSecondaryColor,
                )
                : null,
        filled: true,
        fillColor:
            muted
                ? context.appInputBackground
                : context.appInputBackgroundActive,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.appBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.appBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.appBorderColor),
        ),
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
            color: AppColors.headerBottom.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: context.appBrandIconColor),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimaryColor,
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
            color:
                selected ? AppColors.headerBottom : context.appInputBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : context.appTextSecondaryColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      selected ? Colors.white : context.appTextSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
