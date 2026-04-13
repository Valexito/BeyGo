import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/features/core/providers/favorites_provider.dart';

import 'package:mapbox_api/features/core/components/home_bottom_parking_details.dart';
import 'package:mapbox_api/features/reservations/models/parking.dart';

void openParkingSheet(BuildContext context, Parking parking) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _ParkingSheet(parking: parking),
      );
    },
  );
}

class _ParkingSheet extends ConsumerStatefulWidget {
  final Parking parking;
  const _ParkingSheet({required this.parking});

  @override
  ConsumerState<_ParkingSheet> createState() => _ParkingSheetState();
}

class _ParkingSheetState extends ConsumerState<_ParkingSheet> {
  bool? _localFav;

  @override
  Widget build(BuildContext context) {
    final asyncFav = ref.watch(isFavoriteStreamProvider(widget.parking.id));
    final toggle = ref.read(toggleFavoriteProvider);

    final uiFav = _localFav ?? asyncFav.asData?.value ?? false;

    return HomeParkingDetailBottomSheet(
      parking: widget.parking,
      isFavorite: uiFav,
      onToggleFavorite: () async {
        final next = !uiFav;
        setState(() => _localFav = next);
        try {
          await toggle(toFav: next, p: widget.parking);
        } catch (_) {
          if (mounted) {
            setState(() => _localFav = !next);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo actualizar favoritos')),
            );
          }
        }
      },
    );
  }
}
