import 'package:flutter/material.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_text.dart';

class LegalInformationPage extends StatelessWidget {
  const LegalInformationPage({super.key, this.initialSection});

  final String? initialSection;

  @override
  Widget build(BuildContext context) {
    final items = <({String title, String body})>[
      (
        title: 'Términos de servicio',
        body:
            'Al usar Parking App aceptas utilizar la plataforma de forma responsable. La app facilita la conexión entre usuarios y proveedores de parqueo, pero cada proveedor administra su disponibilidad, horarios, tarifas y condiciones del establecimiento. El uso indebido, fraude, datos falsos, abuso de reservaciones o incumplimiento de políticas puede resultar en restricciones, strikes o suspensión de la cuenta.',
      ),
      (
        title: 'Privacidad',
        body:
            'Usamos tu información para crear tu cuenta, gestionar reservaciones, mostrar parqueos cercanos, enviar notificaciones importantes y dar soporte. Esto puede incluir nombre, correo, teléfono, ubicación aproximada cuando la autorizas, datos del vehículo, historial de reservaciones y reportes enviados. Puedes solicitar revisión o eliminación de datos desde tu perfil o soporte.',
      ),
      (
        title: 'Política de cookies',
        body:
            'La app móvil no usa cookies tradicionales de navegador para rastreo web. Puede utilizar almacenamiento local, preferencias del dispositivo y servicios de Firebase para mantener sesión, guardar configuración, mejorar estabilidad, entregar notificaciones y recordar preferencias como tema o alertas.',
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
      backgroundColor: context.appPageBackground,
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
                    Column(
                      children: [
                        Stack(
                          children: [
                            const SizedBox(height: 235, width: double.infinity),
                            const Positioned.fill(
                              child: SafeArea(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 42),
                                  child: Column(
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
                                    ],
                                  ),
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
                        Transform.translate(
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
                                    final initiallyExpanded =
                                        initialSection != null &&
                                        it.title.toLowerCase() ==
                                            initialSection!.toLowerCase();
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Material(
                                        color: context.appCardBackground,
                                        elevation: context.isDarkMode ? 0 : 1.5,
                                        shadowColor: Colors.black.withValues(
                                          alpha:
                                              context.isDarkMode ? 0.18 : 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        child: ExpansionTile(
                                          initiallyExpanded: initiallyExpanded,
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
                                                decoration: BoxDecoration(
                                                  color:
                                                      context
                                                          .appIconCircleColor,
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
                                                    context
                                                        .appTextSecondaryColor,
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
