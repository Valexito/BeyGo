import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/reservations/reservations.dart';
import 'package:beygo/features/users/users.dart';

class ReserveSpaceContent extends ConsumerStatefulWidget {
  final Parking parking;
  final List<String> gallery;
  final int? selectedSpace;
  final bool isSubmitting;
  final AsyncValue<List<Vehicle>> vehiclesAsync;
  final Vehicle? selectedVehicle;
  final ValueChanged<List<Vehicle>> onPickVehicle;
  final Function(int) onSelectSpace;
  final VoidCallback onConfirm;

  const ReserveSpaceContent({
    super.key,
    required this.parking,
    required this.gallery,
    required this.selectedSpace,
    required this.isSubmitting,
    required this.vehiclesAsync,
    required this.selectedVehicle,
    required this.onPickVehicle,
    required this.onSelectSpace,
    required this.onConfirm,
  });

  @override
  ConsumerState<ReserveSpaceContent> createState() =>
      _ReserveSpaceContentState();
}

class _ReserveSpaceContentState extends ConsumerState<ReserveSpaceContent> {
  int _headerPage = 0;

  void _openGallery([int? initialPage]) {
    if (widget.gallery.isEmpty) return;
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) {
          return _FullscreenGalleryDialog(
            gallery: widget.gallery,
            initialPage: initialPage ?? _headerPage,
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeTop = MediaQuery.of(context).padding.top;
    const headerActionHeight = 54.0;
    final heroVisibleHeight = screenHeight * 0.25;
    final galleryTapTop = safeTop + headerActionHeight;
    final galleryTapHeight = (heroVisibleHeight - galleryTapTop).clamp(
      0.0,
      260.0,
    );

    final cross =
        w >= 520
            ? 5
            : w >= 390
            ? 4
            : 3;

    final parkingAsync = ref.watch(parkingStreamProvider(widget.parking.id));
    final currentParking = parkingAsync.asData?.value ?? widget.parking;
    final spacesAsync = ref.watch(parkingSpacesProvider(widget.parking.id));

    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: Stack(
        children: [
          Column(
            children: [
              _ReservationHeader(
                gallery: widget.gallery,
                onBack: () => Navigator.pop(context),
                onPageChanged: (page) => _headerPage = page,
                onOpenGallery: _openGallery,
              ),
            ],
          ),

          DraggableScrollableSheet(
            initialChildSize: 0.84,
            minChildSize: 0.84,
            maxChildSize: 0.86,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: context.appSectionBackground,
                  borderRadius: const BorderRadius.only(
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
                                18,
                                20,
                                10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: MyText(
                                          text: 'Reservar espacio',
                                          variant: MyTextVariant.title,
                                          customColor:
                                              context.isDarkMode
                                                  ? Colors.white
                                                  : AppColors.headerBottom,
                                          fontSize: 22,
                                        ),
                                      ),
                                      _buildOpenStatus(currentParking),
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
                                                    (s) =>
                                                        s.status
                                                            .toLowerCase()
                                                            .trim() ==
                                                        'free',
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
                                        label:
                                            'Q${currentParking.pricePerHour}/h',
                                      ),
                                      _InfoChip(
                                        icon: Icons.access_time_rounded,
                                        label:
                                            '${currentParking.businessHours?['open'] ?? '--'} - ${currentParking.businessHours?['close'] ?? '--'}',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  widget.vehiclesAsync.when(
                                    loading:
                                        () => const _VehicleSelectorCard(
                                          icon: Icons.directions_car_rounded,
                                          title: 'Vehículo',
                                          subtitle: 'Cargando vehículos...',
                                        ),
                                    error:
                                        (_, __) => _VehicleSelectorCard(
                                          icon: Icons.error_outline_rounded,
                                          title: 'Vehículo',
                                          subtitle:
                                              'No se pudieron cargar tus vehículos',
                                        ),
                                    data: (vehicles) {
                                      final selected = widget.selectedVehicle;
                                      final subtitle =
                                          vehicles.isEmpty
                                              ? 'Agrega un vehículo para continuar'
                                              : selected == null
                                              ? 'Selecciona el vehículo a usar'
                                              : '${selected.plate} • ${selected.type.label}';

                                      return _VehicleSelectorCard(
                                        icon: Icons.directions_car_rounded,
                                        title: 'Vehículo para esta reserva',
                                        subtitle: subtitle,
                                        onTap:
                                            () =>
                                                widget.onPickVehicle(vehicles),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: context.appCardBackground,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: context.appBorderColor,
                                  ),
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
                                        _LegendDot(
                                          color: Color(0xFFF59E0B),
                                          label: 'Solicitado',
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
                                            final status =
                                                (space?.status ?? 'free')
                                                    .toLowerCase()
                                                    .trim();
                                            final occupied =
                                                status == 'occupied';
                                            final requested =
                                                status == 'requested' ||
                                                status == 'pending' ||
                                                status == 'solicitado';
                                            final selectable =
                                                !occupied &&
                                                !requested &&
                                                !widget.isSubmitting;
                                            final selected =
                                                selectable &&
                                                widget.selectedSpace == num;

                                            return _SpaceTile(
                                              number: num,
                                              occupied: occupied,
                                              requested: requested,
                                              selected: selected,
                                              onTap:
                                                  selectable
                                                      ? () => widget
                                                          .onSelectSpace(num)
                                                      : null,
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
                                        ? AppColors.headerBottom.withValues(
                                          alpha: 0.12,
                                        )
                                        : context.appInputBackground,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.headerBottom.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.directions_car_rounded,
                                    size: 18,
                                    color:
                                        context.isDarkMode
                                            ? Colors.white
                                            : context.appBrandIconColor,
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
                                        if (!_isParkingOpen(currentParking)) {
                                          showDialog(
                                            context: context,
                                            builder:
                                                (_) => Dialog(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          20,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          context
                                                              .appCardBackground,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .access_time_rounded,
                                                          size: 40,
                                                          color:
                                                              AppColors
                                                                  .headerBottom,
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        const MyText(
                                                          text:
                                                              'Fuera de horario',
                                                          variant:
                                                              MyTextVariant
                                                                  .title,
                                                          fontSize: 18,
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        const MyText(
                                                          text:
                                                              'El parqueo se encuentra fuera de horario de servicio. Intenta en horas regulares.',
                                                          variant:
                                                              MyTextVariant
                                                                  .bodyMuted,
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                        const SizedBox(
                                                          height: 16,
                                                        ),
                                                        SizedBox(
                                                          width:
                                                              double.infinity,
                                                          child: MyButton(
                                                            text: 'Entendido',
                                                            onTap:
                                                                () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                    ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
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
          if (widget.gallery.isNotEmpty && galleryTapHeight > 0)
            Positioned(
              top: galleryTapTop,
              left: 0,
              right: 0,
              height: galleryTapHeight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openGallery(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOpenStatus(Parking parking) {
    try {
      final open = parking.businessHours?['open'];
      final close = parking.businessHours?['close'];

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

  bool _isParkingOpen(Parking parking) {
    try {
      final open = parking.businessHours?['open'];
      final close = parking.businessHours?['close'];

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
        color: color.withValues(alpha: 0.1),
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

class _VehicleSelectorCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _VehicleSelectorCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appCardBackground,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.appBorderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.appIconCircleColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color:
                      context.isDarkMode
                          ? Colors.white
                          : context.appBrandIconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTextSecondaryColor,
                      ),
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

class _ReservationHeader extends StatefulWidget {
  final List<String> gallery;
  final VoidCallback onBack;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onOpenGallery;

  const _ReservationHeader({
    required this.gallery,
    required this.onBack,
    required this.onPageChanged,
    required this.onOpenGallery,
  });

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
              onPageChanged: (value) {
                setState(() => _page = value);
                widget.onPageChanged(value);
              },
              itemBuilder: (_, i) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onOpenGallery(i),
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
            Container(color: context.appInputBackground),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.20),
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.28),
                  ],
                ),
              ),
            ),
          ),
          if (hasGallery)
            Positioned(
              right: 18,
              bottom: 18,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.photo_library_outlined,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_page + 1}/${widget.gallery.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: const Icon(
                      Icons.open_in_full_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
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

class _FullscreenGalleryDialog extends StatefulWidget {
  final List<String> gallery;
  final int initialPage;

  const _FullscreenGalleryDialog({
    required this.gallery,
    required this.initialPage,
  });

  @override
  State<_FullscreenGalleryDialog> createState() =>
      _FullscreenGalleryDialogState();
}

class _FullscreenGalleryDialogState extends State<_FullscreenGalleryDialog> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _controller = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.gallery.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (_, index) {
              return Center(
                child: InteractiveViewer(
                  minScale: 0.9,
                  maxScale: 4.0,
                  child: Image.network(
                    widget.gallery[index],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 34,
            left: 18,
            right: 18,
            child: SafeArea(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.36),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Text(
                      'Foto ${_page + 1} de ${widget.gallery.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.36),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed:
                          () => Navigator.of(context, rootNavigator: true).pop(),
                    ),
                  ),
                ],
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
        color: context.appCardBackgroundSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.headerBottom.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkMode ? 0.14 : 0.06,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color:
                context.isDarkMode ? Colors.white : AppColors.headerBottom,
          ),
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
  final bool requested;
  final bool selected;
  final VoidCallback? onTap;

  const _SpaceTile({
    required this.number,
    required this.occupied,
    required this.requested,
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
            : requested
            ? BoxDecoration(
              color: context.appCardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.6),
            )
            : selected
            ? BoxDecoration(
              color: AppColors.headerBottom,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.headerBottom.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            )
            : BoxDecoration(
              color: context.appCardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
            );

    final Color iconColor =
        occupied
            ? context.appTextSecondaryColor
            : requested
            ? const Color(0xFFF59E0B)
            : selected
            ? Colors.white
            : context.appTextPrimaryColor;

    final Color labelColor =
        occupied
            ? context.appTextSecondaryColor
            : requested
            ? const Color(0xFFF59E0B)
            : selected
            ? Colors.white
            : context.appTextPrimaryColor;

    return Opacity(
      opacity: occupied ? 0.9 : 1,
      child: Material(
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
        MyText(
          text: label,
          variant: MyTextVariant.body,
          fontSize: 12,
          customColor: context.appTextPrimaryColor,
        ),
      ],
    );
  }
}
