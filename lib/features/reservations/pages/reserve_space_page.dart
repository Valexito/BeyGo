import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_button.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/features/reservations/components/reservation_dialogs.dart';
import 'package:mapbox_api/features/reservations/models/parking.dart';
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

  List<String> get _gallery {
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

    if (g.isEmpty && cover.isNotEmpty) {
      g.add(cover);
    }

    if (g.isEmpty && image.isNotEmpty) {
      g.add(image);
    }

    if (g.isEmpty) {
      g.add('https://via.placeholder.com/800x400?text=Parking');
    }

    return g.toSet().toList();
  }

  Future<void> _confirmReservation() async {
    if (selectedSpace == null || _isSubmitting) return;

    final chosenSpace = selectedSpace!;

    final ok = await ReservationDialogs.showConfirmReservationDialog(
      context,
      destination: LatLng(widget.parking.lat, widget.parking.lng),
      parkingName: widget.parking.name,
      spaceNumber: chosenSpace,
    );

    if (ok != true || !mounted) return;

    setState(() => _isSubmitting = true);

    try {
      final reserve = ref.read(reserveSpaceProvider);
      final reservationId = await reserve(
        parkingId: widget.parking.id,
        parkingName: widget.parking.name,
        spaceNumber: chosenSpace,
      );

      if (!mounted) return;

      Navigator.of(context).pushNamed(
        '/routeView',
        arguments: {
          'destination': LatLng(widget.parking.lat, widget.parking.lng),
          'parkingName': widget.parking.name,
          'reservationId': reservationId,
          'spaceNumber': chosenSpace,
        },
      );
    } catch (e, st) {
      debugPrint('🔥 RESERVE ERROR: $e');
      debugPrintStack(stackTrace: st);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error real: ${e.toString()}')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    final cross =
        w >= 520
            ? 5
            : w >= 390
            ? 4
            : 3;

    final spacesAsync = ref.watch(parkingSpacesProvider(widget.parking.id));

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ReservationHeader(
              gallery: _gallery,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -18),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(34),
                      topRight: Radius.circular(34),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const MyText(
                              text: 'Reservar espacio',
                              variant: MyTextVariant.title,
                              customColor: AppColors.headerBottom,
                              fontSize: 22,
                            ),
                            const SizedBox(height: 6),
                            const MyText(
                              text:
                                  'Selecciona un espacio disponible para continuar con tu reserva.',
                              variant: MyTextVariant.bodyMuted,
                              fontSize: 13,
                            ),
                            const SizedBox(height: 18),
                            _InfoChipsRow(parking: widget.parking),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.headerBottom.withOpacity(
                                    0.08,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const MyText(
                                  text: 'Disponibilidad',
                                  variant: MyTextVariant.normalBold,
                                  fontSize: 15,
                                ),
                                const SizedBox(height: 10),
                                const Wrap(
                                  spacing: 14,
                                  runSpacing: 10,
                                  children: [
                                    _LegendDot(
                                      color: Color(0xFF16A34A),
                                      label: 'Libre',
                                    ),
                                    _LegendDot(
                                      color: Color(0xFFCBD5E1),
                                      label: 'Ocupado',
                                    ),
                                    _LegendDot(
                                      color: AppColors.headerBottom,
                                      label: 'Seleccionado',
                                      filled: true,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: spacesAsync.when(
                                    loading:
                                        () => const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                    error:
                                        (e, _) => Center(
                                          child: MyText(
                                            text: 'Error cargando espacios: $e',
                                            variant: MyTextVariant.bodyMuted,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                    data: (spacesMap) {
                                      final total =
                                          widget.parking.spaces > 0
                                              ? widget.parking.spaces
                                              : (spacesMap.isNotEmpty
                                                  ? spacesMap.length
                                                  : 20);

                                      return GridView.builder(
                                        itemCount: total,
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: cross,
                                              mainAxisSpacing: 12,
                                              crossAxisSpacing: 12,
                                              childAspectRatio: 0.95,
                                            ),
                                        itemBuilder: (_, idx) {
                                          final num = idx + 1;
                                          final space = spacesMap[num];
                                          final occupied =
                                              (space?.status ?? 'free') !=
                                              'free';
                                          final selected = selectedSpace == num;

                                          return _SpaceTile(
                                            number: num,
                                            occupied: occupied,
                                            selected: selected,
                                            onTap:
                                                occupied || _isSubmitting
                                                    ? null
                                                    : () => setState(() {
                                                      selected
                                                          ? selectedSpace = null
                                                          : selectedSpace = num;
                                                    }),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(26),
                            topRight: Radius.circular(26),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.headerBottom.withOpacity(0.08),
                              blurRadius: 22,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              /// LEFT
                              SizedBox(
                                width: 160,
                                height: 44,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        selectedSpace != null
                                            ? AppColors.headerBottom
                                                .withOpacity(0.08)
                                            : AppColors.formFieldBg,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.local_parking_rounded,
                                        size: 18,
                                        color: AppColors.headerBottom,
                                      ),
                                      const SizedBox(width: 6),
                                      MyText(
                                        text:
                                            selectedSpace == null
                                                ? 'Seleccionar'
                                                : 'Espacio $selectedSpace',
                                        fontSize: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              /// RIGHT
                              SizedBox(
                                width: 160,
                                height: 44,
                                child: MyButton(
                                  text: _isSubmitting ? '...' : 'Confirmar',
                                  onTap:
                                      selectedSpace != null && !_isSubmitting
                                          ? _confirmReservation
                                          : null,
                                  margin: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationHeader extends StatefulWidget {
  final List<String> gallery;
  final VoidCallback onBack;

  const _ReservationHeader({required this.gallery, required this.onBack});

  @override
  State<_ReservationHeader> createState() => _ReservationHeaderState();
}

class _ReservationHeaderState extends State<_ReservationHeader> {
  late final PageController _pageController;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasGallery = widget.gallery.isNotEmpty;

    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasGallery)
            PageView.builder(
              controller: _pageController,
              itemCount: widget.gallery.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                return Image.network(
                  widget.gallery[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => const _ImageFallback(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const _ImageShimmer();
                  },
                );
              },
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.headerTop, AppColors.headerBottom],
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.08),
                      Colors.black.withOpacity(0.18),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 38,
            left: -20,
            child: IgnorePointer(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            top: -10,
            right: -10,
            child: IgnorePointer(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 18,
            child: SafeArea(
              child: TextButton.icon(
                onPressed: widget.onBack,
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
          if (widget.gallery.length > 1)
            Positioned(
              top: 18,
              right: 18,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_page + 1}/${widget.gallery.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (widget.gallery.length > 1)
            Positioned(
              bottom: 18,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.gallery.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 7,
                      width: _page == i ? 18 : 7,
                      decoration: BoxDecoration(
                        color: _page == i ? Colors.white : Colors.white70,
                        borderRadius: BorderRadius.circular(10),
                      ),
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

class _InfoChipsRow extends StatelessWidget {
  final Parking parking;

  const _InfoChipsRow({required this.parking});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _InfoChip(
          icon: Icons.directions_car_outlined,
          label: '${parking.spaces} espacios',
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.headerBottom.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.headerBottom),
          const SizedBox(width: 8),
          MyText(text: label, variant: MyTextVariant.body, fontSize: 12),
        ],
      ),
    );
  }
}

class _SpaceTile extends StatelessWidget {
  final int number;
  final bool occupied;
  final bool selected;
  final VoidCallback? onTap;

  const _SpaceTile({
    required this.number,
    required this.occupied,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final decoration =
        occupied
            ? BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(14),
            )
            : selected
            ? BoxDecoration(
              color: AppColors.headerBottom,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.headerBottom.withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            )
            : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
            );
    final Color iconColor =
        occupied
            ? const Color(0xFF6B7280)
            : selected
            ? Colors.white
            : AppColors.textPrimary;

    final Color labelColor =
        occupied
            ? const Color(0xFF6B7280)
            : selected
            ? Colors.white
            : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: decoration,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_car_outlined, size: 21, color: iconColor),
              const SizedBox(height: 6),
              Text(
                'Espacio $number',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool filled;

  const _LegendDot({
    required this.color,
    required this.label,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: filled ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        MyText(text: label, variant: MyTextVariant.body, fontSize: 12),
      ],
    );
  }
}

class _ImageShimmer extends StatelessWidget {
  const _ImageShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE9EDF3),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.headerTop, AppColors.headerBottom],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported,
        size: 40,
        color: Colors.white,
      ),
    );
  }
}
