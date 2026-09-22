// lib/common/ui/widgets/formatted_date_range_picker.dart
//
// Reemplazo de `showDateRangePicker` para la entrada manual de fechas.
//
// El diálogo nativo de Flutter (`showDateRangePicker` en modo de teclado)
// no inserta las barras "/" mientras el usuario escribe, por lo que el
// campo muestra "08092026" en vez de "08/09/2026" (el propio hint). Como
// ese comportamiento vive dentro del widget interno de Flutter y no expone
// forma de inyectar un `TextInputFormatter`, aquí se construye un diálogo
// propio — visualmente equivalente (encabezado azul marino + "Periodo") —
// que formatea la fecha en vivo y conserva un acceso directo al calendario
// nativo por si el usuario prefiere seleccionar visualmente.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beygo/common/ui/components/app_styles.dart';

/// Inserta automáticamente "/" mientras el usuario escribe dd/mm/aaaa.
class _SlashDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digitsOnly.length > 8
        ? digitsOnly.substring(0, 8)
        : digitsOnly;

    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      buffer.write(limited[i]);
      final isEndOfDay = i == 1;
      final isEndOfMonth = i == 3;
      if ((isEndOfDay || isEndOfMonth) && i != limited.length - 1) {
        buffer.write('/');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatDdMmYyyy(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

/// Intenta interpretar un texto "dd/mm/aaaa" como [DateTime]. Devuelve
/// `null` si el formato o el valor no son válidos.
DateTime? _tryParseDdMmYyyy(String text) {
  final parts = text.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  if (year < 1000) return null;
  if (month < 1 || month > 12) return null;
  final daysInMonth = DateTime(year, month + 1, 0).day;
  if (day < 1 || day > daysInMonth) return null;
  return DateTime(year, month, day);
}

/// Muestra un selector de rango de fechas con entrada manual formateada
/// (dd/mm/aaaa) en vivo. Incluye un acceso directo al calendario nativo
/// de Flutter (icono de calendario) para quienes prefieran seleccionar
/// las fechas tocando en vez de escribiendo.
Future<DateTimeRange?> showFormattedDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange? initialDateRange,
  Color accentColor = AppColors.headerBottom,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (ctx) => _FormattedDateRangeDialog(
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialDateRange,
      accentColor: accentColor,
    ),
  );
}

class _FormattedDateRangeDialog extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTimeRange? initialDateRange;
  final Color accentColor;

  const _FormattedDateRangeDialog({
    required this.firstDate,
    required this.lastDate,
    required this.initialDateRange,
    required this.accentColor,
  });

  @override
  State<_FormattedDateRangeDialog> createState() =>
      _FormattedDateRangeDialogState();
}

class _FormattedDateRangeDialogState
    extends State<_FormattedDateRangeDialog> {
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _startCtrl = TextEditingController(
      text: widget.initialDateRange != null
          ? _formatDdMmYyyy(widget.initialDateRange!.start)
          : '',
    );
    _endCtrl = TextEditingController(
      text: widget.initialDateRange != null
          ? _formatDdMmYyyy(widget.initialDateRange!.end)
          : '',
    );
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _openNativeCalendar() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      initialDateRange: widget.initialDateRange,
      builder: (ctx, child) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: (isDark
                    ? const ColorScheme.dark()
                    : const ColorScheme.light())
                .copyWith(
                  primary: widget.accentColor,
                  onPrimary: Colors.white,
                  surface: isDark ? const Color(0xFF111827) : Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      Navigator.of(context).pop(picked);
    }
  }

  void _submit() {
    final start = _tryParseDdMmYyyy(_startCtrl.text.trim());
    final end = _tryParseDdMmYyyy(_endCtrl.text.trim());

    if (start == null || end == null) {
      setState(() => _errorText = 'Ingresa ambas fechas en formato dd/mm/aaaa.');
      return;
    }
    if (end.isBefore(start)) {
      setState(() => _errorText = 'La fecha final no puede ser anterior a la de inicio.');
      return;
    }
    final firstDay = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      widget.firstDate.day,
    );
    final lastDay = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
      widget.lastDate.day,
    );
    if (start.isBefore(firstDay) || end.isAfter(lastDay)) {
      setState(() => _errorText = 'Selecciona fechas entre '
          '${_formatDdMmYyyy(firstDay)} y ${_formatDdMmYyyy(lastDay)}.');
      return;
    }

    Navigator.of(context).pop(DateTimeRange(start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
            decoration: BoxDecoration(
              color: widget.accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'SELECCIONAR PERIODO',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Periodo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _openNativeCalendar,
                  icon: const Icon(Icons.calendar_month, color: Colors.white),
                  tooltip: 'Elegir en calendario',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _DateField(label: 'Fecha de inicio', controller: _startCtrl, accentColor: widget.accentColor)),
                const SizedBox(width: 12),
                Expanded(child: _DateField(label: 'Fecha de fin', controller: _endCtrl, accentColor: widget.accentColor)),
              ],
            ),
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Text(
                _errorText!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12.5),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCELAR'),
                ),
                TextButton(
                  onPressed: _submit,
                  child: const Text('ACEPTAR'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color accentColor;

  const _DateField({
    required this.label,
    required this.controller,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: context.appTextSecondaryColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [_SlashDateInputFormatter()],
          decoration: InputDecoration(
            hintText: 'dd/mm/aaaa',
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accentColor.withValues(alpha: 0.35)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accentColor, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}
