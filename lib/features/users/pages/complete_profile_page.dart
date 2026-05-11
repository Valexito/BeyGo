import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/users/users.dart';
import 'package:beygo/features/auth/providers/auth_providers.dart'
    show signOutAndNavigateToAuth;

class CompleteProfilePage extends ConsumerStatefulWidget {
  final User user;
  final bool isNewUser;
  final String? password;

  const CompleteProfilePage({
    super.key,
    required this.user,
    required this.isNewUser,
    this.password,
  });

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _phoneNumberCtrl = TextEditingController();

  bool _isSaving = false;
  bool _isGoingBack = false;
  final List<_VehicleEntry> _vehicles = [];
  String _existingPhotoUrl = '';

  AppCountryCode _selectedCountry = AppCountryCodes.defaultCode;

  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();

    final u = widget.user;
    if ((u.displayName ?? '').trim().isNotEmpty) {
      _nameController.text = u.displayName!.trim();
    }
    _existingPhotoUrl = (u.photoURL ?? '').trim();
    _applyPhoneValue((u.phoneNumber ?? '').trim());
    _loadExistingProfile();

    _vehicles.add(_VehicleEntry());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneNumberCtrl.dispose();
    for (final v in _vehicles) {
      v.dispose();
    }
    _slideController.dispose();
    super.dispose();
  }

  void _addVehicle() {
    if (_vehicles.length >= 4) return;
    setState(() => _vehicles.add(_VehicleEntry()));
  }

  void _removeVehicle(int index) {
    if (_vehicles.length <= 1) return;
    setState(() {
      _vehicles[index].dispose();
      _vehicles.removeAt(index);
    });
  }

  String _buildPlate(_VehicleEntry v) {
    final prefix = v.type.platePrefix;
    var body = v.correlativeController.text.toUpperCase().trim();
    body = body.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return '$prefix$body';
  }

  bool _isValidCorrelative(String value) {
    final clean = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return clean.length >= 4;
  }

  Future<void> _loadExistingProfile() async {
    try {
      await widget.user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser ?? widget.user;
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(refreshedUser.uid)
              .get();
      final data = doc.data() ?? {};
      final firestoreName = (data['name'] as String? ?? '').trim();
      final firestorePhone = (data['phone'] as String? ?? '').trim();
      final firestorePhoto = (data['photoURL'] as String? ?? '').trim();
      final authPhoto =
          (refreshedUser.photoURL ?? widget.user.photoURL ?? '').trim();
      final authPhone =
          (refreshedUser.phoneNumber ?? widget.user.phoneNumber ?? '').trim();

      if (!mounted) return;
      setState(() {
        if (firestoreName.isNotEmpty) {
          _nameController.text = firestoreName;
        }
        _existingPhotoUrl =
            firestorePhoto.isNotEmpty ? firestorePhoto : authPhoto;
        _applyPhoneValue(
          firestorePhone.isNotEmpty ? firestorePhone : authPhone,
        );
      });
    } catch (_) {}
  }

  void _applyPhoneValue(String rawPhone) {
    if (rawPhone.isEmpty) return;

    final parsed = AppCountryCode.parse(
      rawPhone,
      fallback: AppCountryCodes.defaultCode,
    );
    _selectedCountry = parsed.country;
    _phoneNumberCtrl.text = parsed.number;
  }

  Future<void> _goBack() async {
    if (_isGoingBack) return;
    setState(() => _isGoingBack = true);
    try {
      await signOutAndNavigateToAuth(
        context,
        message: 'Saliendo...',
        submessage: 'Volviendo al acceso de BeyGo.',
      );
    } catch (_) {
      if (mounted) setState(() => _isGoingBack = false);
    }
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
    final u = FirebaseAuth.instance.currentUser;
    await u?.reload();
    if (!mounted) return;

    final providerIds = u?.providerData.map((e) => e.providerId).toSet() ?? {};
    final isPasswordUser = providerIds.contains('password');
    final isGoogleUser = providerIds.contains('google.com');
    final isAppleUser = providerIds.contains('apple.com');

    if (isPasswordUser && !isGoogleUser && !isAppleUser) {
      if (u?.emailVerified != true) {
        _showSnack('Verifica tu correo electrónico antes de continuar.');
        return;
      }
    }

    final name = _nameController.text.trim();
    final numberPart = _phoneNumberCtrl.text.trim();
    final phone = '${_selectedCountry.code} $numberPart';

    if (name.isEmpty) {
      _showSnack('Ingresa tu nombre completo.');
      return;
    }
    if (numberPart.isEmpty) {
      _showSnack('Ingresa tu número de teléfono.');
      return;
    }

    for (int i = 0; i < _vehicles.length; i++) {
      final v = _vehicles[i];
      if (!_isValidCorrelative(v.correlativeController.text)) {
        _showSnack(
          'El vehículo ${i + 1} tiene un correlativo inválido (mín. 4 caracteres).',
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final vehicleList =
          _vehicles.asMap().entries.map((e) {
            final idx = e.key;
            final v = e.value;
            final plate = _buildPlate(v);
            return Vehicle(
              id: 'v${idx + 1}',
              type: v.type,
              plate: plate,
              isPrimary: idx == 0,
              createdAt: DateTime.now(),
            );
          }).toList();

      final primaryVehicle = vehicleList.first;

      await ref.read(saveProfileProvider)(
        name: name,
        phone: phone,
        role: 'user',
        vehiclePlate: primaryVehicle.plate,
        vehicleType: primaryVehicle.type.value,
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final db = FirebaseFirestore.instance;
        final userRef = db.collection('users').doc(currentUser.uid);
        final batch = db.batch();

        batch.set(userRef, {
          'plateType': primaryVehicle.type.platePrefix,
        }, SetOptions(merge: true));

        for (final vehicle in vehicleList) {
          batch.set(
            userRef.collection('vehicles').doc(vehicle.id),
            vehicle.toMap(),
          );
        }

        await batch.commit();
      }

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaving) {
      return const AppLoadingScreen(
        message: 'Creando tu perfil...',
        submessage: 'Esto solo tomará un momento',
        variant: LoadingVariant.profile,
      );
    }

    if (_isGoingBack) {
      return const AppLoadingScreen(
        message: 'Regresando...',
        variant: LoadingVariant.general,
      );
    }

    final screen = MediaQuery.of(context).size;
    final headerGradient =
        context.isDarkMode
            ? const [Color(0xFF111827), Color(0xFF0F172A), Color(0xFF0B1220)]
            : const [AppColors.headerTop, AppColors.headerBottom];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _goBack(),
      child: Scaffold(
        backgroundColor: context.appPageBackground,
        body: SafeArea(
          top: false,
          child: SizedBox(
            height: screen.height,
            child: Stack(
              children: [
                // Gradient header
                Container(
                  height: screen.height * 0.38,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: headerGradient,
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
                      onPressed: _isGoingBack ? null : _goBack,
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

                // Icon circle
                Positioned(
                  top: screen.height * 0.10,
                  left: 28,
                  right: 28,
                  child: Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1.4,
                        ),
                      ),
                      child: ClipOval(
                        child:
                            _existingPhotoUrl.isNotEmpty
                                ? Image.network(
                                  _existingPhotoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => const Icon(
                                        Icons.badge_outlined,
                                        size: 36,
                                        color: Colors.white,
                                      ),
                                )
                                : const Icon(
                                  Icons.badge_outlined,
                                  size: 36,
                                  color: Colors.white,
                                ),
                      ),
                    ),
                  ),
                ),

                // Content sheet — same style as SignUpPage
                Positioned(
                  top: screen.height * 0.24,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.appSectionBackground,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(34),
                          topRight: Radius.circular(34),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Completa tu perfil',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: context.appBrandTextColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Agrega tus datos para habilitar todas las funciones.',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.appTextSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // ── Personal info ──────────────────────────────
                            _SectionHeader(
                              icon: Icons.person_outline_rounded,
                              title: 'Información personal',
                            ),
                            const SizedBox(height: 14),

                            const _FieldLabel('Nombre completo'),
                            const SizedBox(height: 6),
                            _Field(
                              controller: _nameController,
                              hint: 'Ej: Juan Carlos Pérez',
                              icon: Icons.person_outline_rounded,
                              validator:
                                  (v) =>
                                      (v?.trim().isEmpty ?? true)
                                          ? 'Ingresa tu nombre'
                                          : null,
                            ),
                            const SizedBox(height: 16),

                            const _FieldLabel('Teléfono'),
                            const SizedBox(height: 6),
                            // Phone field with country code picker
                            AppPhoneField(
                              selectedCountry: _selectedCountry,
                              numberController: _phoneNumberCtrl,
                              onPickCountry: _showCountryPicker,
                            ),
                            const SizedBox(height: 28),

                            // ── Vehicles ───────────────────────────────────
                            Row(
                              children: [
                                const Expanded(
                                  child: _SectionHeader(
                                    icon: Icons.directions_car_outlined,
                                    title: 'Mis vehículos',
                                  ),
                                ),
                                if (_vehicles.length < 4)
                                  GestureDetector(
                                    onTap: _addVehicle,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            context.isDarkMode
                                                ? context.appCardBackgroundSoft
                                                : AppColors.headerBottom
                                                    .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color:
                                              context.isDarkMode
                                                  ? context.appBorderColor
                                                  : Colors.transparent,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add_rounded,
                                            size: 15,
                                            color: context.appBrandIconColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Agregar',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: context.appBrandTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Solo ingresa el correlativo — el sistema agrega el prefijo automáticamente.',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.appTextSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 14),

                            ...List.generate(_vehicles.length, (i) {
                              return _VehicleCard(
                                entry: _vehicles[i],
                                index: i,
                                isPrimary: i == 0,
                                canRemove: _vehicles.length > 1,
                                onRemove: () => _removeVehicle(i),
                                onChanged: () => setState(() {}),
                                buildPlate: _buildPlate,
                              );
                            }),

                            const SizedBox(height: 32),

                            MyButton(
                              text: 'Guardar y continuar',
                              onTap: _save,
                              margin: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

// ─── Shared field widgets (SignUpPage style) ──────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color:
              context.isDarkMode
                  ? context.appCardBackgroundSoft
                  : AppColors.headerBottom.withValues(alpha: 0.08),
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

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: context.appTextPrimaryColor,
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;

  const _Field({
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
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
    );
  }
}

// ─── Vehicle entry model ───────────────────────────────────────────────────────
class _VehicleEntry {
  VehicleType type;
  final TextEditingController correlativeController;

  _VehicleEntry({String initialCorrelative = ''})
    : type = VehicleType.car,
      correlativeController = TextEditingController(text: initialCorrelative);

  void dispose() => correlativeController.dispose();
}

// ─── Vehicle card ──────────────────────────────────────────────────────────────
class _VehicleCard extends StatefulWidget {
  final _VehicleEntry entry;
  final int index;
  final bool isPrimary;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final String Function(_VehicleEntry) buildPlate;

  const _VehicleCard({
    required this.entry,
    required this.index,
    required this.isPrimary,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    required this.buildPlate,
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
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
              alpha: context.isDarkMode ? 0.18 : 0.05,
            ),
            blurRadius: context.isDarkMode ? 18 : 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card header
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
                            ? context.appBrandTextColor
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
                        color: context.appBrandTextColor,
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
                        color:
                            context.isDarkMode
                                ? const Color(0xFFDC2626).withValues(alpha: 0.14)
                                : const Color(
                                  0xFFDC2626,
                                ).withValues(alpha: 0.08),
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
                    border: Border.all(color: context.appBorderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color:
                              context.isDarkMode
                                  ? const Color(0xFF213453)
                                  : AppColors.headerBottom,
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
                    color:
                        context.isDarkMode
                            ? context.appCardBackgroundSoft
                            : AppColors.headerBottom.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          context.isDarkMode
                              ? context.appBorderColor
                              : AppColors.headerBottom.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.credit_card_rounded,
                        size: 15,
                        color: context.appBrandIconColor.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Placa: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appBrandTextColor.withValues(
                            alpha: 0.78,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _platePreview,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: context.appBrandTextColor,
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
