import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/components/ui/app_styles.dart';
import 'package:mapbox_api/common/components/ui/my_button.dart';
import 'package:mapbox_api/common/components/ui/my_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mapbox_api/features/users/providers/delete_account_provider.dart';

class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final controller = TextEditingController();

  bool isValid = false;
  bool isLoading = false;

  void _onChanged(String value) {
    setState(() {
      isValid = value.trim().toLowerCase() == 'eliminar';
    });
  }

  Future<void> _delete() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => isLoading = true);

    try {
      await ref.read(deleteAccountProvider)(uid: uid);

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
    } catch (e) {
      setState(() => isLoading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppDims.radiusXl),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.10),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.headerTop, AppColors.headerBottom],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.headerBottom.withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(height: 16),

              const MyText(
                text: 'Eliminar cuenta',
                variant: MyTextVariant.title,
                customColor: AppColors.headerBottom,
              ),

              const SizedBox(height: 10),

              const MyText(
                text:
                    'Esta acción eliminará permanentemente tu cuenta y toda la información asociada.\n\n'
                    'Esto incluye:\n'
                    '• Reservaciones activas e historial\n'
                    '• Favoritos guardados\n'
                    '• Configuración de la cuenta\n'
                    '• Datos relacionados a tu perfil\n\n'
                    'Esta acción es irreversible.\n\n'
                    'Escribe "ELIMINAR" para confirmar.',
                variant: MyTextVariant.subtitle,
                textAlign: TextAlign.left,
                fontSize: 13,
                customColor: AppColors.textSecondary,
              ),

              const SizedBox(height: 18),

              Theme(
                data: Theme.of(context).copyWith(
                  textSelectionTheme: const TextSelectionThemeData(
                    cursorColor: AppColors.headerBottom,
                    selectionColor: AppColors.primarySoft,
                  ),
                ),
                child: TextField(
                  controller: controller,
                  onChanged: _onChanged,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ELIMINAR',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: const Color(0xFFF4F8FC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed:
                            isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.headerBottom.withOpacity(0.35),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDims.radiusLg,
                            ),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        child: const MyText(
                          text: 'Cancelar',
                          variant: MyTextVariant.normalBold,
                          customColor: AppColors.headerBottom,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child:
                          isValid
                              ? MyButton(
                                onTap: isLoading ? null : _delete,
                                text: 'Eliminar',
                                loading: isLoading,
                                margin: EdgeInsets.zero,
                                color: Colors.red,
                                fontSize: 14,
                              )
                              : OutlinedButton(
                                onPressed: null,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Colors.red,
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppDims.radiusLg,
                                    ),
                                  ),
                                ),
                                child: const MyText(
                                  text: 'Eliminar',
                                  variant: MyTextVariant.normalBold,
                                  customColor: Colors.red,
                                  fontSize: 14,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
