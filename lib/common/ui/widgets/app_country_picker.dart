import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beygo/common/common.dart';

class AppCountryCode {
  final String flag;
  final String name;
  final String code; // e.g. "+502"

  const AppCountryCode({
    required this.flag,
    required this.name,
    required this.code,
  });

  static ({AppCountryCode country, String number}) parse(
    String fullPhone, {
    AppCountryCode? fallback,
  }) {
    final fb = fallback ?? AppCountryCodes.defaultCode;
    for (final c in AppCountryCodes.all) {
      if (fullPhone.startsWith(c.code)) {
        final number = fullPhone.substring(c.code.length).trim();
        return (country: c, number: number);
      }
    }
    return (country: fb, number: fullPhone.trim());
  }

  String combine(String number) => '$code ${number.trim()}';

  @override
  bool operator ==(Object other) =>
      other is AppCountryCode && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

class AppCountryCodes {
  AppCountryCodes._();

  static const defaultCode = AppCountryCode(
    flag: '🇬🇹',
    name: 'Guatemala',
    code: '+502',
  );

  static const all = <AppCountryCode>[
    AppCountryCode(flag: '🇬🇹', name: 'Guatemala', code: '+502'),
    AppCountryCode(flag: '🇲🇽', name: 'México', code: '+52'),
    AppCountryCode(flag: '🇺🇸', name: 'Estados Unidos', code: '+1'),
    AppCountryCode(flag: '🇸🇻', name: 'El Salvador', code: '+503'),
    AppCountryCode(flag: '🇭🇳', name: 'Honduras', code: '+504'),
    AppCountryCode(flag: '🇳🇮', name: 'Nicaragua', code: '+505'),
    AppCountryCode(flag: '🇨🇷', name: 'Costa Rica', code: '+506'),
    AppCountryCode(flag: '🇵🇦', name: 'Panamá', code: '+507'),
    AppCountryCode(flag: '🇨🇴', name: 'Colombia', code: '+57'),
    AppCountryCode(flag: '🇪🇸', name: 'España', code: '+34'),
    AppCountryCode(flag: '🇦🇷', name: 'Argentina', code: '+54'),
    AppCountryCode(flag: '🇨🇱', name: 'Chile', code: '+56'),
    AppCountryCode(flag: '🇵🇪', name: 'Perú', code: '+51'),
    AppCountryCode(flag: '🇻🇪', name: 'Venezuela', code: '+58'),
    AppCountryCode(flag: '🇧🇷', name: 'Brasil', code: '+55'),
    AppCountryCode(flag: '🇪🇨', name: 'Ecuador', code: '+593'),
    AppCountryCode(flag: '🇧🇴', name: 'Bolivia', code: '+591'),
    AppCountryCode(flag: '🇺🇾', name: 'Uruguay', code: '+598'),
    AppCountryCode(flag: '🇵🇾', name: 'Paraguay', code: '+595'),
    AppCountryCode(flag: '🇩🇴', name: 'Rep. Dominicana', code: '+1809'),
  ];
}

// ─── Picker (bottom sheet) ────────────────────────────────────────────────────
class AppCountryPicker {
  AppCountryPicker._();

  /// Shows the country picker and returns the selected country (or null if dismissed).
  static Future<AppCountryCode?> show(
    BuildContext context, {
    AppCountryCode? selected,
  }) {
    return showModalBottomSheet<AppCountryCode>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CountryPickerSheet(selected: selected),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final AppCountryCode? selected;
  const _CountryPickerSheet({this.selected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<AppCountryCode> _filtered = AppCountryCodes.all;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filter);
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered =
          q.isEmpty
              ? AppCountryCodes.all
              : AppCountryCodes.all
                  .where(
                    (c) =>
                        c.name.toLowerCase().contains(q) || c.code.contains(q),
                  )
                  .toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.45,
      maxChildSize: 0.85,
      expand: false,
      builder:
          (_, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: context.appCardBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Handle + header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.appBorderColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Código de país',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Search
                      TextField(
                        controller: _searchCtrl,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.appTextPrimaryColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar país...',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: context.appTextSecondaryColor,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: context.appBrandIconColor,
                          ),
                          filled: true,
                          fillColor: context.appInputBackground,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(color: context.appBorderColor, height: 1),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child:
                      _filtered.isEmpty
                          ? Center(
                            child: Text(
                              'Sin resultados',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.appTextSecondaryColor,
                              ),
                            ),
                          )
                          : ListView.builder(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final c = _filtered[i];
                              final isSelected = c == widget.selected;
                              return InkWell(
                                onTap: () => Navigator.pop(context, c),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? AppColors.headerBottom.withValues(
                                              alpha: 0.07,
                                            )
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isSelected
                                              ? AppColors.headerBottom
                                                  .withValues(alpha: 0.25)
                                              : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        c.flag,
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          c.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                isSelected
                                                    ? context.appBrandTextColor
                                                    : context.appTextPrimaryColor,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        c.code,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        color:
                                            isSelected
                                                ? context.appBrandTextColor
                                                : context.appTextSecondaryColor,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.check_rounded,
                                        color: context.appBrandIconColor,
                                        size: 18,
                                      ),
                                    ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
    );
  }
}

class AppPhoneField extends StatelessWidget {
  final AppCountryCode selectedCountry;
  final TextEditingController numberController;
  final VoidCallback onPickCountry;
  final String hint;
  final bool readOnly;

  const AppPhoneField({
    super.key,
    required this.selectedCountry,
    required this.numberController,
    required this.onPickCountry,
    this.hint = '5555 1234',
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appInputBackgroundActive,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appBorderColor),
      ),
      child: Row(
        children: [
          // Country picker button
          GestureDetector(
            onTap: readOnly ? null : onPickCountry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: context.appBorderColor),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selectedCountry.flag,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selectedCountry.code,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color:
                          readOnly
                              ? context.appTextSecondaryColor
                              : context.appBrandTextColor,
                    ),
                  ),
                  if (!readOnly) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: context.appBrandIconColor.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Number input
          Expanded(
            child: TextField(
              controller: numberController,
              readOnly: readOnly,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9\s\-]')),
              ],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    readOnly
                        ? context.appTextSecondaryColor
                        : context.appTextPrimaryColor,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: context.appTextSecondaryColor,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
