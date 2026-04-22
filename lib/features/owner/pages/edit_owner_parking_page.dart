import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_button.dart';
import 'package:mapbox_api/features/owner/providers/owner_management_providers.dart';
import 'package:mapbox_api/features/owner/widgets/app_header.dart';
import 'package:mapbox_api/features/reservations/providers/parking_service_provider.dart';

class EditOwnerParkingPage extends ConsumerStatefulWidget {
  const EditOwnerParkingPage({super.key});

  @override
  ConsumerState<EditOwnerParkingPage> createState() =>
      _EditOwnerParkingPageState();
}

class _EditOwnerParkingPageState extends ConsumerState<EditOwnerParkingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _spacesCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _picker = ImagePicker();

  TimeOfDay _open = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _close = const TimeOfDay(hour: 18, minute: 0);
  final List<XFile> _newImages = [];
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _spacesCtrl.dispose();
    _priceCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parkingAsync = ref.watch(ownerParkingDocumentProvider);

    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: parkingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No pudimos cargar los detalles del parqueo.\n$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.appTextSecondaryColor),
                ),
              ),
            ),
        data: (parking) {
          if (parking == null) {
            return Column(
              children: [
                const AppHeader(
                  title: 'Editar parqueo',
                  subtitle: 'Gestiona la información publicada',
                  showBack: true,
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aún no tienes un parqueo publicado para editar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.appTextSecondaryColor),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          _hydrateForm(parking);

          return Column(
            children: [
              const AppHeader(
                title: 'Editar parqueo',
                subtitle: 'Horarios, fotos y datos públicos',
                showBack: true,
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    children: [
                      _SectionCard(
                        title: 'Información principal',
                        children: [
                          _InputField(
                            controller: _nameCtrl,
                            label: 'Nombre del parqueo',
                            hint: 'Ej: Parqueo Central Xela',
                            icon: Icons.local_parking_rounded,
                            validator:
                                (value) =>
                                    (value == null || value.trim().isEmpty)
                                        ? 'Ingresa el nombre del parqueo'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          _InputField(
                            controller: _addressCtrl,
                            label: 'Dirección',
                            hint: 'Dirección visible para los usuarios',
                            icon: Icons.place_outlined,
                            validator:
                                (value) =>
                                    (value == null || value.trim().isEmpty)
                                        ? 'Ingresa una dirección'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _InputField(
                                  controller: _phoneCtrl,
                                  label: 'Teléfono',
                                  hint: '5555 1234',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  validator:
                                      (value) =>
                                          (value == null ||
                                                  value.trim().isEmpty)
                                              ? 'Ingresa un teléfono'
                                              : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _InputField(
                                  controller: _priceCtrl,
                                  label: 'Precio por hora',
                                  hint: '15',
                                  icon: Icons.payments_outlined,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (value) {
                                    final parsed = int.tryParse(value ?? '');
                                    if (parsed == null || parsed < 0) {
                                      return 'Inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _InputField(
                            controller: _spacesCtrl,
                            label: 'Cantidad de espacios',
                            hint: '24',
                            icon: Icons.grid_view_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              final parsed = int.tryParse(value ?? '');
                              if (parsed == null || parsed <= 0) {
                                return 'Ingresa una capacidad válida';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _InputField(
                            controller: _descriptionCtrl,
                            label: 'Descripción',
                            hint: 'Cuéntale al usuario qué hace especial tu parqueo',
                            icon: Icons.description_outlined,
                            maxLines: 4,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: 'Horario publicado',
                        subtitle:
                            'Este horario también se usa para validar solicitudes de eliminación.',
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _TimeButton(
                                  label: 'Abre',
                                  value: _formatTime(_open),
                                  onTap: () => _pickTime(isOpen: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _TimeButton(
                                  label: 'Cierra',
                                  value: _formatTime(_close),
                                  onTap: () => _pickTime(isOpen: false),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: 'Fotos del parqueo',
                        subtitle:
                            'Puedes sumar nuevas fotos sin perder las actuales.',
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final photo in parking.photos)
                                _NetworkImageChip(url: photo),
                              for (final image in _newImages)
                                _LocalImageChip(
                                  path: image.path,
                                  onRemove:
                                      () => setState(
                                        () => _newImages.remove(image),
                                      ),
                                ),
                              _AddImageChip(onTap: _pickImages),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      MyButton(
                        text: _saving ? 'Guardando...' : 'Guardar cambios',
                        loading: _saving,
                        onTap: _saving ? null : () => _save(parking),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _hydrateForm(OwnerParkingDocument parking) {
    if (_initialized) return;
    _initialized = true;

    _nameCtrl.text = parking.name;
    _phoneCtrl.text = parking.phone;
    _addressCtrl.text = parking.address;
    _spacesCtrl.text = parking.spaces > 0 ? '${parking.spaces}' : '';
    _priceCtrl.text =
        parking.pricePerHour > 0 ? '${parking.pricePerHour}' : '';
    _descriptionCtrl.text = parking.description;

    final hours = parking.businessHours;
    _open = _parseTime(hours['open']) ?? _open;
    _close = _parseTime(hours['close']) ?? _close;
  }

  Future<void> _pickTime({required bool isOpen}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen ? _open : _close,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isOpen) {
        _open = picked;
      } else {
        _close = picked;
      }
    });
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 82);
    if (images.isEmpty || !mounted) return;
    setState(() => _newImages.addAll(images));
  }

  Future<void> _save(OwnerParkingDocument parking) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await ref.read(parkingServiceProvider).updateParkingDetails(
        ownerID: parking.data['ownerID'] as String? ?? '',
        parkingId: parking.id,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        spaces: int.parse(_spacesCtrl.text.trim()),
        description: _descriptionCtrl.text.trim(),
        pricePerHour: int.tryParse(_priceCtrl.text.trim()) ?? 0,
        openTime: _formatTime(_open),
        closeTime: _formatTime(_close),
        newImages: _newImages,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parqueo actualizado correctamente.')),
      );
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

  String _formatTime(TimeOfDay value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.appBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDarkMode ? 0.18 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: context.appTextSecondaryColor,
                fontSize: 12,
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
    this.keyboardType,
    this.maxLines = 1,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.appTextPrimaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          style: TextStyle(color: context.appTextPrimaryColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.appTextSecondaryColor),
            prefixIcon: Icon(icon, color: AppColors.headerBottom, size: 18),
            filled: true,
            fillColor: context.appInputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.appBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.appBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.headerBottom),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.appInputBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorderColor),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              color: AppColors.headerBottom,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: context.appTextSecondaryColor,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: context.appTextPrimaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.appTextSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddImageChip extends StatelessWidget {
  const _AddImageChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: context.appInputBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.appBorderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined),
            const SizedBox(height: 6),
            Text(
              'Agregar',
              style: TextStyle(
                color: context.appTextPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkImageChip extends StatelessWidget {
  const _NetworkImageChip({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 92,
        height: 92,
        child: Image.network(url, fit: BoxFit.cover),
      ),
    );
  }
}

class _LocalImageChip extends StatelessWidget {
  const _LocalImageChip({
    required this.path,
    required this.onRemove,
  });

  final String path;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 92,
            height: 92,
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => Container(
                    color: context.appInputBackground,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_outlined),
                  ),
            ),
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
