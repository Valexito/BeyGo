import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/common/utils/components/ui/app_styles.dart';
import 'package:mapbox_api/common/utils/components/ui/my_button.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/features/reservations/models/parking.dart';
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';

class ReserveSpaceContent extends ConsumerStatefulWidget {
  final Parking parking;
  final List<String> gallery;
  final int? selectedSpace;
  final bool isSubmitting;
  final Function(int) onSelectSpace;
  final VoidCallback onConfirm;

  const ReserveSpaceContent({
    super.key,
    required this.parking,
    required this.gallery,
    required this.selectedSpace,
    required this.isSubmitting,
    required this.onSelectSpace,
    required this.onConfirm,
  });

  @override
  ConsumerState<ReserveSpaceContent> createState() =>
      _ReserveSpaceContentState();
}

class _ReserveSpaceContentState extends ConsumerState<ReserveSpaceContent> {
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              _ReservationHeader(
                gallery: widget.gallery,
                onBack: () => Navigator.pop(context),
              ),
            ],
          ),

          DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.75,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 255, 255, 255),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(34),
                    topRight: Radius.circular(34),
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                22,
                                20,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: MyText(
                                          text: 'Reservar espacio',
                                          variant: MyTextVariant.title,
                                          customColor: AppColors.headerBottom,
                                          fontSize: 22,
                                        ),
                                      ),
                                      _buildOpenStatus(),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const MyText(
                                    text:
                                        'Selecciona un espacio disponible para continuar con tu reserva.',
                                    variant: MyTextVariant.bodyMuted,
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      spacesAsync.when(
                                        data: (spacesMap) {
                                          final available =
                                              spacesMap.values
                                                  .where(
                                                    (s) => s.status == 'free',
                                                  )
                                                  .length;
                                          return _InfoChip(
                                            icon: Icons.directions_car_rounded,
                                            label: '$available disponibles',
                                          );
                                        },
                                        loading:
                                            () => const _InfoChip(
                                              icon:
                                                  Icons.directions_car_rounded,
                                              label: 'Cargando...',
                                            ),
                                        error:
                                            (_, __) => _InfoChip(
                                              icon:
                                                  Icons.directions_car_rounded,
                                              label:
                                                  '${widget.parking.spaces} espacios',
                                            ),
                                      ),
                                      _InfoChip(
                                        icon: Icons.attach_money_rounded,
                                        label: 'Q${widget.parking.price}/h',
                                      ),
                                      const _InfoChip(
                                        icon: Icons.access_time_rounded,
                                        label: '8:00 AM - 6:00 PM',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
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

                                    spacesAsync.when(
                                      loading:
                                          () => const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                      error:
                                          (e, _) => Center(child: Text('$e')),
                                      data: (spacesMap) {
                                        final total = widget.parking.spaces;
                                        return GridView.builder(
                                          controller: scrollController,
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
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
                                            final selected =
                                                widget.selectedSpace == num;

                                            return _SpaceTile(
                                              number: num,
                                              occupied: occupied,
                                              selected: selected,
                                              onTap:
                                                  occupied ||
                                                          widget.isSubmitting
                                                      ? null
                                                      : () => widget
                                                          .onSelectSpace(num),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 48,
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    widget.selectedSpace != null
                                        ? AppColors.headerBottom.withOpacity(
                                          0.12,
                                        )
                                        : AppColors.formFieldBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.headerBottom.withOpacity(
                                    0.15,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.directions_car_rounded,
                                    size: 18,
                                    color: AppColors.headerBottom,
                                  ),
                                  const SizedBox(width: 6),
                                  MyText(
                                    text:
                                        widget.selectedSpace == null
                                            ? 'Seleccionar'
                                            : 'Espacio ${widget.selectedSpace}',
                                    fontSize: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 160,
                            height: 48,
                            child: MyButton(
                              text: widget.isSubmitting ? '...' : 'Confirmar',
                              onTap:
                                  widget.selectedSpace != null &&
                                          !widget.isSubmitting
                                      ? () {
                                        if (!_isParkingOpen()) {
                                          showDialog(
                                            context: context,
                                            builder:
                                                (_) => AlertDialog(
                                                  title: const Text(
                                                    'Fuera de horario',
                                                  ),
                                                  content: const Text(
                                                    'El parqueo se encuentra fuera de horario de servicio. Intenta en horas regulares.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                          ),
                                                      child: const Text('OK'),
                                                    ),
                                                  ],
                                                ),
                                          );
                                          return;
                                        }

                                        widget.onConfirm();
                                      }
                                      : null,
                              margin: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOpenStatus() {
    try {
      final open = widget.parking.businessHours?['open'];
      final close = widget.parking.businessHours?['close'];

      if (open == null || close == null) {
        return _statusChip('N/A', Colors.grey);
      }

      TimeOfDay parse(String t) {
        final clean = t.toLowerCase().replaceAll(' ', '');
        final isPM = clean.contains('pm');

        final time = clean.replaceAll(RegExp(r'[a-z]'), '');
        final parts = time.split(':');

        int hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;

        return TimeOfDay(hour: hour, minute: minute);
      }

      final openTime = parse(open);
      final closeTime = parse(close);

      final now = TimeOfDay.now();

      final nowMinutes = now.hour * 60 + now.minute;
      final openMinutes = openTime.hour * 60 + openTime.minute;
      final closeMinutes = closeTime.hour * 60 + closeTime.minute;

      final isOpen = nowMinutes >= openMinutes && nowMinutes <= closeMinutes;

      return _statusChip(
        isOpen ? 'ABIERTO' : 'CERRADO',
        isOpen ? Colors.green : Colors.red,
      );
    } catch (_) {
      return _statusChip('N/A', Colors.grey);
    }
  }

  bool _isParkingOpen() {
    try {
      final open = widget.parking.businessHours?['open'];
      final close = widget.parking.businessHours?['close'];

      if (open == null || close == null) return true;

      TimeOfDay parse(String t) {
        final clean = t.toLowerCase().replaceAll(' ', '');
        final isPM = clean.contains('pm');

        final time = clean.replaceAll(RegExp(r'[a-z]'), '');
        final parts = time.split(':');

        int hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;

        return TimeOfDay(hour: hour, minute: minute);
      }

      final openTime = parse(open);
      final closeTime = parse(close);

      final now = TimeOfDay.now();

      final nowMinutes = now.hour * 60 + now.minute;
      final openMinutes = openTime.hour * 60 + openTime.minute;
      final closeMinutes = closeTime.hour * 60 + closeTime.minute;

      return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
    } catch (_) {
      return true;
    }
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: MyText(
        text: text,
        variant: MyTextVariant.bodyBold,
        fontSize: 12,
        customColor: color,
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
                return GestureDetector(
                  onTap: () {
                    showGeneralDialog(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: 'Image',
                      barrierColor: Colors.black,
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (_, __, ___) {
                        return Scaffold(
                          backgroundColor: Colors.black,
                          body: Stack(
                            children: [
                              PageView.builder(
                                controller: PageController(initialPage: i),
                                itemCount: widget.gallery.length,
                                itemBuilder: (_, index) {
                                  return Center(
                                    child: InteractiveViewer(
                                      child: Image.network(
                                        widget.gallery[index],
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              Positioned(
                                top: 40,
                                right: 20,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      transitionBuilder: (_, animation, __, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    );
                  },
                  child: Image.network(
                    widget.gallery[i],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                );
              },
            )
          else
            Container(color: Colors.grey),
          Positioned(
            top: 12,
            left: 18,
            child: SafeArea(
              child: TextButton.icon(
                onPressed: widget.onBack,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                label: const Text('Regresar'),
              ),
            ),
          ),
        ],
      ),
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
        border: Border.all(color: AppColors.headerBottom.withOpacity(0.08)),
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
