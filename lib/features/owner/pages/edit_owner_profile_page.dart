import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/owner/widgets/app_header.dart';
import 'package:beygo/features/users/providers/user_providers.dart';

class EditOwnerProfilePage extends ConsumerStatefulWidget {
  const EditOwnerProfilePage({super.key});

  @override
  ConsumerState<EditOwnerProfilePage> createState() =>
      _EditOwnerProfilePageState();
}

class _EditOwnerProfilePageState extends ConsumerState<EditOwnerProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _picker = ImagePicker();

  AppCountryCode _selectedCountry = AppCountryCodes.defaultCode;
  File? _imageFile;
  String _existingPhotoUrl = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final data = snap.data() ?? <String, dynamic>{};
      final phone = (data['phone'] as String?) ?? '';
      final parsed = AppCountryCode.parse(phone);

      _nameCtrl.text =
          ((data['name'] as String?) ??
                  (data['displayName'] as String?) ??
                  user.displayName ??
                  '')
              .trim();
      _emailCtrl.text = ((data['email'] as String?) ?? user.email ?? '').trim();
      _phoneCtrl.text = parsed.number;

      if (!mounted) return;
      setState(() {
        _selectedCountry = parsed.country;
        _existingPhotoUrl =
            ((data['photoURL'] as String?) ?? user.photoURL ?? '').trim();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('No pudimos cargar tu perfil: $e');
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (image == null || !mounted) return;
    setState(() => _imageFile = File(image.path));
  }

  Future<String?> _uploadImage(String uid) async {
    final image = _imageFile;
    if (image == null) return _existingPhotoUrl;

    final ref = FirebaseStorage.instance.ref('users/$uid/owner_profile.jpg');
    await ref.putFile(image);
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
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_phoneCtrl.text.trim().isEmpty) {
      _toast('Ingresa un teléfono de contacto.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _toast('Tu sesión expiró. Inicia sesión nuevamente.');
      return;
    }

    setState(() => _saving = true);
    try {
      final photoUrl = await _uploadImage(user.uid);
      await ref
          .read(updateBasicProfileProvider)
          .call(
            name: _nameCtrl.text,
            email: _emailCtrl.text,
            phone: _selectedCountry.combine(_phoneCtrl.text),
            photoUrl: photoUrl,
          );

      if (!mounted) return;
      _toast('Perfil de owner actualizado.');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _toast('No se pudo guardar el perfil: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  const AppHeader(
                    title: 'Editar perfil',
                    subtitle: 'Datos de cuenta y contacto',
                    showBack: true,
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                        children: [
                          _SectionCard(
                            title: 'Información del perfil',
                            subtitle:
                                'Estos datos se usan para gestionar tu cuenta.',
                            children: [
                              Center(
                                child: _OwnerAvatar(
                                  imageFile: _imageFile,
                                  photoUrl: _existingPhotoUrl,
                                  onTap: _pickImage,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _InputField(
                                controller: _nameCtrl,
                                label: 'Nombre visible',
                                hint: 'Ej: Alex Argueta',
                                icon: Icons.badge_outlined,
                                validator:
                                    (value) =>
                                        (value == null || value.trim().isEmpty)
                                            ? 'Ingresa tu nombre'
                                            : null,
                              ),
                              const SizedBox(height: 12),
                              _InputField(
                                controller: _emailCtrl,
                                label: 'Correo electrónico',
                                hint: 'correo@ejemplo.com',
                                icon: Icons.email_outlined,
                                readOnly: true,
                              ),
                              const SizedBox(height: 12),
                              const _FieldLabel(label: 'Teléfono de contacto'),
                              const SizedBox(height: 7),
                              AppPhoneField(
                                selectedCountry: _selectedCountry,
                                numberController: _phoneCtrl,
                                onPickCountry: _showCountryPicker,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'No incluimos vehículos aquí para mantener separado tu perfil de owner del perfil de usuario.',
                            style: TextStyle(
                              color: context.appTextSecondaryColor,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 22),
                          MyButton(
                            text: 'Guardar cambios',
                            loading: _saving,
                            onTap: _saving ? null : _save,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

class _OwnerAvatar extends StatelessWidget {
  const _OwnerAvatar({
    required this.imageFile,
    required this.photoUrl,
    required this.onTap,
  });

  final File? imageFile;
  final String photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (imageFile != null) {
      image = FileImage(imageFile!);
    } else if (photoUrl.isNotEmpty) {
      image = NetworkImage(photoUrl);
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 46,
            backgroundColor: AppColors.headerBottom.withValues(alpha: 0.12),
            backgroundImage: image,
            child:
                image == null
                    ? const Icon(
                      Icons.person_rounded,
                      color: AppColors.headerBottom,
                      size: 42,
                    )
                    : null,
          ),
          Positioned(
            right: -2,
            bottom: 2,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.headerBottom,
                shape: BoxShape.circle,
                border: Border.all(color: context.appCardBackground, width: 3),
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.18 : 0.05,
            ),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.appTextPrimaryColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(
                color: context.appTextSecondaryColor,
                fontSize: 11,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          validator: validator,
          style: TextStyle(
            color:
                readOnly
                    ? context.appTextSecondaryColor
                    : context.appTextPrimaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: context.appTextSecondaryColor,
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, color: AppColors.headerBottom, size: 18),
            filled: true,
            fillColor:
                readOnly
                    ? context.appInputBackground
                    : context.appInputBackgroundActive,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
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
              borderSide: const BorderSide(
                color: AppColors.headerBottom,
                width: 1.25,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: context.appTextPrimaryColor,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
