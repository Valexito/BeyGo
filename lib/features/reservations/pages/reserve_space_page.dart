import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_api/features/reservations/components/reservation_dialogs.dart';
import 'package:mapbox_api/features/reservations/models/parking.dart';
import 'package:mapbox_api/features/reservations/pages/reserve_space_content.dart';
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';

class ReserveSpacePage extends ConsumerStatefulWidget {
  final Parking parking;

  const ReserveSpacePage({super.key, required this.parking});

  @override
  ConsumerState<ReserveSpacePage> createState() => _ReserveSpacePageState();
}

class _ReserveSpacePageState extends ConsumerState<ReserveSpacePage> {
  int? selectedSpace;
  bool _isSubmitting = false;

  /// 🔥 Gallery EXACTA (NO CAMBIAR)
  List<String> get gallery {
    final g = <String>[];

    if (widget.parking.photos.isNotEmpty) {
      g.addAll(
        widget.parking.photos
            .where((e) => e.trim().isNotEmpty)
            .map((e) => e.trim()),
      );
    }

    final cover = (widget.parking.coverUrl ?? '').trim();
    final image = (widget.parking.imageUrl ?? '').trim();

    if (g.isEmpty && cover.isNotEmpty) g.add(cover);
    if (g.isEmpty && image.isNotEmpty) g.add(image);

    if (g.isEmpty) {
      g.add('https://via.placeholder.com/800x400?text=Parking');
    }

    return g.toSet().toList();
  }

  Future<void> _confirmReservation() async {
    if (selectedSpace == null || _isSubmitting) return;

    print(
      '[RESERVE PAGE] parking.pricePerHour: ${widget.parking.pricePerHour}',
    );
    print('[RESERVE PAGE] parking.price: ${widget.parking.price}');

    final ok = await ReservationDialogs.showConfirmReservationDialog(
      context,
      destination: LatLng(widget.parking.lat, widget.parking.lng),
      parkingName: widget.parking.name,
      spaceNumber: selectedSpace!,
      pricePerHour:
          ref
              .read(parkingStreamProvider(widget.parking.id))
              .asData
              ?.value
              .pricePerHour ??
          widget.parking.pricePerHour ??
          0,
    );

    if (ok != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final reserve = ref.read(reserveSpaceProvider);

      final reservationId = await reserve(
        parkingId: widget.parking.id,
        parkingName: widget.parking.name,
        spaceNumber: selectedSpace!,
      );

      if (!mounted) return;

      if (widget.parking.lat == 0 && widget.parking.lng == 0) {
        debugPrint('❌ INVALID DESTINATION (0,0)');
        return;
      }
      print(
        '[NAVIGATE] destination: ${widget.parking.lat}, ${widget.parking.lng}',
      );
      print('[NAVIGATE] parkingName: ${widget.parking.name}');
      print('[NAVIGATE] reservationId: $reservationId');
      print('[NAVIGATE] spaceNumber: $selectedSpace');

      Navigator.pushNamed(
        context,
        '/routeView',
        arguments: {
          'destination': LatLng(widget.parking.lat, widget.parking.lng),
          'parkingName': widget.parking.name,
          'reservationId': reservationId,
          'spaceNumber': selectedSpace!,
        },
      );
    } catch (e, st) {
      debugPrint('🔥 RESERVE ERROR: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReserveSpaceContent(
      parking: widget.parking,
      gallery: gallery,
      selectedSpace: selectedSpace,
      isSubmitting: _isSubmitting,
      onSelectSpace: (num) {
        setState(() {
          selectedSpace == num ? selectedSpace = null : selectedSpace = num;
        });
      },
      onConfirm: _confirmReservation,
    );
  }
}
