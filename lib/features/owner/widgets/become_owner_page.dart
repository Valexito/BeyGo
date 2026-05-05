// lib/features/core/pages/userv/become_owner_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/owner/owner.dart';
import 'package:beygo/features/core/core.dart';
class BecomeOwnerPage extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const BecomeOwnerPage({super.key, this.onBack});

  @override
  ConsumerState<BecomeOwnerPage> createState() => _BecomeOwnerPageState();
}

class _BecomeOwnerPageState extends ConsumerState<BecomeOwnerPage>
    with SingleTickerProviderStateMixin {
  // Controllers
  final _companyName = TextEditingController();
  final _parkingName = TextEditingController();
  final _email = TextEditingController();
  final _phoneNumber = TextEditingController();
  final _address = TextEditingController();
  final _capacity = TextEditingController();
  final _description = TextEditingController();
  final _pricePerHour = TextEditingController();
  final _nit = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // State
  final List<Uint8List> _parkingImages = [];
  Uint8List? _dpiFront;
  Uint8List? _dpiBack;
  Uint8List? _patent;

  bool _accept = false;
  bool _sending = false;
  LatLng? _picked;
  TimeOfDay _openingHour = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closingHour = const TimeOfDay(hour: 18, minute: 0);
  int _cancellationMinutes = 5;

  AppCountryCode _selectedCountry = AppCountryCodes.defaultCode;

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
    _loadExistingContactData();
  }

  @override
  void dispose() {
    _companyName.dispose();
    _parkingName.dispose();
    _email.dispose();
    _phoneNumber.dispose();
    _address.dispose();
    _capacity.dispose();
    _description.dispose();
    _pricePerHour.dispose();
    _nit.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Country picker ──────────────────────────────────────────────────────────
  Future<void> _showCountryPicker() async {
    final picked = await AppCountryPicker.show(
      context,
      selected: _selectedCountry,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedCountry = picked);
  }

  Future<void> _loadExistingContactData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      _email.text = user.email ?? '';

      await user.reload();
      final refreshedUser = _auth.currentUser ?? user;
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(refreshedUser.uid)
              .get();
      final data = doc.data() ?? {};
      final firestorePhone = (data['phone'] as String? ?? '').trim();
      final authPhone =
          (refreshedUser.phoneNumber ?? user.phoneNumber ?? '').trim();
      final resolvedPhone =
          firestorePhone.isNotEmpty ? firestorePhone : authPhone;

      if (!mounted || resolvedPhone.isEmpty) return;

      final parsed = AppCountryCode.parse(
        resolvedPhone,
        fallback: AppCountryCodes.defaultCode,
      );

      setState(() {
        _selectedCountry = parsed.country;
        _phoneNumber.text = parsed.number;
      });
    } catch (_) {}
  }

  // ── Image pickers ───────────────────────────────────────────────────────────
  Future<void> _pickParkingImages() async {
    final remaining = 3 - _parkingImages.length;
    if (remaining <= 0) {
      _showSnack('Solo puedes subir hasta 3 fotos del parqueo.');
      return;
    }

    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked.isNotEmpty) {
      final bytes = await Future.wait(
        picked.take(remaining).map((i) => i.readAsBytes()),
      );
      setState(() => _parkingImages.addAll(bytes));
    }
  }

  Future<void> _pickSingle(void Function(Uint8List) onPicked) async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() => onPicked(bytes));
    }
  }

  // ── Map picker ──────────────────────────────────────────────────────────────
  Future<void> _pickOnMap() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickPage(initialPosition: _picked),
      ),
    );
    if (result != null) setState(() => _picked = result);
  }

  // ── Submit ──────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (!_accept) {
      _showSnack('Debes aceptar los términos para continuar.');
      return;
    }
    if (_picked == null) {
      _showSnack('Selecciona la ubicación del parqueo en el mapa.');
      return;
    }
    if (_parkingImages.length < 3) {
      _showSnack('Sube al menos 3 fotos del parqueo.');
      return;
    }
    if (_dpiFront == null) {
      _showSnack('Debes subir la foto del DPI frente.');
      return;
    }
    if (_dpiBack == null) {
      _showSnack('Debes subir la foto del DPI reverso.');
      return;
    }
    if (_patent == null) {
      _showSnack('Debes subir la patente de comercio.');
      return;
    }

    setState(() => _sending = true);

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        _showSnack('Debes iniciar sesión.');
        return;
      }

      final submit = ref.read(submitProviderRequestProvider);
      final fullPhone = '${_selectedCountry.code} ${_phoneNumber.text.trim()}';

      final requestNumber = await submit(
        uid: uid,
        companyName: _companyName.text.trim(),
        parkingName: _parkingName.text.trim(),
        email: _email.text.trim(),
        phone: fullPhone,
        nit: _nit.text.trim(),
        address: _address.text.trim(),
        capacity: int.parse(_capacity.text.trim()),
        description: _description.text.trim(),
        lat: _picked!.latitude,
        lng: _picked!.longitude,
        parkingImages: _parkingImages,
        dpiFront: _dpiFront!,
        dpiBack: _dpiBack!,
        patent: _patent!,
        price: int.parse(_pricePerHour.text.trim()),
        freeCancellationMinutes: _cancellationMinutes,
        openTime: _openingHour.format(context),
        closeTime: _closingHour.format(context),
      );

      if (!mounted) return;

      await AppDialog.show(
        context,
        icon: Icons.check_circle_outline_rounded,
        title: '¡Solicitud enviada!',
        message:
            'Gracias por tu solicitud.\n\n'
            'Número de solicitud: $requestNumber\n\n'
            'Te enviaremos un correo de confirmación y soporte se comunicará contigo por correo o teléfono para continuar el proceso.',
        showCancel: false,
        confirmText: 'Entendido',
      );

      if (!mounted) return;
      Navigator.pop(context);
    } on ProviderRequestSubmitException catch (e) {
      if (!mounted) return;
      _showSnack(e.userMessage);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      if (msg.contains('network') ||
          msg.contains('socket') ||
          msg.contains('timeout')) {
        AppNoConnection.snack(context, onRetry: _submit);
      } else {
        _showSnack('No se pudo enviar la solicitud: $e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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
      ),
    );
  }

  // ── Validators ──────────────────────────────────────────────────────────────
  String? _required(String? v, String label) =>
      (v?.trim().isEmpty ?? true) ? '$label es obligatorio.' : null;

  String? _emailValidator(String? v) {
    final email = (v ?? '').trim();
    if (email.isEmpty) return 'Correo obligatorio.';
    if (!RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$').hasMatch(email)) {
      return 'Correo inválido.';
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final headerGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors:
          context.isDarkMode
              ? const [Color(0xFF111827), Color(0xFF0F172A), Color(0xFF0B1220)]
              : const [AppColors.headerTop, AppColors.headerBottom],
    );

    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: SafeArea(
        top: false,
        child: SizedBox(
          height: screen.height,
          child: Stack(
            children: [
              // Gradient background
              Container(
                height: screen.height * 0.38,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: headerGradient,
                ),
              ),

              // Blobs
              Positioned(
                top: 40,
                left: -20,
                child: _Blob(size: 90, opacity: 0.12),
              ),
              Positioned(
                top: -10,
                right: -10,
                child: _Blob(size: 120, opacity: 0.10),
              ),

              // Back button
              Positioned(
                top: 15,
                left: 18,
                child: SafeArea(
                  child: TextButton.icon(
                    onPressed:
                        _sending
                            ? null
                            : () {
                              if (widget.onBack != null) {
                                widget.onBack!();
                              } else {
                                Navigator.pop(context);
                              }
                            },
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

              // Hero icon
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
                    child: const Icon(
                      Icons.store_mall_directory_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // ── Content sheet ──
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Solicitud de proveedor',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: context.appBrandTextColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Completa tu información, sube tus documentos y envía tu solicitud para revisión.',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.appTextSecondaryColor,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── Sección 1: Empresa ──
                            _SectionHeader(
                              icon: Icons.business_outlined,
                              title: 'Datos de la empresa',
                            ),
                            const SizedBox(height: 14),

                            _FieldLabel(
                              label: 'Empresa o encargado',
                              hint: 'Nombre legal o nombre del propietario',
                            ),
                            const SizedBox(height: 6),
                            _FormField(
                              controller: _companyName,
                              hint: 'Ej: Parqueos del Centro S.A.',
                              icon: Icons.business_outlined,
                              validator: (v) => _required(v, 'Empresa'),
                            ),

                            const SizedBox(height: 14),
                            _FieldLabel(
                              label: 'Nombre del parqueo',
                              hint: 'Como aparecerá en la app',
                            ),
                            const SizedBox(height: 6),
                            _FormField(
                              controller: _parkingName,
                              hint: 'Ej: Parqueo Central Xela',
                              icon: Icons.local_parking_outlined,
                              validator:
                                  (v) => _required(v, 'Nombre del parqueo'),
                            ),

                            const SizedBox(height: 14),
                            _FieldLabel(
                              label: 'NIT',
                              hint: 'Número de identificación tributaria',
                            ),
                            const SizedBox(height: 6),
                            _FormField(
                              controller: _nit,
                              hint: 'Ej: 112615953',
                              icon: Icons.badge_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) => _required(v, 'NIT'),
                            ),

                            const SizedBox(height: 28),

                            // ── Sección 2: Contacto ──
                            _SectionHeader(
                              icon: Icons.contact_phone_outlined,
                              title: 'Información de contacto',
                            ),
                            const SizedBox(height: 14),

                            _FieldLabel(
                              label: 'Correo electrónico',
                              hint: 'Para recibir notificaciones',
                            ),
                            const SizedBox(height: 6),
                            _FormField(
                              controller: _email,
                              hint: 'ejemplo@correo.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: _emailValidator,
                            ),

                            const SizedBox(height: 14),
                            _FieldLabel(
                              label: 'Teléfono de contacto',
                              hint: 'Número con código de país',
                            ),
                            const SizedBox(height: 6),
                            AppPhoneField(
                              numberController: _phoneNumber,
                              selectedCountry: _selectedCountry,
                              onPickCountry: _showCountryPicker,
                            ),

                            const SizedBox(height: 28),

                            // ── Sección 3: Parqueo ──
                            _SectionHeader(
                              icon: Icons.local_parking_outlined,
                              title: 'Detalles del parqueo',
                            ),
                            const SizedBox(height: 14),

                            _FieldLabel(
                              label: 'Dirección',
                              hint: 'Dirección exacta del parqueo',
                            ),
                            const SizedBox(height: 6),
                            _FormField(
                              controller: _address,
                              hint: 'Ej: 4a Calle 14-50 Zona 1',
                              icon: Icons.place_outlined,
                              validator: (v) => _required(v, 'Dirección'),
                            ),

                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _FieldLabel(
                                        label: 'Capacidad',
                                        hint: 'Espacios totales',
                                      ),
                                      const SizedBox(height: 6),
                                      _FormField(
                                        controller: _capacity,
                                        hint: 'Ej: 20',
                                        icon:
                                            Icons.format_list_numbered_outlined,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        validator: (v) {
                                          final n = int.tryParse(
                                            v?.trim() ?? '',
                                          );
                                          if (n == null || n <= 0)
                                            return 'Inválida';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _FieldLabel(
                                        label: 'Precio / hora (Q)',
                                        hint: 'En quetzales',
                                      ),
                                      const SizedBox(height: 6),
                                      _FormField(
                                        controller: _pricePerHour,
                                        hint: 'Ej: 10',
                                        icon: Icons.attach_money_outlined,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        validator: (v) {
                                          final n = int.tryParse(
                                            v?.trim() ?? '',
                                          );
                                          if (n == null || n < 0)
                                            return 'Inválido';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),
                            _FieldLabel(
                              label: 'Descripción breve',
                              hint: 'Características del parqueo (opcional)',
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _description,
                              maxLines: 3,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.appTextPrimaryColor,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Ej: Parqueo techado, seguridad 24h...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: context.appTextSecondaryColor,
                                ),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(bottom: 40),
                                  child: Icon(
                                    Icons.notes_outlined,
                                    size: 18,
                                    color: context.appBrandIconColor,
                                  ),
                                ),
                                filled: true,
                                fillColor: context.appInputBackgroundActive,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: context.appBorderColor,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: context.appBorderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: AppColors.headerBottom,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Sección 4: Horario ──
                            _SectionHeader(
                              icon: Icons.schedule_outlined,
                              title: 'Horario de atención',
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: _TimeButton(
                                    label: 'Apertura',
                                    time: _openingHour.format(context),
                                    icon: Icons.wb_sunny_outlined,
                                    onTap: () async {
                                      final p = await showTimePicker(
                                        context: context,
                                        initialTime: _openingHour,
                                      );
                                      if (p != null)
                                        setState(() => _openingHour = p);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _TimeButton(
                                    label: 'Cierre',
                                    time: _closingHour.format(context),
                                    icon: Icons.nights_stay_outlined,
                                    onTap: () async {
                                      final p = await showTimePicker(
                                        context: context,
                                        initialTime: _closingHour,
                                      );
                                      if (p != null)
                                        setState(() => _closingHour = p);
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Cancellation window
                            _FieldLabel(
                              label: 'Ventana de cancelación gratuita',
                              hint:
                                  'Minutos que tiene el usuario para cancelar sin costo',
                            ),
                            const SizedBox(height: 8),
                            _CancellationSelector(
                              value: _cancellationMinutes,
                              onChanged:
                                  (v) =>
                                      setState(() => _cancellationMinutes = v),
                            ),

                            const SizedBox(height: 28),

                            // ── Sección 5: Ubicación ──
                            _SectionHeader(
                              icon: Icons.map_outlined,
                              title: 'Ubicación en mapa',
                            ),
                            const SizedBox(height: 12),

                            _picked == null
                                ? _MapPickButton(onTap: _pickOnMap)
                                : _MapPickedCard(
                                  lat: _picked!.latitude,
                                  lng: _picked!.longitude,
                                  onEdit: _pickOnMap,
                                ),

                            const SizedBox(height: 28),

                            // ── Sección 6: Fotos ──
                            _SectionHeader(
                              icon: Icons.photo_library_outlined,
                              title: 'Fotos del parqueo',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Máximo 3 fotos — muestra el interior, exterior y acceso.',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.appTextSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ParkingImagesGrid(
                              images: _parkingImages,
                              onAdd: _pickParkingImages,
                              onRemove:
                                  (img) => setState(
                                    () => _parkingImages.remove(img),
                                  ),
                            ),

                            const SizedBox(height: 28),

                            // ── Sección 7: Documentos ──
                            _SectionHeader(
                              icon: Icons.description_outlined,
                              title: 'Documentos requeridos',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sube fotos claras de cada documento.',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.appTextSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 14),

                            _DocUploadCard(
                              label: 'DPI Frente',
                              icon: Icons.badge_outlined,
                              file: _dpiFront,
                              onPick: () => _pickSingle((b) => _dpiFront = b),
                              onRemove: () => setState(() => _dpiFront = null),
                            ),
                            const SizedBox(height: 10),
                            _DocUploadCard(
                              label: 'DPI Reverso',
                              icon: Icons.credit_card_outlined,
                              file: _dpiBack,
                              onPick: () => _pickSingle((b) => _dpiBack = b),
                              onRemove: () => setState(() => _dpiBack = null),
                            ),
                            const SizedBox(height: 10),
                            _DocUploadCard(
                              label: 'Patente de comercio',
                              icon: Icons.article_outlined,
                              file: _patent,
                              onPick: () => _pickSingle((b) => _patent = b),
                              onRemove: () => setState(() => _patent = null),
                            ),

                            const SizedBox(height: 28),

                            // ── Accept terms ──
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    _accept
                                        ? AppColors.headerBottom.withValues(
                                          alpha: 0.08,
                                        )
                                        : context.appCardBackground,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      _accept
                                          ? AppColors.headerBottom.withValues(
                                            alpha: 0.25,
                                          )
                                          : context.appBorderColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _accept,
                                    onChanged:
                                        _sending
                                            ? null
                                            : (v) => setState(
                                              () => _accept = v ?? false,
                                            ),
                                    activeColor: AppColors.headerBottom,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Acepto enviar mis datos para revisión del equipo de BeyGo.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: context.appTextPrimaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            MyButton(
                              text:
                                  _sending
                                      ? 'Enviando solicitud...'
                                      : 'Enviar solicitud',
                              loading: _sending,
                              onTap: _sending ? null : _submit,
                              margin: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_sending)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.44),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: context.appCardBackground,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: context.appBorderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.20),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: AppColors.headerBottom,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Procesando tu información',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: context.appTextPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Estamos subiendo tus fotos y documentos, validando tus datos y preparando tu solicitud. Espera un momento...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: context.appTextSecondaryColor,
                              ),
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
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  Local helper widgets
// ═════════════════════════════════════════════════════════════════════════════

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

class _FieldLabel extends StatelessWidget {
  final String label;
  final String hint;
  const _FieldLabel({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.appTextPrimaryColor,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        hint,
        style: TextStyle(fontSize: 11, color: context.appTextSecondaryColor),
      ),
    ],
  );
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;

  const _FormField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
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


class _TimeButton extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final VoidCallback onTap;

  const _TimeButton({
    required this.label,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.appBorderColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.appBrandIconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.appTextSecondaryColor,
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit_outlined,
              size: 14,
              color: context.appBrandIconColor.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancellationSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _CancellationSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [3, 5, 10, 15, 20, 30];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          options.map((min) {
            final selected = value == min;
            return GestureDetector(
              onTap: () => onChanged(min),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      selected
                          ? AppColors.headerBottom
                          : context.appCardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        selected
                            ? AppColors.headerBottom
                            : AppColors.borderSoft,
                  ),
                ),
                child: Text(
                  '$min min',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        selected
                            ? Colors.white
                            : context.appTextSecondaryColor,
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

class _MapPickButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MapPickButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: context.appCardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.headerBottom.withValues(alpha: 0.25),
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.headerBottom.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.map_outlined,
                size: 18,
                color: context.appBrandIconColor,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Seleccionar en el mapa',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.appBrandTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPickedCard extends StatelessWidget {
  final double lat;
  final double lng;
  final VoidCallback onEdit;

  const _MapPickedCard({
    required this.lat,
    required this.lng,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.headerBottom.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.headerBottom.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.headerBottom.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.place_rounded,
              size: 18,
              color: context.appBrandIconColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ubicación seleccionada',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.appBrandTextColor,
                  ),
                ),
                Text(
                  '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: context.appBrandIconColor,
            ),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _ParkingImagesGrid extends StatelessWidget {
  final List<Uint8List> images;
  final VoidCallback onAdd;
  final void Function(Uint8List) onRemove;

  const _ParkingImagesGrid({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...images.map(
          (img) => Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 90,
                  height: 90,
                  child: Image.memory(img, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: () => onRemove(img),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (images.length < 3)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: context.appCardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.headerBottom.withValues(alpha: 0.25),
                  width: 1.4,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    color: context.appBrandIconColor,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${images.length}/3',
                    style: TextStyle(
                      fontSize: 10,
                      color: context.appBrandTextColor.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (images.length >= 3)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Llegaste al máximo de 3 fotos. Elimina una para agregar otra.',
              style: TextStyle(
                fontSize: 11,
                color: context.appTextSecondaryColor,
              ),
            ),
          ),
      ],
    );
  }
}

class _DocUploadCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Uint8List? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _DocUploadCard({
    required this.label,
    required this.icon,
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: context.appCardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.appBorderColor,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.headerBottom.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: context.appBrandIconColor),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimaryColor,
                    ),
                  ),
                  Text(
                    'Toca para subir foto',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appTextSecondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 120,
            width: double.infinity,
            child: Image.memory(file!, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              color: Colors.black.withValues(alpha: 0.35),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 15, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final double opacity;
  const _Blob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      shape: BoxShape.circle,
    ),
  );
}
