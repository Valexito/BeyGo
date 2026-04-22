// lib/features/reservations/components/reservation_card.dart
//
// ✅ FIXED: latlong2.LatLng → google_maps_flutter.LatLng
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mapbox_api/common/ui/components/app_styles.dart';
import 'package:mapbox_api/common/ui/components/my_text.dart';
import 'package:mapbox_api/features/reservations/components/reservations_details_sheet.dart';
import 'package:mapbox_api/features/reservations/models/parking.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';
import 'package:url_launcher/url_launcher.dart';

class ReservationCard extends ConsumerWidget {
  final Reservation reservation;

  const ReservationCard({super.key, required this.reservation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parkingAsync = ref.watch(
      parkingStreamProvider(reservation.parkingId),
    );

    return parkingAsync.when(
      loading:
          () => _ReservationCardShell(
            reservation: reservation,
            parking: null,
            loading: true,
          ),
      error:
          (_, __) => _ReservationCardShell(
            reservation: reservation,
            parking: null,
            loading: false,
          ),
      data:
          (parking) => _ReservationCardShell(
            reservation: reservation,
            parking: parking,
            loading: false,
          ),
    );
  }
}

class _ReservationCardShell extends StatelessWidget {
  final Reservation reservation;
  final Parking? parking;
  final bool loading;

  const _ReservationCardShell({
    required this.reservation,
    required this.parking,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImage(parking);
    final statusColor = _statusColor(reservation);
    final statusText = _statusLabel(reservation);
    final priceText = _priceText(parking, reservation);
    final startText = _formatDateTime(reservation.reservedAt);
    final durationText = _durationText(reservation);

    final showNavigate =
        reservation.state == 'active' ||
        reservation.state == 'pending' ||
        reservation.providerApprovalStatus == 'pending';

    final isApprovedActive =
        reservation.state == 'active' &&
        reservation.providerApprovalStatus == 'approved';

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final imageWidth = totalWidth * 0.33;
        final rightWidth = totalWidth * 0.24;

        return Material(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder:
                    (_) => ReservationDetailsSheet(reservation: reservation),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: context.appBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: context.isDarkMode ? 0.18 : 0.05,
                    ),
                    blurRadius: context.isDarkMode ? 20 : 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: imageWidth,
                    child: _CardImage(imageUrl: imageUrl, loading: loading),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(
                            text: reservation.parkingName,
                            variant: MyTextVariant.bodyBold,
                            fontSize: 15,
                          ),
                          if (reservation.reservationNumber != null &&
                              (reservation.state == 'active' ||
                                  reservation.state == 'completed')) ...[
                            const SizedBox(height: 4),
                            MyText(
                              text: 'No. ${reservation.reservationNumber}',
                              variant: MyTextVariant.bodyMuted,
                              fontSize: 12,
                              customColor: AppColors.headerBottom,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _InfoChipLine(
                            icon: Icons.local_parking_outlined,
                            text: 'Espacio ${reservation.spaceNumber}',
                          ),
                          const SizedBox(height: 6),
                          _InfoChipLine(
                            icon: Icons.access_time_rounded,
                            text: startText,
                          ),
                          const SizedBox(height: 6),
                          _InfoChipLine(
                            icon: Icons.timelapse_outlined,
                            text: durationText,
                          ),
                          const SizedBox(height: 6),
                          _InfoChipLine(
                            icon: Icons.payments_outlined,
                            text: priceText,
                            highlight: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: rightWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (showNavigate) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: OutlinedButton(
                              onPressed:
                                  parking == null
                                      ? null
                                      : () => _openNavigation(
                                        context,
                                        // ✅ google_maps_flutter.LatLng
                                        LatLng(parking!.lat, parking!.lng),
                                        reservation,
                                      ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: AppColors.headerBottom.withValues(
                                    alpha: 0.18,
                                  ),
                                  width: 1.1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor:
                                    context.isDarkMode
                                        ? context.appCardBackgroundSoft
                                        : const Color(0xFFF3F4F6),
                                foregroundColor: AppColors.headerBottom,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                elevation: 0,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.navigation_outlined,
                                    size: 15,
                                    color: AppColors.headerBottom,
                                  ),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Navegar',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.headerBottom,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isApprovedActive) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 32,
                              child: ElevatedButton(
                                onPressed: () {
                                  final phone = (parking?.phone ?? '')
                                      .replaceAll('+', '');
                                  if (phone.isEmpty) return;
                                  launchUrl(
                                    Uri.parse('https://wa.me/$phone'),
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.chat,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String? _resolveImage(Parking? parking) {
    if (parking == null) return null;
    if (parking.photos.isNotEmpty) {
      final first = parking.photos.first.trim();
      if (first.isNotEmpty) return first;
    }
    if (parking.coverUrl?.trim().isNotEmpty == true) {
      return parking.coverUrl!.trim();
    }
    if (parking.imageUrl?.trim().isNotEmpty == true) {
      return parking.imageUrl!.trim();
    }
    return null;
  }

  static String _priceText(Parking? parking, Reservation reservation) {
    final pricePerHour = parking?.pricePerHour ?? 0;
    return pricePerHour > 0 ? 'Q $pricePerHour por hora' : 'Tarifa no disp.';
  }

  static String _formatDateTime(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  static String _durationText(Reservation reservation) {
    if (reservation.durationMinutes != null) {
      final mins = reservation.durationMinutes!;
      if (mins < 60) return '$mins min';
      final h = mins ~/ 60;
      final m = mins % 60;
      return m == 0 ? '$h h' : '$h h $m min';
    }
    final mins = DateTime.now().difference(reservation.reservedAt).inMinutes;
    if (mins <= 0) return '0 min';
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  static String _statusLabel(Reservation r) {
    if (r.providerApprovalStatus == 'pending') return 'PENDIENTE';
    if (r.state == 'pending') return 'PENDIENTE';
    if (r.state == 'completed') return 'COMPLETADA';
    if (r.state == 'cancelled') return 'CANCELADA';
    if (r.state == 'rejected' || r.providerApprovalStatus == 'rejected') {
      return 'DENEGADA';
    }
    if (r.state == 'active' && r.exitStatus == 'approved') return 'SALIDA OK';
    if (r.state == 'active' && r.exitStatus == 'requested') {
      return 'SALIDA SOL.';
    }
    return 'ACTIVA';
  }

  static Color _statusColor(Reservation r) {
    if (r.providerApprovalStatus == 'pending') {
      return const Color(0xFFF59E0B);
    }
    if (r.state == 'pending') return const Color(0xFFF59E0B);
    if (r.state == 'completed') return const Color(0xFF2563EB);
    if (r.state == 'cancelled') return const Color(0xFFDC2626);
    if (r.state == 'rejected' || r.providerApprovalStatus == 'rejected') {
      return const Color(0xFFDC2626);
    }
    if (r.state == 'active' && r.exitStatus == 'approved') {
      return const Color(0xFF0EA5E9);
    }
    if (r.state == 'active' && r.exitStatus == 'requested') {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF16A34A);
  }

  static void _openNavigation(
    BuildContext context,
    LatLng destination, // ✅ google_maps_flutter.LatLng
    Reservation reservation,
  ) {
    Navigator.pushNamed(
      context,
      '/routeView',
      arguments: {
        'destination': destination,
        'parkingName': reservation.parkingName,
        'reservationId': reservation.id,
        'spaceNumber': reservation.spaceNumber,
      },
    );
  }
}

// ─── Sub-widgets (unchanged logic) ───────────────────────────────────────────

class _InfoChipLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;

  const _InfoChipLine({
    required this.icon,
    required this.text,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color:
                highlight
                    ? AppColors.headerBottom.withValues(alpha: 0.10)
                    : context.appIconCircleColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 13,
            color:
                highlight
                    ? AppColors.headerBottom
                    : context.appTextSecondaryColor,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  highlight
                      ? AppColors.headerBottom
                      : context.appTextSecondaryColor,
              fontSize: 11.5,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardImage extends StatelessWidget {
  final String? imageUrl;
  final bool loading;

  const _CardImage({required this.imageUrl, required this.loading});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: context.appInputBackground,
          child:
              loading
                  ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                  : imageUrl == null
                  ? const _CardImageFallback()
                  : Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _CardImageFallback(),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                  ),
        ),
      ),
    );
  }
}

class _CardImageFallback extends StatelessWidget {
  const _CardImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              context.isDarkMode
                  ? const [Color(0xFF1E3A5F), Color(0xFF0F172A)]
                  : const [AppColors.headerTop, AppColors.headerBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.local_parking_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
