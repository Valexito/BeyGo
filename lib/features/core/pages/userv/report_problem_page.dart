import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_button.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/common/utils/components/ui/my_textfield.dart';
import 'package:mapbox_api/common/utils/components/ui/navy_header.dart';
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
      backgroundColor: const Color(0xFFD8F3EE),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                // HEADER
                Stack(
                  children: [
                    NavyHeader(
                      height: 250,
                      roundedBottom: false,
                      children: const [
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
                        SizedBox(height: 6),
                      ],
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
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.only(
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
                              const MyText(
                                text: 'Detalle del reporte',
                                variant: MyTextVariant.title,
                                customColor: AppColors.headerBottom,
                                fontSize: 22,
                              ),

                              const SizedBox(height: 8),

                              const MyText(
                                text:
                                    'Incluye la mayor cantidad de información posible para revisar el caso más rápido.',
                                variant: MyTextVariant.subtitle,
                                fontSize: 13,
                              ),

                              const SizedBox(height: 24),

                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x12000000),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: const Color(0xFFE8EEF5),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      DropdownButtonFormField<String>(
                                        value: _selectedReportType,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          hintText: 'Tipo de reporte',
                                          prefixIcon: const Icon(
                                            Icons.category_outlined,
                                            color: AppColors.headerBottom,
                                          ),
                                          filled: true,
                                          fillColor: AppColors.formFieldBg,
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
                                                    child: Text(e),
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
