import 'package:flutter/material.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_text.dart';
import 'package:mapbox_api/common/ui/components/navy_header.dart';

class LegalInformationPage extends StatelessWidget {
  const LegalInformationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <({String title, String body})>[
      (
        title: 'Términos de servicio',
        body:
            'Al usar la app aceptas los términos y condiciones. El uso indebido, fraude o violación de las políticas puede resultar en la suspensión de la cuenta.',
      ),
      (
        title: 'Privacidad',
        body:
            'Protegemos tu información y solo la usamos para proveer las funciones del servicio. Puedes solicitar la eliminación de tu cuenta y datos desde tu perfil.',
      ),
      (
        title: 'Responsabilidad',
        body:
            'La app conecta a usuarios con parqueos registrados. Cada proveedor es responsable por su establecimiento. Reporta cualquier problema desde “Reportar un problema”.',
      ),
      (
        title: 'Contacto',
        body: '¿Dudas legales? Escríbenos a parking.dev.app@gmail.com',
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Stack(
                  children: [
                    Container(
                      height: 300,
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
                      top: 38,
                      left: -20,
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
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
                          color: Colors.white.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Stack(
                          children: [
                            const NavyHeader(
                              height: 235,
                              roundedBottom: false,
                              children: [
                                Icon(
                                  Icons.gavel_rounded,
                                  color: Colors.white,
                                  size: 52,
                                ),
                                SizedBox(height: 12),
                                MyText(
                                  text: 'Información legal',
                                  variant: MyTextVariant.title,
                                  customColor: Colors.white,
                                  textAlign: TextAlign.center,
                                  fontSize: 28,
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
                        Transform.translate(
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
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                28,
                                16,
                                28,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...List.generate(items.length, (i) {
                                    final it = items[i];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Material(
                                        color: Colors.white,
                                        elevation: 1.5,
                                        shadowColor: Colors.black12,
                                        borderRadius: BorderRadius.circular(18),
                                        child: ExpansionTile(
                                          tilePadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 10,
                                              ),
                                          childrenPadding:
                                              const EdgeInsets.fromLTRB(
                                                16,
                                                0,
                                                16,
                                                16,
                                              ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          collapsedShape:
                                              RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                          iconColor: AppColors.headerBottom,
                                          collapsedIconColor:
                                              AppColors.headerBottom,
                                          title: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFEAF3FF),
                                                  shape: BoxShape.circle,
                                                ),
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.gavel_rounded,
                                                  size: 18,
                                                  color: AppColors.headerBottom,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: MyText(
                                                  text: it.title,
                                                  variant:
                                                      MyTextVariant.normalBold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 48,
                                              ),
                                              child: MyText(
                                                text: it.body,
                                                variant: MyTextVariant.body,
                                                customColor:
                                                    AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 24),
                                ],
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
          },
        ),
      ),
    );
  }
}
