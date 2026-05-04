import 'package:flutter/material.dart';
import 'package:beygo/common/common.dart';
class FrequentQuestionsPage extends StatelessWidget {
  const FrequentQuestionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <({String q, String a})>[
      (
        q: '¿Cómo creo una reserva?',
        a:
            'Desde el mapa, selecciona un parqueo disponible y sigue los pasos. '
            'Verás el precio, horario y confirmación antes de finalizar.',
      ),
      (
        q: '¿Puedo cancelar una reserva?',
        a: 'Sí. Puedes cancelarla desde Mis reservaciones siempre que no haya iniciado. Algunos parqueos ofrecen cancelación gratuita por un tiempo definido por el proveedor de parqueo (mínimo 5 minutos). Si cancelas fuera de ese tiempo, puede aplicarse una penalización en tu cuenta.',
      ),
      (
        q: '¿Qué hago si se bloquea mi cuenta?',
        a: 'Si ya no puedes reservar porque sobrepasaste el límite de penalizaciones, debes ir a la opción de Reportar un problema, llenar el formulario y enviarlo. Nuestro equipo revisará tu caso y te dará seguimiento.',
      ),
      (
        q: '¿Qué métodos de inicio de sesión hay?',
        a: 'Puedes usar Google o correo/contraseña.',
      ),
      (
        q: '¿Cómo me hago proveedor?',
        a: 'Desde tu perfil puedes enviar una solicitud para convertirte en proveedor registrando tu parqueo. Nuestro equipo revisará tu información y te dará seguimiento. El proceso puede tardar aproximadamente 72 horas y se comunicarán contigo para continuar.',
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
                    Column(
                      children: [
                        Stack(
                          children: [
                            const SizedBox(height: 200, width: double.infinity),
                            const Positioned.fill(
                              child: SafeArea(
                                child: Column(
                                  children: [
                                    SizedBox(height: 32),
                                    Icon(
                                      Icons.help_outline_rounded,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                    SizedBox(height: 10),
                                    MyText(
                                      text: 'PREGUNTAS FRECUENTES',
                                      variant: MyTextVariant.title,
                                      textAlign: TextAlign.center,
                                      customColor: Colors.white,
                                      fontSize: 26,
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
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Material(
                                        color: context.appCardBackground,
                                        elevation: context.isDarkMode ? 0 : 1.5,
                                        shadowColor: Colors.black.withValues(
                                          alpha: context.isDarkMode ? 0.18 : 0.12,
                                        ),
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
                                          iconColor: context.appBrandIconColor,
                                          collapsedIconColor:
                                              context.appBrandIconColor,
                                          title: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: context.appIconCircleColor,
                                                  shape: BoxShape.circle,
                                                ),
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons.help_outline_rounded,
                                                  size: 18,
                                                  color: context.appBrandIconColor,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: MyText(
                                                  text: it.q,
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
                                                text: it.a,
                                                variant: MyTextVariant.body,
                                                customColor: context.appTextSecondaryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
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
