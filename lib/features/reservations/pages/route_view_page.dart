// lib/features/reservations/pages/route_view_page.dart
//
// Uses GoogleDirectionsService (via directions_providers.dart)
// Uses google_maps_flutter.LatLng everywhere (no latlong2)
//
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/reservations/reservations.dart';

class RouteViewPage extends ConsumerStatefulWidget {
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
  ConsumerState<RouteViewPage> createState() => _RouteViewPageState();
}

class _RouteViewPageState extends ConsumerState<RouteViewPage> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _buildMapObjects(List<LatLng> points, LatLng origin, LatLng dest) {
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        width: 5,
        // The brand blue blends into the dark map style's own dark road
        // colors — use a light/white line in dark mode so it stays visible.
        color: context.isDarkMode ? Colors.white : AppColors.headerBottom,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
    _markers = {
      _pin(
        origin,
        Icons.my_location_rounded,
        const Color(0xFF16A34A),
        const MarkerId('origin'),
      ),
      _pin(
        dest,
        Icons.location_on_rounded,
        Colors.red,
        const MarkerId('destination'),
      ),
    };
  }

  Marker _pin(LatLng pos, IconData icon, Color color, MarkerId id) {
    return Marker(
      markerId: id,
      position: pos,
      icon: BitmapDescriptor.defaultMarkerWithHue(
        color == Colors.red
            ? BitmapDescriptor.hueRed
            : BitmapDescriptor.hueGreen,
      ),
    );
  }

  void _recenter(LatLng origin) {
    _mapController?.animateCamera(CameraUpdate.newLatLng(origin));
  }

  Future<void> _zoom(double delta) async {
    final zoom = await _mapController?.getZoomLevel() ?? 15;
    _mapController?.animateCamera(CameraUpdate.zoomTo(zoom + delta));
  }

  @override
  Widget build(BuildContext context) {
    // Read args from Navigator if available (deep-link / named route)
    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final effectiveReservationId =
        routeArgs?['reservationId'] ?? widget.reservationId;
    final LatLng effectiveDest =
        routeArgs?['destination'] ?? widget.destination;
    final String effectiveParkingName =
        routeArgs?['parkingName'] ?? widget.parkingName;
    final int? effectiveSpaceNumber =
        routeArgs?['spaceNumber'] ?? widget.spaceNumber;

    final originAsync = ref.watch(currentLocationProvider);

    return originAsync.when(
      loading: () => const _RouteLoaderPage(),
      error:
          (e, _) => _RouteErrorPage(
            message:
                'No se pudo obtener tu ubicación.\n'
                'Activa el GPS y los permisos e inténtalo de nuevo.',
            onRetry: () => ref.refresh(currentLocationProvider),
          ),
      data: (origin) {
        // Guard: invalid destination
        if (effectiveDest.latitude == 0 && effectiveDest.longitude == 0) {
          return _RouteErrorPage(
            message: 'Destino inválido. No se puede calcular la ruta.',
            onRetry: () => Navigator.pop(context),
          );
        }

        final args = (origin: origin, destination: effectiveDest);
        final pointsAsync = ref.watch(routePointsProvider(args));
        final distanceAsync = ref.watch(routeDistanceProvider(args));
        final durationAsync = ref.watch(routeDurationProvider(args));

        return pointsAsync.when(
          loading: () => const _RouteLoaderPage(),
          error:
              (e, _) => _RouteErrorPage(
                message:
                    'No se pudo calcular la ruta.\n'
                    'Verifica tu conexión a internet.',
                onRetry: () {
                  ref.invalidate(routePointsProvider(args));
                  ref.invalidate(routeDistanceProvider(args));
                  ref.invalidate(routeDurationProvider(args));
                },
              ),
          data: (points) {
            if (points.isEmpty) {
              return _RouteErrorPage(
                message: 'La ruta no tiene puntos. Intenta de nuevo.',
                onRetry: () => ref.invalidate(routePointsProvider(args)),
              );
            }

            _buildMapObjects(points, origin, effectiveDest);

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
                backgroundColor: context.appPageBackground,
                body: Stack(
                  children: [
                    // ── Map ─────────────────────────────────────────────────
                    GoogleMap(
                      onMapCreated: (ctrl) {
                        _mapController = ctrl;
                        // Works around a cold-start Android Maps renderer
                        // race where POI icons/labels stay missing until the
                        // app is relaunched — re-apply the style once ready.
                        ctrl.setMapStyle(
                          GoogleMapStyles.forBrightness(
                            Theme.of(context).brightness,
                          ),
                        );
                        // Fit both markers
                        Future.delayed(const Duration(milliseconds: 300), () {
                          // The page can be popped (e.g. user taps back)
                          // before this delayed callback fires, leaving the
                          // controller's widget disposed — animateCamera on
                          // it then throws a fatal "used after disposed".
                          if (!mounted) return;
                          ctrl.animateCamera(
                            CameraUpdate.newLatLngBounds(
                              LatLngBounds(
                                southwest: LatLng(
                                  origin.latitude < effectiveDest.latitude
                                      ? origin.latitude
                                      : effectiveDest.latitude,
                                  origin.longitude < effectiveDest.longitude
                                      ? origin.longitude
                                      : effectiveDest.longitude,
                                ),
                                northeast: LatLng(
                                  origin.latitude > effectiveDest.latitude
                                      ? origin.latitude
                                      : effectiveDest.latitude,
                                  origin.longitude > effectiveDest.longitude
                                      ? origin.longitude
                                      : effectiveDest.longitude,
                                ),
                              ),
                              120, // padding
                            ),
                          );
                        });
                      },
                      initialCameraPosition: CameraPosition(
                        target: origin,
                        zoom: 14,
                      ),
                      polylines: _polylines,
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      style: GoogleMapStyles.forBrightness(
                        Theme.of(context).brightness,
                      ),
                    ),

                    // ── Header ───────────────────────────────────────────────
                    _RouteHeader(
                      parkingName: effectiveParkingName,
                      onBack: () => Navigator.pop(context),
                    ),

                    // ── Map controls ─────────────────────────────────────────
                    Positioned(
                      right: 14,
                      bottom: 290,
                      child: AppMapControls(
                        onZoomIn: () => _zoom(1),
                        onZoomOut: () => _zoom(-1),
                        onMyLocation: () => _recenter(origin),
                      ),
                    ),
                  ],
                ),

                // ── Bottom sheet with route info ──────────────────────────
                bottomSheet:
                    effectiveReservationId == null
                        ? RouteBottomInfoCard(
                          parkingName: effectiveParkingName,
                          distance: distance,
                          duration: duration,
                          spaceNumber: effectiveSpaceNumber,
                          destination: effectiveDest,
                          reservationStatus: widget.reservationState,
                          onGoToReservations:
                              () => Navigator.of(
                                context,
                              ).pushNamed('/reservationsPage'),
                        )
                        : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('reservations')
                                  .doc(effectiveReservationId)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            final data = snapshot.data?.data();
                            final rawState =
                                (data?['state'] as String?) ?? 'unknown';
                            final providerApproval =
                                (data?['providerApprovalStatus'] as String?) ??
                                '';

                            String state;
                            if (providerApproval == 'pending') {
                              state = 'pending';
                            } else if (rawState == 'cancellation_requested') {
                              state = 'cancellation_requested';
                            } else {
                              state = rawState;
                            }

                            return RouteBottomInfoCard(
                              parkingName: effectiveParkingName,
                              distance: distance,
                              duration: duration,
                              spaceNumber: effectiveSpaceNumber,
                              destination: effectiveDest,
                              reservationStatus: state,
                              onGoToReservations:
                                  () => Navigator.of(
                                    context,
                                  ).pushNamed('/reservationsPage'),
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
}

// ─── Loading page ─────────────────────────────────────────────────────────
class _RouteLoaderPage extends StatelessWidget {
  const _RouteLoaderPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.headerTop, AppColors.headerBottom],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.headerBottom.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Calculando ruta...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error page ────────────────────────────────────────────────────────────
class _RouteErrorPage extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _RouteErrorPage({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 32,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudo obtener la ruta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: context.appTextSecondaryColor,
                ),
              ),
              const SizedBox(height: 24),
              MyButton(
                text: 'Reintentar',
                onTap: onRetry,
                margin: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Route Header ─────────────────────────────────────────────────────────
class _RouteHeader extends StatelessWidget {
  final String parkingName;
  final VoidCallback onBack;
  const _RouteHeader({required this.parkingName, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final headerGradient =
        context.isDarkMode
            ? const [Color(0xFF111827), Color(0xFF0F172A), Color(0xFF0B1220)]
            : const [AppColors.headerTop, AppColors.headerBottom];

    return SizedBox(
      height: 120,
      width: double.infinity,
      child: Stack(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: headerGradient,
              ),
            ),
          ),
          Positioned(
            top: 30,
            left: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: context.isDarkMode ? 0.04 : 0.10,
                ),
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
                color: Colors.white.withValues(
                  alpha: context.isDarkMode ? 0.03 : 0.08,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 8,
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
            bottom: 14,
            left: 20,
            right: 20,
            child: Text(
              'RUTA A ${parkingName.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
