import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:mapbox_api/common/env/env.dart';
import 'package:mapbox_api/common/components/ui/app_styles.dart';
import 'package:mapbox_api/common/components/ui/my_button.dart';
import 'package:mapbox_api/common/components/ui/my_text.dart';
import 'package:mapbox_api/features/reservations/components/route_bottom_info_card.dart';
import 'package:mapbox_api/features/reservations/providers/directions_providers.dart';
import 'package:mapbox_api/features/reservations/providers/location_providers.dart';
import 'package:mapbox_api/features/reservations/providers/map_providers.dart';

class RouteViewPage extends ConsumerWidget {
  final LatLng destination;
  final String parkingName;
  final int? spaceNumber;
  final String? reservationId;
  final String reservationState;

  const RouteViewPage({
    super.key,
    this.destination = const LatLng(0, 0),
    this.parkingName = '',
    this.spaceNumber,
    this.reservationId,
    this.reservationState = 'active',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(mapControllerProvider);
    final originAsync = ref.watch(currentLocationProvider);

    // 🔥 FIX: ensure we correctly read arguments from Navigator
    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? effectiveReservationId =
        routeArgs?['reservationId'] ?? reservationId;
    final LatLng effectiveDestination =
        routeArgs?['destination'] ?? destination;
    final String effectiveParkingName =
        routeArgs?['parkingName'] ?? parkingName;

    final int? effectiveSpaceNumber = routeArgs?['spaceNumber'] ?? spaceNumber;

    return originAsync.when(
      loading: () => const _RouteLoaderPage(),
      error:
          (e, _) => _RouteErrorPage(
            message:
                'No se pudo obtener tu ubicación.\n$e\n\nActiva GPS y permisos e inténtalo de nuevo.',
            onRetry: () => ref.refresh(currentLocationProvider),
          ),
      data: (origin) {
        print('[ROUTE VIEW] origin: ${origin.latitude}, ${origin.longitude}');
        print(
          '[ROUTE VIEW] destination: ${effectiveDestination.latitude}, ${effectiveDestination.longitude}',
        );
        print('[ROUTE VIEW] parkingName: $effectiveParkingName');
        print('[ROUTE VIEW] spaceNumber: $effectiveSpaceNumber');

        // Guard: destino inválido (0,0)
        if (effectiveDestination.latitude == 0 &&
            effectiveDestination.longitude == 0) {
          return _RouteErrorPage(
            message: 'Destino inválido (0,0). No se puede calcular la ruta.',
            onRetry: () => Navigator.pop(context),
          );
        }

        final args = (origin: origin, destination: effectiveDestination);
        final pointsAsync = ref.watch(routePointsProvider(args));
        final distanceAsync = ref.watch(routeDistanceProvider(args));
        final durationAsync = ref.watch(routeDurationProvider(args));

        return pointsAsync.when(
          loading: () => const _RouteLoaderPage(),
          error:
              (e, _) => _RouteErrorPage(
                message:
                    'No se pudo calcular la ruta.\n$e\n\nVerifica tu conexión o el token de Mapbox.',
                onRetry: () {
                  ref.invalidate(routePointsProvider(args));
                  ref.invalidate(routeDistanceProvider(args));
                  ref.invalidate(routeDurationProvider(args));
                },
              ),
          data: (points) {
            print('[ROUTE VIEW] points received: ${points.length}');
            if (points.isEmpty) {
              return _RouteErrorPage(
                message:
                    'La ruta no contiene puntos. Posible fallo en Directions API.',
                onRetry: () {
                  ref.invalidate(routePointsProvider(args));
                },
              );
            }
            final distance = distanceAsync.maybeWhen(
              data: (v) => v,
              orElse: () => '—',
            );
            final duration = durationAsync.maybeWhen(
              data: (v) => v,
              orElse: () => '—',
            );

            return Theme(
              data: Theme.of(context).copyWith(
                bottomSheetTheme: const BottomSheetThemeData(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                ),
              ),
              child: Scaffold(
                backgroundColor: AppColors.pageBg,
                body: Stack(
                  children: [
                    FlutterMap(
                      mapController: map,
                      options: MapOptions(
                        initialCenter: origin,
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://api.mapbox.com/styles/v1/{id}/tiles/512/{z}/{x}/{y}@2x?access_token={accessToken}',
                          additionalOptions: {
                            'accessToken': Env.mapboxToken,
                            'id': 'mapbox/streets-v12',
                          },
                          tileProvider: NetworkTileProvider(),
                        ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: points,
                              strokeWidth: 6,
                              color: AppColors.headerBottom,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            _mapPin(
                              origin,
                              icon: Icons.my_location_rounded,
                              iconColor: const Color(0xFF16A34A),
                            ),
                            _mapPin(
                              effectiveDestination,
                              icon: Icons.location_on_rounded,
                              iconColor: Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                    _RouteHeader(
                      parkingName: effectiveParkingName,
                      onBack: () => Navigator.pop(context),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 260,
                      child: _RecenterButton(
                        onTap: () => map.move(origin, map.camera.zoom),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 330,
                      child: Column(
                        children: [
                          _ZoomButton(
                            icon: Icons.add,
                            onTap: () {
                              map.move(map.camera.center, map.camera.zoom + 1);
                            },
                          ),
                          const SizedBox(height: 10),
                          _ZoomButton(
                            icon: Icons.remove,
                            onTap: () {
                              map.move(map.camera.center, map.camera.zoom - 1);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                bottomSheet:
                    effectiveReservationId == null
                        ? RouteBottomInfoCard(
                          parkingName: effectiveParkingName,
                          distance: distance,
                          duration: duration,
                          spaceNumber: effectiveSpaceNumber,
                          destination: effectiveDestination,
                          reservationStatus: reservationState,
                          onGoToReservations: () {
                            Navigator.of(
                              context,
                            ).pushNamed('/reservationsPage');
                          },
                        )
                        : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('reservations')
                                  .doc(effectiveReservationId)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            final data = snapshot.data?.data();
                            print('[FIRESTORE RAW DATA] $data');
                            print('[FIRESTORE state] ${data?['state']}');
                            print(
                              '[FIRESTORE providerApprovalStatus] ${data?['providerApprovalStatus']}',
                            );
                            final rawState =
                                (data?['state'] as String?) ?? 'unknown';
                            final providerApproval =
                                (data?['providerApprovalStatus'] as String?) ??
                                '';

                            // 🔥 REAL STATE FROM FIRESTORE (priority logic)
                            String state;

                            if (providerApproval == 'pending') {
                              state = 'pending';
                            } else if (rawState == 'cancellation_requested') {
                              state = 'cancellation_requested';
                            } else if (rawState == 'pending') {
                              state = 'pending';
                            } else {
                              state = rawState;
                            }

                            return RouteBottomInfoCard(
                              parkingName: effectiveParkingName,
                              distance: distance,
                              duration: duration,
                              spaceNumber: effectiveSpaceNumber,
                              destination: effectiveDestination,
                              reservationStatus: state,
                              onGoToReservations: () {
                                Navigator.of(
                                  context,
                                ).pushNamed('/reservationsPage');
                              },
                            );
                          },
                        ),
              ),
            );
          },
        );
      },
    );
  }

  Marker _mapPin(
    LatLng point, {
    required IconData icon,
    required Color iconColor,
  }) {
    return Marker(
      point: point,
      width: 46,
      height: 46,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(child: Icon(icon, color: iconColor, size: 23)),
      ),
    );
  }
}

class _RouteHeader extends StatelessWidget {
  final String parkingName;
  final VoidCallback onBack;

  const _RouteHeader({required this.parkingName, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      width: double.infinity,
      child: Stack(
        children: [
          Container(
            height: 128,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.headerTop, AppColors.headerBottom],
              ),
            ),
          ),
          Positioned(
            top: 32,
            left: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: -14,
            right: -10,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 15,
            left: 10,
            child: SafeArea(
              bottom: false,
              child: TextButton.icon(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                ),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                label: const Text('Regresar'),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: 10,
            right: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'RUTA A $parkingName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteInfoCard extends StatelessWidget {
  final String parkingName;
  final String distance;
  final String duration;

  const _RouteInfoCard({
    required this.parkingName,
    required this.distance,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.headerBottom.withOpacity(0.12),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: 'Ruta al parqueo',
              variant: MyTextVariant.title,
              customColor: AppColors.headerBottom,
              fontSize: 21,
            ),
            const SizedBox(height: 6),
            MyText(
              text: parkingName,
              variant: MyTextVariant.bodyMuted,
              fontSize: 13,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniInfoTile(
                    icon: Icons.route_rounded,
                    label: 'Distancia',
                    value: distance,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniInfoTile(
                    icon: Icons.access_time_rounded,
                    label: 'Tiempo',
                    value: duration,
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

class _MiniInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.formFieldBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.iconCircle,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.headerBottom),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  text: label,
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

class _RecenterButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(
            Icons.my_location_rounded,
            color: AppColors.headerBottom,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _RouteLoaderPage extends StatelessWidget {
  const _RouteLoaderPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Column(
        children: [
          SizedBox(
            height: 128,
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  height: 128,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.headerTop, AppColors.headerBottom],
                    ),
                  ),
                ),
                Positioned(
                  top: 32,
                  left: -20,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: -14,
                  right: -10,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

class _RouteErrorPage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RouteErrorPage({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Column(
        children: [
          SizedBox(
            height: 128,
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  height: 128,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.headerTop, AppColors.headerBottom],
                    ),
                  ),
                ),
                Positioned(
                  top: 32,
                  left: -20,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: -14,
                  right: -10,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.headerBottom.withOpacity(0.10),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 42,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: MyButton(
                          text: 'Reintentar',
                          onTap: onRetry,
                          margin: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 5,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.headerBottom),
        ),
      ),
    );
  }
}
