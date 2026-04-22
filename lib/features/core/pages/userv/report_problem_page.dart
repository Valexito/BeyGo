import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_button.dart';
import 'package:mapbox_api/common/ui/components/my_text.dart';
import 'package:mapbox_api/common/ui/components/my_textfield.dart';
import 'package:mapbox_api/features/core/providers/report_provider.dart';

class ReportProblemPage extends ConsumerStatefulWidget {
  const ReportProblemPage({super.key});

  @override
  ConsumerState<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends ConsumerState<ReportProblemPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();

  String? _selectedReportType;
  bool _sending = false;

  final List<String> _reportTypes = const [
    'Usuario bloqueado',
    'No puedo reservar',
    'Problema con mi parqueo',
    'Problema con pagos',
    'Problema con reservación',
    'Otro',
  ];

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

      await submitReport(
        reportType: _selectedReportType!,
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('¡Reporte enviado!')));

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
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
                                text: 'Detalle del reporte',
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
                                        dropdownColor: context.appCardBackground,
                                        style: TextStyle(
                                          color: context.appTextPrimaryColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Tipo de reporte',
                                          hintStyle: TextStyle(
                                            color: context.appTextSecondaryColor,
                                            fontSize: 13,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.category_outlined,
                                            color: AppColors.headerBottom,
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
