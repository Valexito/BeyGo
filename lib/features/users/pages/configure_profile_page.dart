import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_button.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/common/utils/components/ui/my_textfield.dart';
import 'package:mapbox_api/features/users/providers/user_providers.dart';

class ConfigureProfilePage extends ConsumerStatefulWidget {
  const ConfigureProfilePage({super.key});

  @override
  ConsumerState<ConfigureProfilePage> createState() =>
      _ConfigureProfilePageState();
}

class _ConfigureProfilePageState extends ConsumerState<ConfigureProfilePage> {
  final _auth = FirebaseAuth.instance;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  String _gender = 'male';
  bool _saving = false;
  bool _loadingProfile = true;

  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final u = _auth.currentUser;
      if (u == null) {
        if (mounted) {
          setState(() => _loadingProfile = false);
        }
        return;
      }

      _emailCtrl.text = u.email ?? '';

      final doc =
          await FirebaseFirestore.instance.collection('users').doc(u.uid).get();

      final data = doc.data() ?? <String, dynamic>{};

      _nameCtrl.text =
          (data['name'] as String?)?.trim().isNotEmpty == true
              ? (data['name'] as String).trim()
              : (u.displayName ?? '');

      _mobileCtrl.text = (data['phone'] as String?) ?? '';
      _dobCtrl.text = (data['dob'] as String?) ?? '';
      _gender =
          ((data['gender'] as String?) ?? 'male').trim().isNotEmpty
              ? ((data['gender'] as String?) ?? 'male')
              : 'male';
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() => _loadingProfile = false);
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
      helpText: 'Selecciona tu fecha de nacimiento',
    );

    if (selected != null) {
      _dobCtrl.text =
          '${selected.day.toString().padLeft(2, '0')}/${selected.month.toString().padLeft(2, '0')}/${selected.year}';
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<String?> _uploadImage(String uid) async {
    if (_imageFile == null) return null;

    final refStorage = FirebaseStorage.instance.ref().child(
      'users/$uid/profile.jpg',
    );

    await refStorage.putFile(_imageFile!);
    return refStorage.getDownloadURL();
  }

  Future<void> _save() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _saving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No hay sesión activa.');
      }

      String? uploadedPhotoUrl;

      if (_imageFile != null) {
        uploadedPhotoUrl = await _uploadImage(user.uid);
        await user.updatePhotoURL(uploadedPhotoUrl);
      }

      if (_nameCtrl.text.trim().isNotEmpty) {
        await user.updateDisplayName(_nameCtrl.text.trim());
      }

      await ref.read(updateBasicProfileProvider)(
        name: _nameCtrl.text.trim(),
        phone: _mobileCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        dob: _dobCtrl.text.trim(),
        gender: _gender,
        photoUrl: uploadedPhotoUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final screen = MediaQuery.of(context).size;

    final currentPhotoUrl =
        _imageFile == null ? (user?.photoURL ?? '').trim() : '';

    final ImageProvider<Object>? avatarProvider =
        _imageFile != null
            ? FileImage(_imageFile!)
            : (currentPhotoUrl.isNotEmpty
                ? NetworkImage(currentPhotoUrl)
                : null);

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
                top: 56,
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
              Positioned(
                top: screen.height * 0.15,
                left: 28,
                right: 28,
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
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
                                        Icons.person,
                                        size: 56,
                                        color: AppColors.headerBottom,
                                      ),
                                    ),
                          ),
                        ),
                        Positioned(
                          bottom: -6,
                          right: -6,
                          child: Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                color: AppColors.headerBottom,
                                size: 20,
                              ),
                              onPressed: _saving ? null : _pickImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: screen.height * 0.28,
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
                          : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(28, 28, 28, 34),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: MyText(
                                      text: 'Editar perfil',
                                      variant: MyTextVariant.title,
                                      customColor: AppColors.headerBottom,
                                      fontSize: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const MyText(
                                    text:
                                        'Actualiza tu información personal y mantén tu perfil al día.',
                                    variant: MyTextVariant.subtitle,
                                    fontSize: 13,
                                  ),
                                  const SizedBox(height: 22),
                                  MyTextField(
                                    controller: _nameCtrl,
                                    hintText: 'Nombre completo',
                                    prefixIcon: Icons.person_outline,
                                    margin: EdgeInsets.zero,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Escribe tu nombre';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  MyTextField(
                                    controller: _emailCtrl,
                                    hintText: 'Correo electrónico',
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: Icons.mail_outline,
                                    readOnly: true,
                                    margin: EdgeInsets.zero,
                                  ),
                                  const SizedBox(height: 14),
                                  MyTextField(
                                    controller: _mobileCtrl,
                                    hintText: 'Número de teléfono',
                                    keyboardType: TextInputType.phone,
                                    prefixIcon: Icons.phone_outlined,
                                    margin: EdgeInsets.zero,
                                  ),
                                  const SizedBox(height: 14),
                                  MyTextField(
                                    controller: _dobCtrl,
                                    hintText: 'DD / MM / YYYY',
                                    readOnly: true,
                                    onTap: _pickDob,
                                    prefixIcon: Icons.calendar_today_outlined,
                                    margin: EdgeInsets.zero,
                                  ),
                                  const SizedBox(height: 16),
                                  const MyText(
                                    text: 'Sexo',
                                    variant: MyTextVariant.normal,
                                    fontSize: 13,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _GenderChip(
                                          label: 'Masculino',
                                          selected: _gender == 'male',
                                          onTap:
                                              () => setState(
                                                () => _gender = 'male',
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _GenderChip(
                                          label: 'Femenino',
                                          selected: _gender == 'female',
                                          onTap:
                                              () => setState(
                                                () => _gender = 'female',
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  MyButton(
                                    onTap: _saving ? null : _save,
                                    text: _saving ? 'Guardando...' : 'Guardar',
                                    loading: _saving,
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

class _GenderChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.headerBottom : const Color(0xFFEFF2F6);
    final fg = selected ? Colors.white : const Color(0xFF1B3A57);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: fg, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
