import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:beygo/common/common.dart';

Future<LatLng> getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    final opened = await _offerToEnableLocationService();
    if (opened) {
      // Give the user a moment to flip the toggle and return to the app.
      await Future.delayed(const Duration(seconds: 1));
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    }
    if (!serviceEnabled) {
      throw Exception(
        'El servicio de ubicación está desactivado. Activa el GPS.',
      );
    }
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    final accepted = await _ensureLocationDisclosureAccepted();
    if (!accepted) {
      throw Exception('Debes aceptar el uso de ubicación para continuar.');
    }
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Permiso de ubicación denegado.');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception(
      'Permisos de ubicación permanentemente denegados. '
      'Actívalos en Configuración → Aplicaciones.',
    );
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );

  return LatLng(position.latitude, position.longitude);
}

Future<bool> _offerToEnableLocationService() async {
  final context = AppNavigator.key.currentContext;
  if (context == null) return false;

  final wantsToEnable =
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const _LocationServiceDisabledDialog(),
      ) ??
      false;

  if (!wantsToEnable) return false;

  await Geolocator.openLocationSettings();
  return true;
}

class _LocationServiceDisabledDialog extends StatelessWidget {
  const _LocationServiceDisabledDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.appBorderColor),
          boxShadow: [
            BoxShadow(
              color: AppColors.headerBottom.withValues(
                alpha: isDark ? 0.22 : 0.16,
              ),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors:
                      isDark
                          ? const [
                            Color(0xFF111827),
                            Color(0xFF0F172A),
                            Color(0xFF0B1220),
                          ]
                          : [AppColors.headerTop, AppColors.headerBottom],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.26),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ubicación desactivada',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activa el GPS de tu dispositivo para que BeyGo pueda calcular '
                    'tu distancia y ruta reales hacia el parqueo.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextPrimaryColor,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.headerBottom.withValues(
                                  alpha: 0.28,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: context.appCardBackgroundSoft,
                            ),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.appBrandTextColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MyButton(
                          text: 'Activar ubicación',
                          height: 46,
                          onTap: () => Navigator.of(context).pop(true),
                          margin: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _ensureLocationDisclosureAccepted() async {
  final prefs = AppPreferencesService.instance;
  if (prefs.locationDisclosureAccepted) return true;

  final context = AppNavigator.key.currentContext;
  if (context == null) {
    return false;
  }

  final accepted =
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const _LocationDisclosureDialog(),
      ) ??
      false;

  if (accepted) {
    await prefs.setLocationDisclosureAccepted(true);
  }

  return accepted;
}

class _LocationDisclosureDialog extends StatelessWidget {
  const _LocationDisclosureDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.appBorderColor),
          boxShadow: [
            BoxShadow(
              color: AppColors.headerBottom.withValues(
                alpha: isDark ? 0.22 : 0.16,
              ),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors:
                      isDark
                          ? const [
                            Color(0xFF111827),
                            Color(0xFF0F172A),
                            Color(0xFF0B1220),
                          ]
                          : [AppColors.headerTop, AppColors.headerBottom],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.26),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Uso de tu ubicación',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Solo se usa dentro de la app',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BeyGo usa tu ubicación para mostrarte parqueos cercanos y trazar rutas hacia ellos.',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextPrimaryColor,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.appCardBackgroundSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.appBorderColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: context.appBrandTextColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Solo se usa mientras tienes la app abierta y nunca se comparte con terceros.',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appTextSecondaryColor,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.headerBottom.withValues(
                                  alpha: 0.28,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: context.appCardBackgroundSoft,
                            ),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.appBrandTextColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MyButton(
                          text: 'Continuar',
                          height: 46,
                          onTap: () => Navigator.of(context).pop(true),
                          margin: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
