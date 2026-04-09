// lib/features/users/pages/complete_profile_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_button.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/common/utils/components/ui/my_textfield.dart';
import 'package:mapbox_api/features/users/providers/user_providers.dart';

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

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final plateController = TextEditingController();

  bool isSaving = false;
  String selectedVehicleType = 'car';

  final List<Map<String, String>> vehicleTypes = const [
    {'value': 'car', 'label': 'Carro'},
    {'value': 'motorcycle', 'label': 'Moto'},
    {'value': 'other', 'label': 'Otro'},
  ];

  @override
  void initState() {
    super.initState();

    final u = widget.user;

    if ((u.displayName ?? '').trim().isNotEmpty) {
      nameController.text = u.displayName!.trim();
    }

    phoneController.text =
        (u.phoneNumber ?? '').trim().isNotEmpty
            ? u.phoneNumber!.trim()
            : '+502 ';
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    plateController.dispose();
    super.dispose();
  }

  String _platePrefixForVehicleType(String type) {
    switch (type) {
      case 'motorcycle':
        return 'M';
      case 'other':
        return 'C';
      case 'car':
      default:
        return 'P';
    }
  }

  String _normalizePlateBody(String raw) {
    var text = raw.toUpperCase().trim();
    text = text.replaceAll(RegExp(r'[\s\-]+'), '');
    text = text.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return text;
  }

  String _buildFullPlate() {
    final prefix = _platePrefixForVehicleType(selectedVehicleType);
    final body = _normalizePlateBody(plateController.text);

    var cleanedBody = body;
    if (cleanedBody.startsWith(prefix)) {
      cleanedBody = cleanedBody.substring(1);
    }

    return '$prefix$cleanedBody';
  }

  bool _isValidPlateBody(String value) {
    final body = _normalizePlateBody(value);
    if (body.isEmpty) return false;

    var cleanedBody = body;
    final prefix = _platePrefixForVehicleType(selectedVehicleType);

    if (cleanedBody.startsWith(prefix)) {
      cleanedBody = cleanedBody.substring(1);
    }

    return cleanedBody.length >= 4;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Debes verificar tu correo electrónico antes de continuar.',
            ),
          ),
        );
        return;
      }
    }

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final fullPlate = _buildFullPlate();
    final plateType = _platePrefixForVehicleType(selectedVehicleType);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresar tu nombre completo')),
      );
      return;
    }

    if (phone.isEmpty || phone == '+502') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresar tu número de teléfono')),
      );
      return;
    }

    if (!_isValidPlateBody(plateController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresar una placa de vehículo válida')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      await ref.read(saveProfileProvider)(
        name: name,
        phone: phone,
        role: 'user',
        vehiclePlate: fullPlate,
        vehicleType: selectedVehicleType,
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await ref.read(userDocRefProvider(currentUser.uid)).set({
          'plateType': plateType,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Widget _buildVehicleDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDims.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.18),
            blurRadius: 18,
            spreadRadius: 0.5,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: selectedVehicleType,
        borderRadius: BorderRadius.circular(AppDims.radiusLg),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AppColors.headerBottom,
        ),
        decoration: InputDecoration(
          hintText: 'Selecciona tu tipo de vehículo',
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(
            Icons.directions_car_outlined,
            color: AppColors.headerBottom,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDims.radiusLg),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDims.radiusLg),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDims.radiusLg),
            borderSide: BorderSide(
              color: AppColors.headerBottom.withOpacity(0.45),
              width: 1,
            ),
          ),
        ),
        items:
            vehicleTypes.map((item) {
              return DropdownMenuItem<String>(
                value: item['value'],
                child: Text(
                  item['label']!,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              );
            }).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => selectedVehicleType = value);
        },
      ),
    );
  }

  Widget _buildPlateField() {
    final prefix = _platePrefixForVehicleType(selectedVehicleType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MyText(
          text: 'Placa del vehículo',
          variant: MyTextVariant.bodyMuted,
          fontSize: 13,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              height: 58,
              width: 80,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppDims.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.headerBottom.withOpacity(0.18),
                    blurRadius: 18,
                    spreadRadius: 0.5,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: prefix,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.headerBottom,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'P', child: Text('P')),
                    DropdownMenuItem(value: 'M', child: Text('M')),
                    DropdownMenuItem(value: 'C', child: Text('C')),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MyTextField(
                controller: plateController,
                hintText: 'Ej. 123ABC',
                prefixIcon: Icons.pin_outlined,
                margin: EdgeInsets.zero,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final previewPlate = _buildFullPlate();

    return WillPopScope(
      onWillPop: () async {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return false;
        }

        Navigator.of(context).pushReplacementNamed('/auth');
        return false;
      },
      child: Scaffold(
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
                  decoration: BoxDecoration(
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
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushReplacementNamed('/auth');
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
                          Icons.badge_outlined,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: MyText(
                              text: 'Completar perfil',
                              variant: MyTextVariant.title,
                              customColor: AppColors.headerBottom,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const MyText(
                            text:
                                'Agrega tus datos para continuar y habilitar todas las funciones de tu cuenta.',
                            variant: MyTextVariant.subtitle,
                            fontSize: 13,
                          ),
                          const SizedBox(height: 22),
                          const MyText(
                            text: 'Nombre completo',
                            variant: MyTextVariant.bodyMuted,
                            fontSize: 13,
                          ),
                          const SizedBox(height: 6),
                          MyTextField(
                            controller: nameController,
                            hintText: 'Nombre completo',
                            prefixIcon: Icons.person_outline,
                            margin: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 14),
                          const MyText(
                            text: 'Número de teléfono',
                            variant: MyTextVariant.bodyMuted,
                            fontSize: 13,
                          ),
                          const SizedBox(height: 6),
                          MyTextField(
                            controller: phoneController,
                            hintText: 'Número de teléfono',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_outlined,
                            margin: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 14),
                          const MyText(
                            text: 'Tipo de vehículo',
                            variant: MyTextVariant.bodyMuted,
                            fontSize: 13,
                          ),
                          const SizedBox(height: 6),
                          _buildVehicleDropdown(),
                          const SizedBox(height: 14),
                          _buildPlateField(),
                          const SizedBox(height: 10),
                          if (_normalizePlateBody(
                            plateController.text,
                          ).isNotEmpty)
                            Center(
                              child: MyText(
                                text: previewPlate,
                                variant: MyTextVariant.title,
                                fontSize: 16,
                                customColor: AppColors.headerBottom,
                              ),
                            ),
                          const SizedBox(height: 28),
                          isSaving
                              ? const Center(child: CircularProgressIndicator())
                              : MyButton(
                                text: 'Guardar y continuar',
                                onTap: _save,
                                margin: EdgeInsets.zero,
                              ),
                        ],
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
}
