import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_button.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/common/utils/components/ui/my_textfield.dart';
import 'package:mapbox_api/features/core/pages/userv/map_pick_page_become_owner.dart';
import 'package:mapbox_api/features/core/providers/firebase_providers.dart';
import 'package:mapbox_api/features/core/pages/ownerv/providers/owners_providers.dart';

class BecomeOwnerPage extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const BecomeOwnerPage({super.key, this.onBack});

  @override
  ConsumerState<BecomeOwnerPage> createState() => _BecomeOwnerPageState();
}

class _BecomeOwnerPageState extends ConsumerState<BecomeOwnerPage> {
  final _companyName = TextEditingController();
  final _parkingName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _capacity = TextEditingController();
  final _description = TextEditingController();
  final _pricePerHour = TextEditingController();
  final _nit = TextEditingController();
  final _cancellationWindow = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final List<Uint8List> _parkingImages = [];
  Uint8List? _dpiFront;
  Uint8List? _dpiBack;
  Uint8List? _patent;

  bool _accept = false;
  bool _sending = false;
  LatLng? _picked;
  TimeOfDay _openingHour = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closingHour = const TimeOfDay(hour: 18, minute: 0);

  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) {
      _email.text = user.email ?? '';
      _phone.text = '';
    }
  }

  @override
  void dispose() {
    _companyName.dispose();
    _parkingName.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _capacity.dispose();
    _description.dispose();
    _pricePerHour.dispose();
    _nit.dispose();
    _cancellationWindow.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickPage()),
    );
    if (result != null) {
      setState(() => _picked = result);
    }
  }

  Future<void> _pickParkingImages() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked.isNotEmpty) {
      const maxTotal = 10;
      final remaining = maxTotal - _parkingImages.length;
      final selected = picked.take(remaining);

      final bytesList = await Future.wait(
        selected.map((img) => img.readAsBytes()),
      );

      setState(() {
        _parkingImages.addAll(bytesList);
      });
    }
  }

  Future<void> _pickDpiFront() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() => _dpiFront = bytes);
    }
  }

  Future<void> _pickDpiBack() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() => _dpiBack = bytes);
    }
  }

  Future<void> _pickPatent() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() => _patent = bytes);
    }
  }

  void _removeParkingImage(Uint8List img) {
    setState(() => _parkingImages.remove(img));
  }

  void _removeDpiFront() {
    setState(() => _dpiFront = null);
  }

  void _removeDpiBack() {
    setState(() => _dpiBack = null);
  }

  void _removePatent() {
    setState(() => _patent = null);
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDims.radiusLg),
            ),
            content: MyText(text: msg, variant: MyTextVariant.body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  String? _requiredValidator(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label es obligatorio.';
    return null;
  }

  String? _emailValidator(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Correo obligatorio.';
    final ok = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$').hasMatch(email);
    if (!ok) return 'Correo inválido.';
    return null;
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (!_accept) {
      return _showError('Debes aceptar los términos para continuar.');
    }

    final cap = int.tryParse(_capacity.text.trim());
    if (cap == null || cap <= 0) {
      return _showError('Capacidad debe ser un número mayor a 0.');
    }

    final price = int.tryParse(_pricePerHour.text.trim());
    if (price == null || price < 0) {
      return _showError('Precio por hora inválido.');
    }

    if (_picked == null) {
      return _showError('Selecciona la ubicación del parqueo en el mapa.');
    }

    if (_parkingImages.length < 3) {
      return _showError('Sube al menos 3 fotos del parqueo.');
    }

    if (_dpiFront == null) {
      return _showError('Debes subir la foto del DPI frente.');
    }

    if (_dpiBack == null) {
      return _showError('Debes subir la foto del DPI reverso.');
    }

    if (_patent == null) {
      return _showError('Debes subir la patente de comercio.');
    }

    final cancelWindow = int.tryParse(_cancellationWindow.text.trim());
    if (cancelWindow == null || cancelWindow < 3) {
      return _showError('La ventana mínima es de 3 minutos.');
    }
    setState(() => _sending = true);

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        return _showError('Debes iniciar sesión.');
      }

      final submit = ref.read(submitProviderRequestProvider);

      await submit(
        uid: uid,
        companyName: _companyName.text.trim(),
        parkingName: _parkingName.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        nit: _nit.text.trim(), // ✅ ADD THIS
        address: _address.text.trim(),
        capacity: cap,
        description: _description.text.trim(),
        lat: _picked!.latitude,
        lng: _picked!.longitude,
        parkingImages: _parkingImages,
        dpiFront: _dpiFront!,
        dpiBack: _dpiBack!,
        patent: _patent!,
        price: price,

        // ✅ THESE 3 WERE MISSING
        freeCancellationMinutes: cancelWindow,
        openTime: _openingHour.format(context),
        closeTime: _closingHour.format(context),
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const MyText(
                text: 'Solicitud enviada',
                variant: MyTextVariant.title,
              ),
              content: const MyText(
                text:
                    'Tu solicitud fue enviada correctamente. El equipo la revisará antes de aprobarte como proveedor.',
                variant: MyTextVariant.body,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('Aceptar'),
                ),
              ],
            ),
      );
    } catch (e) {
      _showError('No se pudo enviar la solicitud. $e');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Widget _buildSinglePreview({
    required Uint8List? file,
    required VoidCallback onPick,
    required VoidCallback onRemove,
    required String emptyLabel,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (file == null)
          GestureDetector(
            onTap: onPick,
            child: Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD7E0EA)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.headerBottom, size: 28),
                  const SizedBox(height: 8),
                  MyText(
                    text: emptyLabel,
                    variant: MyTextVariant.bodyMuted,
                    textAlign: TextAlign.center,
                    fontSize: 13,
                  ),
                ],
              ),
            ),
          )
        else
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Image.memory(file, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: InkWell(
                  onTap: onRemove,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildParkingImagesGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final img in _parkingImages)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: Image.memory(img, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                right: 4,
                top: 4,
                child: InkWell(
                  onTap: () => _removeParkingImage(img),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        GestureDetector(
          onTap: _pickParkingImages,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD7E0EA)),
            ),
            child: const Icon(
              Icons.add_a_photo_outlined,
              color: AppColors.headerBottom,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFD8F3EE),
      body: SafeArea(
        top: false,
        child: SizedBox(
          height: screen.height,
          child: Stack(
            children: [
              Container(
                height: screen.height * 0.42,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.headerTop, AppColors.headerBottom],
                  ),
                ),
              ),
              Positioned(
                top: 40,
                left: -20,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                top: -10,
                right: -10,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
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
              Positioned(
                top: screen.height * 0.12,
                left: 28,
                right: 28,
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.22),
                          width: 1.4,
                        ),
                      ),
                      child: const Icon(
                        Icons.store_mall_directory_rounded,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 34),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: MyText(
                              text: 'Solicitud de proveedor',
                              variant: MyTextVariant.title,
                              customColor: AppColors.headerBottom,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const MyText(
                            text:
                                'Completa tu información, sube tus documentos y envía tu solicitud para revisión.',
                            variant: MyTextVariant.subtitle,
                            fontSize: 13,
                          ),
                          const SizedBox(height: 24),

                          MyTextField(
                            controller: _companyName,
                            hintText: 'Nombre de empresa o encargado',
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.business_outlined,
                            margin: EdgeInsets.zero,
                            validator:
                                (v) => _requiredValidator(v, 'Company name'),
                          ),
                          const SizedBox(height: 14),

                          MyTextField(
                            controller: _parkingName,
                            hintText: 'Nombre del parqueo',
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.local_parking_outlined,
                            margin: EdgeInsets.zero,
                            validator:
                                (v) => _requiredValidator(v, 'Parking name'),
                          ),
                          const SizedBox(height: 14),

                          MyTextField(
                            controller: _email,
                            hintText: 'Correo electrónico',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.mail_outline,
                            margin: EdgeInsets.zero,
                            validator: _emailValidator,
                          ),
                          const SizedBox(height: 14),

                          MyTextField(
                            controller: _phone,
                            hintText: 'Número de teléfono',
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.phone_outlined,
                            margin: EdgeInsets.zero,
                            validator: (v) => _requiredValidator(v, 'Teléfono'),
                          ),
                          const SizedBox(height: 14),

                          MyTextField(
                            controller: _address,
                            hintText: 'Dirección',
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.place_outlined,
                            margin: EdgeInsets.zero,
                            validator:
                                (v) => _requiredValidator(v, 'Dirección'),
                          ),
                          const SizedBox(height: 14),

                          MyTextField(
                            controller: _capacity,
                            hintText: 'Capacidad de espacios',
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.format_list_numbered_outlined,
                            margin: EdgeInsets.zero,
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n <= 0)
                                return 'Capacidad inválida.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          MyTextField(
                            controller: _pricePerHour,
                            hintText: 'Precio por hora (Q)',
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            prefixIcon: Icons.attach_money_outlined,
                            margin: EdgeInsets.zero,
                            validator: (v) {
                              final n = int.tryParse((v ?? '').trim());
                              if (n == null || n < 0) return 'Precio inválido.';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          MyTextField(
                            controller: _description,
                            hintText: 'Descripción breve',
                            textInputAction: TextInputAction.done,
                            prefixIcon: Icons.notes_outlined,
                            margin: EdgeInsets.zero,
                          ),

                          const SizedBox(height: 14),

                          const MyText(
                            text: 'NIT',
                            variant: MyTextVariant.normalBold,
                            fontSize: 13,
                          ),
                          const SizedBox(height: 6),
                          MyTextField(
                            controller: _nit,
                            hintText: 'Ej. 112615953',
                            prefixIcon: Icons.badge_outlined,
                            margin: EdgeInsets.zero,
                            validator: (v) => _requiredValidator(v, 'NIT'),
                          ),

                          const SizedBox(height: 14),

                          Row(
                            children: [
                              const MyText(
                                text: 'Tiempo de cancelación gratis (min)',
                                variant: MyTextVariant.normalBold,
                                fontSize: 13,
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (_) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          title: const MyText(
                                            text: '¿Cómo funciona?',
                                            variant: MyTextVariant.title,
                                          ),
                                          content: const MyText(
                                            text:
                                                'Este tiempo define cuántos minutos tiene el usuario para cancelar una reservación sin costo. '
                                                'Si cancela después de este tiempo, se le aplicarán cargos automáticamente.',
                                            variant: MyTextVariant.body,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              child: const Text('Entendido'),
                                            ),
                                          ],
                                        ),
                                  );
                                },
                                child: const Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: AppColors.headerBottom,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value:
                                _cancellationWindow.text.isEmpty
                                    ? null
                                    : int.tryParse(_cancellationWindow.text),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.timer_outlined),
                              hintText: 'Selecciona (mín. 3 min)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD7E0EA),
                                ),
                              ),
                            ),
                            items:
                                List.generate(10, (i) => i + 1).map((min) {
                                  return DropdownMenuItem(
                                    value: min,
                                    child: Text('$min minutos'),
                                  );
                                }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _cancellationWindow.text = value.toString();
                              }
                            },
                            validator: (value) {
                              if (value == null || value < 3) {
                                return 'Mínimo 3 minutos';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 18),

                          const MyText(
                            text: 'Horario de atención',
                            variant: MyTextVariant.normalBold,
                            fontSize: 13,
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _openingHour,
                                    );
                                    if (picked != null) {
                                      setState(() => _openingHour = picked);
                                    }
                                  },
                                  icon: const Icon(Icons.access_time),
                                  label: Text(
                                    'Desde: ${_openingHour.format(context)}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _closingHour,
                                    );
                                    if (picked != null) {
                                      setState(() => _closingHour = picked);
                                    }
                                  },
                                  icon: const Icon(Icons.access_time_filled),
                                  label: Text(
                                    'Hasta: ${_closingHour.format(context)}',
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),
                          const MyText(
                            text: 'Ubicación del parqueo',
                            variant: MyTextVariant.normal,
                            fontSize: 13,
                          ),
                          const SizedBox(height: 8),

                          OutlinedButton.icon(
                            onPressed: _sending ? null : _pickOnMap,
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Elegir en el mapa'),
                          ),
                          const SizedBox(height: 8),

                          MyText(
                            text:
                                _picked == null
                                    ? 'Sin ubicación seleccionada'
                                    : 'Lat: ${_picked!.latitude.toStringAsFixed(6)}, Lng: ${_picked!.longitude.toStringAsFixed(6)}',
                            variant: MyTextVariant.bodyMuted,
                            fontSize: 13,
                          ),

                          const SizedBox(height: 22),
                          const MyText(
                            text: 'Fotos del parqueo (mínimo 3)',
                            variant: MyTextVariant.normal,
                            fontSize: 13,
                          ),
                          const SizedBox(height: 10),
                          _buildParkingImagesGrid(),

                          const SizedBox(height: 22),
                          const MyText(
                            text: 'DPI frente',
                            variant: MyTextVariant.normal,
                            fontSize: 13,
                          ),
                          const SizedBox(height: 8),
                          _buildSinglePreview(
                            file: _dpiFront,
                            onPick: _pickDpiFront,
                            onRemove: _removeDpiFront,
                            emptyLabel: 'Subir DPI frente',
                            icon: Icons.badge_outlined,
                          ),

                          const SizedBox(height: 18),
                          const MyText(
                            text: 'DPI reverso',
                            variant: MyTextVariant.normal,
                            fontSize: 13,
                          ),
                          const SizedBox(height: 8),
                          _buildSinglePreview(
                            file: _dpiBack,
                            onPick: _pickDpiBack,
                            onRemove: _removeDpiBack,
                            emptyLabel: 'Subir DPI reverso',
                            icon: Icons.credit_card_outlined,
                          ),

                          const SizedBox(height: 18),
                          const MyText(
                            text: 'Patente de comercio',
                            variant: MyTextVariant.normal,
                            fontSize: 13,
                          ),
                          const SizedBox(height: 8),
                          _buildSinglePreview(
                            file: _patent,
                            onPick: _pickPatent,
                            onRemove: _removePatent,
                            emptyLabel: 'Subir patente',
                            icon: Icons.description_outlined,
                          ),

                          const SizedBox(height: 20),
                          Row(
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
                              ),
                              const Expanded(
                                child: MyText(
                                  text:
                                      'Acepto enviar mis datos para revisión del equipo.',
                                  variant: MyTextVariant.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),
                          MyButton(
                            text: _sending ? 'Enviando...' : 'Enviar solicitud',
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
            ],
          ),
        ),
      ),
    );
  }
}
