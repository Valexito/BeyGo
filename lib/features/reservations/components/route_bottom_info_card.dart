import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:beygo/common/common.dart';
class RouteBottomInfoCard extends StatelessWidget {
  final String parkingName;
  final String distance;
  final String duration;
  final int? spaceNumber;
  final String reservationStatus;
  final LatLng destination;
  final VoidCallback onGoToReservations;

  const RouteBottomInfoCard({
    super.key,
    required this.parkingName,
    required this.distance,
    required this.duration,
    required this.destination,
    required this.onGoToReservations,
    this.spaceNumber,
    this.reservationStatus = 'Reserva activa',
  });

  Future<void> _openNavigationChooser(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(26),
            topRight: Radius.circular(26),
          ),
          child: Material(
            color: context.appCardBackground,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: context.appBorderColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Text(
                    'Abrir navegación',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const MyText(
                    text: 'Selecciona la app con la que deseas navegar.',
                    variant: MyTextVariant.bodyMuted,
                    fontSize: 12,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  _NavAppTile(
                    icon: Icons.map_rounded,
                    title: 'Google Maps',
                    subtitle: 'Abrir ruta en Google Maps',
                    onTap: () async {
                      Navigator.pop(context);
                      await _openGoogleMaps();
                    },
                  ),
                  const SizedBox(height: 10),
                  _NavAppTile(
                    icon: Icons.navigation_rounded,
                    title: 'Waze',
                    subtitle: 'Abrir ruta en Waze',
                    onTap: () async {
                      Navigator.pop(context);
                      await _openWaze();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openGoogleMaps() async {
    final lat = destination.latitude;
    final lng = destination.longitude;

    final googleMapsApp = Uri.parse(
      'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving',
    );
    final googleMapsWeb = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    if (await canLaunchUrl(googleMapsApp)) {
      await launchUrl(
        googleMapsApp,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      return;
    }

    await launchUrl(
      googleMapsWeb,
      mode: LaunchMode.externalNonBrowserApplication,
    );
  }

  Future<void> _openWaze() async {
    final lat = destination.latitude;
    final lng = destination.longitude;

    final wazeUri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
    final wazeWeb = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');

    if (await canLaunchUrl(wazeUri)) {
      await launchUrl(
        wazeUri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      return;
    }

    await launchUrl(
      wazeWeb,
      mode: LaunchMode.externalNonBrowserApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'RouteBottomInfoCard -> reservationStatus: $reservationStatus | spaceNumber: $spaceNumber',
    );
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(26),
        topRight: Radius.circular(26),
      ),
      child: Material(
        color: context.appCardBackground,
        elevation: 18,
        shadowColor: Colors.black.withValues(
          alpha: context.isDarkMode ? 0.22 : 0.10,
        ),
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: context.appBorderColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.appIconCircleColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_car_rounded,
                        color:
                            context.isDarkMode
                                ? Colors.white
                                : AppColors.headerBottom,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(
                            text: parkingName,
                            variant: MyTextVariant.bodyBold,
                            fontSize: 16,
                          ),
                          const SizedBox(height: 4),

                          // 👇 NEW LINE (gris)
                          MyText(
                            text: 'Espacio seleccionado ${spaceNumber ?? '-'}',
                            variant: MyTextVariant.bodyMuted,
                            fontSize: 12,
                          ),

                          const SizedBox(height: 2),
                        ],
                      ),
                    ),
                    (() {
                      final status = reservationStatus.toLowerCase().trim();

                      final isPending = status == 'pending';
                      final isActive = status == 'active';
                      final isCancelRequested =
                          status == 'cancellation_requested';
                      final isRejected =
                          status == 'rejected' || status == 'cancelled';

                      final chipColor =
                          isPending
                              ? const Color(0xFFFFF3E0)
                              : isActive
                              ? const Color(0xFFE8F5E9)
                              : isCancelRequested
                              ? const Color(0xFFFFEBEE)
                              : isRejected
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFE3F2FD);

                      final textColor =
                          isPending
                              ? const Color(0xFFF59E0B)
                              : isActive
                              ? const Color(0xFF16A34A)
                              : isCancelRequested
                              ? const Color(0xFFDC2626)
                              : isRejected
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF1976D2);

                      final label =
                          isPending
                              ? 'PENDIENTE'
                              : isActive
                              ? 'ACTIVO'
                              : isCancelRequested
                              ? 'CANCELACIÓN'
                              : isRejected
                              ? 'RECHAZADO'
                              : status.toUpperCase();

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: chipColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    })(),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: _MiniDetailTile(
                        icon: Icons.route_rounded,
                        title: 'Distancia',
                        value: distance,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MiniDetailTile(
                        icon: Icons.access_time_rounded,
                        title: 'Tiempo',
                        value: duration,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: MyButton(
                        text: 'Navegar',
                        onTap: () => _openNavigationChooser(context),
                        margin: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: AppDims.buttonHeight,
                        child: OutlinedButton(
                          onPressed: onGoToReservations,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppDims.radiusLg,
                              ),
                            ),
                            side: BorderSide(
                              color: AppColors.headerBottom.withValues(
                                alpha: 0.55,
                              ),
                              width: 1.3,
                            ),
                            backgroundColor: context.appCardBackground,
                          ),
                          child: const MyText(
                            text: 'Reservaciones',
                            variant: MyTextVariant.normalBold,
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
      ),
    );
  }
}

class _MiniDetailTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _MiniDetailTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: context.appCardBackgroundSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.appIconCircleColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 17,
              color:
                  context.isDarkMode ? Colors.white : AppColors.headerBottom,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  text: title,
                  variant: MyTextVariant.bodyMuted,
                  fontSize: 11,
                ),
                const SizedBox(height: 2),
                MyText(
                  text: value,
                  variant: MyTextVariant.bodyBold,
                  fontSize: 13,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavAppTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavAppTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appCardBackgroundSoft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.appBorderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.appIconCircleColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color:
                      context.isDarkMode
                          ? Colors.white
                          : AppColors.headerBottom,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: title,
                      variant: MyTextVariant.bodyBold,
                      fontSize: 14,
                    ),
                    const SizedBox(height: 2),
                    MyText(
                      text: subtitle,
                      variant: MyTextVariant.bodyMuted,
                      fontSize: 12,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.appTextSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
