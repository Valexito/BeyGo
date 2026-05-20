import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/core.dart';

class ReportProblemPage extends ConsumerStatefulWidget {
  const ReportProblemPage({
    super.key,
    this.initialReportType,
    this.initialSubject,
  });

  final String? initialReportType;
  final String? initialSubject;

  @override
  ConsumerState<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends ConsumerState<ReportProblemPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _picker = ImagePicker();

  String? _selectedReportType;
  bool _sending = false;
  final List<Uint8List> _screenshots = [];

  final List<String> _reportTypes = const [
    'Usuario bloqueado',
    'No puedo reservar',
    'Problema con mi parqueo',
    'Problema con pagos',
    'Problema con reservación',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialReportType != null &&
        _reportTypes.contains(widget.initialReportType)) {
      _selectedReportType = widget.initialReportType;
    }
    _subject.text = widget.initialSubject ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim());
    return ok ? null : 'Correo inválido';
  }

  Future<void> _submit() async {
    final ok = _form.currentState?.validate() ?? false;
    if (!ok) return;

    if (_selectedReportType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un tipo de reporte')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final submitReport = ref.read(submitReportProvider);

      final reportNumber = await submitReport(
        reportType: _selectedReportType!,
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        screenshots: _screenshots,
      );

      if (!mounted) return;

      await AppDialog.show(
        context,
        icon: Icons.check_circle_outline_rounded,
        title: '¡Reporte enviado!',
        message:
            'Tu reporte se registró correctamente.\n\n'
            'Número de reporte: $reportNumber\n\n'
            'También te enviaremos un correo de confirmación si hay una dirección disponible.',
        showCancel: false,
        confirmText: 'Entendido',
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _pickScreenshots() async {
    final remaining = 3 - _screenshots.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo puedes adjuntar hasta 3 capturas.')),
      );
      return;
    }

    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked.isEmpty) return;

    final bytes = await Future.wait(
      picked.take(remaining).map((image) => image.readAsBytes()),
    );

    if (!mounted) return;
    setState(() => _screenshots.addAll(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    );

    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                // HEADER
                Stack(
                  children: [
                    Container(
                      height: 250,
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
                    Positioned(
                      top: 38,
                      left: -20,
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: context.isDarkMode ? 0.04 : 0.12,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -10,
                      right: -8,
                      child: Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: context.isDarkMode ? 0.03 : 0.10,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: SafeArea(
                        child: Column(
                          children: [
                            SizedBox(height: 56),
                            Icon(
                              Icons.report_problem_outlined,
                              color: Colors.white,
                              size: 52,
                            ),
                            SizedBox(height: 12),
                            MyText(
                              text: 'Reportar un problema',
                              variant: MyTextVariant.title,
                              customColor: Colors.white,
                              fontSize: 28,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 10,
                      child: SafeArea(
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
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
                  ],
                ),

                // BODY
                Expanded(
                  child: Transform.translate(
                    offset: const Offset(0, -22),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.appSectionBackground,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(34),
                          topRight: Radius.circular(34),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              MyText(
                                text: 'Detalle del reporte / retroalimentación',
                                variant: MyTextVariant.title,
                                customColor:
                                    context.isDarkMode
                                        ? Colors.white
                                        : AppColors.headerBottom,
                                fontSize: 22,
                              ),

                              const SizedBox(height: 8),

                              MyText(
                                text:
                                    'Incluye la mayor cantidad de información posible para revisar el caso más rápido.',
                                variant: MyTextVariant.subtitle,
                                fontSize: 13,
                                customColor: context.appTextSecondaryColor,
                              ),

                              const SizedBox(height: 24),

                              Container(
                                decoration: BoxDecoration(
                                  color: context.appCardBackground,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: context.isDarkMode ? 0.22 : 0.07,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: context.appBorderColor,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      DropdownButtonFormField<String>(
                                        value: _selectedReportType,
                                        isExpanded: true,
                                        dropdownColor:
                                            context.appCardBackground,
                                        style: TextStyle(
                                          color: context.appTextPrimaryColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Tipo de reporte',
                                          hintStyle: TextStyle(
                                            color:
                                                context.appTextSecondaryColor,
                                            fontSize: 13,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.category_outlined,
                                            color: context.appBrandIconColor,
                                          ),
                                          filled: true,
                                          fillColor: context.appInputBackground,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 16,
                                              ),
                                          border: border,
                                          enabledBorder: border,
                                        ),
                                        items:
                                            _reportTypes
                                                .map(
                                                  (e) => DropdownMenuItem(
                                                    value: e,
                                                    child: Text(
                                                      e,
                                                      style: TextStyle(
                                                        color:
                                                            context
                                                                .appTextPrimaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged:
                                            (v) => setState(
                                              () => _selectedReportType = v,
                                            ),
                                        validator:
                                            (v) =>
                                                v == null
                                                    ? 'Selecciona uno'
                                                    : null,
                                      ),

                                      const SizedBox(height: 12),

                                      MyTextField(
                                        controller: _email,
                                        hintText: 'Tu correo (opcional)',
                                        prefixIcon: Icons.mail_outline_rounded,
                                        margin: EdgeInsets.zero,
                                        validator: _validateEmail,
                                      ),

                                      const SizedBox(height: 12),

                                      MyTextField(
                                        controller: _subject,
                                        hintText: 'Asunto',
                                        prefixIcon: Icons.subject_rounded,
                                        margin: EdgeInsets.zero,
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? 'Requerido'
                                                    : null,
                                      ),

                                      const SizedBox(height: 12),

                                      MyTextField(
                                        controller: _message,
                                        hintText: 'Describe el problema',
                                        prefixIcon: Icons.chat_outlined,
                                        margin: EdgeInsets.zero,
                                        maxLines: 6,
                                        validator:
                                            (v) =>
                                                v == null || v.isEmpty
                                                    ? 'Requerido'
                                                    : null,
                                      ),

                                      const SizedBox(height: 16),

                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: context.appInputBackground,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: context.appBorderColor,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            MyText(
                                              text: 'Capturas opcionales',
                                              variant: MyTextVariant.bodyBold,
                                              fontSize: 14,
                                              customColor:
                                                  context.appTextPrimaryColor,
                                            ),
                                            const SizedBox(height: 4),
                                            MyText(
                                              text:
                                                  'Puedes adjuntar hasta 3 screenshots para ayudar al equipo de soporte.',
                                              variant: MyTextVariant.bodyMuted,
                                              fontSize: 12,
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: [
                                                for (var i = 0;
                                                    i < _screenshots.length;
                                                    i++)
                                                  Stack(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                        child: Image.memory(
                                                          _screenshots[i],
                                                          width: 88,
                                                          height: 88,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                      Positioned(
                                                        top: 6,
                                                        right: 6,
                                                        child: GestureDetector(
                                                          onTap:
                                                              _sending
                                                                  ? null
                                                                  : () => setState(
                                                                    () => _screenshots
                                                                        .removeAt(i),
                                                                  ),
                                                          child: Container(
                                                            width: 24,
                                                            height: 24,
                                                            decoration:
                                                                const BoxDecoration(
                                                                  color:
                                                                      Colors.black54,
                                                                  shape:
                                                                      BoxShape.circle,
                                                                ),
                                                            child: const Icon(
                                                              Icons.close_rounded,
                                                              size: 16,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                if (_screenshots.length < 3)
                                                  InkWell(
                                                    onTap:
                                                        _sending
                                                            ? null
                                                            : _pickScreenshots,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    child: Container(
                                                      width: 88,
                                                      height: 88,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            context
                                                                .appCardBackground,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              context
                                                                  .appBorderColor,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        Icons
                                                            .add_photo_alternate_outlined,
                                                        color:
                                                            context
                                                                .appBrandIconColor,
                                                        size: 28,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      SizedBox(
                                        width: double.infinity,
                                        child: MyButton(
                                          text:
                                              _sending
                                                  ? 'Enviando...'
                                                  : 'Enviar reporte',
                                          loading: _sending,
                                          onTap: _sending ? null : _submit,
                                          margin: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
          ],
        ),
      ),
    );
  }
}
