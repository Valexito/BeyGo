// lib/features/reservations/pages/reserve_space_page.dart
//
// ✅ google_maps_flutter.LatLng (no latlong2)
// ✅ Import paths match project structure (common/utils/components/ui/)
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/reservations/reservations.dart';
import 'package:beygo/features/users/users.dart';
class ReserveSpacePage extends ConsumerStatefulWidget {
  final Parking parking;

  const ReserveSpacePage({super.key, required this.parking});

  @override
  ConsumerState<ReserveSpacePage> createState() => _ReserveSpacePageState();
}

class _ReserveSpacePageState extends ConsumerState<ReserveSpacePage> {
  int? selectedSpace;
  bool _isSubmitting = false;
  Vehicle? _selectedVehicle;

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
      g.add('https://via.placeholder.com/800x400?text=Parqueo');
    }
    return g.toSet().toList();
  }

  Future<void> _confirmReservation() async {
    if (selectedSpace == null || _isSubmitting) return;

    final vehicles = ref.read(myVehiclesProvider).asData?.value ?? const [];
    final vehicle = _selectedVehicle ?? _pickDefaultVehicle(vehicles);

    if (vehicle == null) {
      _showErrorDialog('Debes agregar o seleccionar un vehículo para reservar.');
      return;
    }

    final ok = await ReservationDialogs.showConfirmReservationDialog(
      context,
      destination: LatLng(widget.parking.lat, widget.parking.lng),
      parkingName: widget.parking.name,
      spaceNumber: selectedSpace!,
      vehiclePlate: vehicle.plate,
      pricePerHour:
          ref
              .read(parkingStreamProvider(widget.parking.id))
              .asData
              ?.value
              .pricePerHour ??
          widget.parking.pricePerHour,
    );

    if (ok != true || !mounted) return;
    setState(() => _isSubmitting = true);

    try {
      final reserve = ref.read(reserveSpaceProvider);
      final reservationId = await reserve(
        parkingId: widget.parking.id,
        parkingName: widget.parking.name,
        spaceNumber: selectedSpace!,
        vehiclePlate: vehicle.plate,
      );

      if (!mounted) return;

      if (widget.parking.lat == 0 && widget.parking.lng == 0) {
        debugPrint('❌ INVALID DESTINATION (0,0)');
        return;
      }

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
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Vehicle? _pickDefaultVehicle(List<Vehicle> vehicles) {
    if (vehicles.isEmpty) return null;
    if (vehicles.length == 1) return vehicles.first;
    for (final vehicle in vehicles) {
      if (vehicle.isPrimary) return vehicle;
    }
    return vehicles.first;
  }

  Future<void> _pickVehicle(List<Vehicle> vehicles) async {
    if (vehicles.isEmpty) {
      _showErrorDialog('Debes registrar al menos un vehículo para reservar.');
      return;
    }

    if (vehicles.length == 1) {
      setState(() => _selectedVehicle = vehicles.first);
      return;
    }

    final picked = await showModalBottomSheet<Vehicle>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final current = _selectedVehicle ?? _pickDefaultVehicle(vehicles);
        return Container(
          decoration: BoxDecoration(
            color: sheetContext.appCardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: sheetContext.appBorderColor),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: sheetContext.appBorderColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Selecciona un vehículo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: sheetContext.appTextPrimaryColor,
                ),
              ),
              const SizedBox(height: 14),
              ...vehicles.map((vehicle) {
                final selected = current?.id == vehicle.id;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor:
                      selected
                          ? sheetContext.appCardBackgroundSoft
                          : Colors.transparent,
                  leading: Icon(
                    switch (vehicle.type) {
                      VehicleType.car => Icons.directions_car_rounded,
                      VehicleType.motorcycle => Icons.two_wheeler_rounded,
                      VehicleType.other => Icons.commute_rounded,
                    },
                    color:
                        selected
                            ? sheetContext.appBrandIconColor
                            : sheetContext.appTextPrimaryColor,
                  ),
                  title: Text(
                    vehicle.plate,
                    style: TextStyle(
                      color: sheetContext.appTextPrimaryColor,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    vehicle.type.label,
                    style: TextStyle(
                      color: sheetContext.appTextSecondaryColor,
                    ),
                  ),
                  trailing:
                      selected
                          ? Icon(
                            Icons.check_rounded,
                            color: sheetContext.appBrandIconColor,
                          )
                          : vehicle.isPrimary
                          ? Text(
                            'Principal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sheetContext.appTextPrimaryColor,
                            ),
                          )
                          : null,
                  onTap: () => Navigator.pop(sheetContext, vehicle),
                );
              }),
            ],
          ),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedVehicle = picked);
    }
  }

  void _showErrorDialog(String rawError) {
    final isRestricted =
        rawError.contains('temporalmente') ||
        rawError.contains('reservar temporalmente');
    final isSpaceTaken = rawError.contains('disponible');
    final isNotLoggedIn = rawError.contains('sesión');

    final icon =
        isRestricted
            ? Icons.block_rounded
            : isSpaceTaken
            ? Icons.local_parking_rounded
            : isNotLoggedIn
            ? Icons.lock_outline_rounded
            : Icons.error_outline_rounded;

    final color =
        isRestricted
            ? const Color(0xFFDC2626)
            : isSpaceTaken
            ? const Color(0xFFF59E0B)
            : AppColors.headerBottom;

    final title =
        isRestricted
            ? 'Cuenta restringida'
            : isSpaceTaken
            ? 'Espacio no disponible'
            : isNotLoggedIn
            ? 'Sesión requerida'
            : 'No se pudo reservar';

    final message =
        isRestricted
            ? 'Tu cuenta tiene una restricción temporal. Espera o contacta soporte.'
            : isSpaceTaken
            ? 'Alguien más tomó este espacio. Por favor selecciona otro.'
            : isNotLoggedIn
            ? 'Debes iniciar sesión para reservar.'
            : rawError.replaceAll('Bad state: ', '');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: context.appCardBackground,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
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
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.26),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(icon, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      children: [
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.appTextSecondaryColor,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: MyButton(
                            text:
                                isSpaceTaken
                                    ? 'Elegir otro espacio'
                                    : 'Entendido',
                            onTap: () => Navigator.pop(ctx),
                            margin: EdgeInsets.zero,
                            height: 46,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(myVehiclesProvider);

    vehiclesAsync.whenData((vehicles) {
      if (_selectedVehicle == null && vehicles.isNotEmpty) {
        final fallback = _pickDefaultVehicle(vehicles);
        if (fallback != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _selectedVehicle != null) return;
            setState(() => _selectedVehicle = fallback);
          });
        }
      }
    });

    return ReserveSpaceContent(
      parking: widget.parking,
      gallery: gallery,
      selectedSpace: selectedSpace,
      isSubmitting: _isSubmitting,
      vehiclesAsync: vehiclesAsync,
      selectedVehicle: _selectedVehicle,
      onPickVehicle: _pickVehicle,
      onSelectSpace: (num) {
        setState(() {
          selectedSpace == num ? selectedSpace = null : selectedSpace = num;
        });
      },
      onConfirm: _confirmReservation,
    );
  }
}
