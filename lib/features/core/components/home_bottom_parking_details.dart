import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/reservations/reservations.dart';

class HomeParkingDetailBottomSheet extends ConsumerStatefulWidget {
  final Parking parking;

  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const HomeParkingDetailBottomSheet({
    super.key,
    required this.parking,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  ConsumerState<HomeParkingDetailBottomSheet> createState() =>
      _HomeParkingDetailBottomSheetState();
}

class _HomeParkingDetailBottomSheetState
    extends ConsumerState<HomeParkingDetailBottomSheet> {
  static const navyBottom = Color(0xFF1B3A57);

  late final PageController _pager;
  int _page = 0;
  bool _isToggling = false;

  // Galería a mostrar (1) photos[] (2) coverUrl (3) imageUrl (4) placeholder
  List<String> _galleryFor(Parking parking) {
    final g = <String>[];
    if (parking.photos.isNotEmpty) g.addAll(parking.photos);

    final cover = parking.coverUrl ?? parking.imageUrl;
    if (g.isEmpty && (cover ?? '').isNotEmpty) g.add(cover!);

    if (g.isEmpty) {
      g.add('https://via.placeholder.com/800x400?text=Parqueo');
    }
    return g;
  }

  @override
  void initState() {
    super.initState();
    _pager = PageController();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  String _money(num v) => 'Q${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

  Future<void> _toggleFavorite(bool toFav) async {
    if (_isToggling) return;

    setState(() => _isToggling = true);

    try {
      await ref.read(toggleFavoriteProvider)(toFav: toFav, p: widget.parking);
      widget.onToggleFavorite?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar favorito: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isToggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parkingAsync = ref.watch(parkingStreamProvider(widget.parking.id));
    final currentParking = parkingAsync.asData?.value ?? widget.parking;
    final gallery = _galleryFor(currentParking);
    final hasMultiple = gallery.length > 1;

    // Escucha en tiempo real si este parking es favorito
    final favAsync = ref.watch(isFavoriteStreamProvider(widget.parking.id));
    final spacesAsync = ref.watch(availableSpacesProvider(widget.parking.id));
    final isFav = favAsync.maybeWhen(data: (v) => v, orElse: () => false);
    final rating = (currentParking.rating ?? 0).toDouble();
    final hasRating = rating > 0;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      child: Material(
        color: context.appCardBackground,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== Carrusel =====
            SizedBox(
              width: double.infinity,
              height: 220,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pager,
                    itemCount: gallery.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) {
                      final url = gallery[i];
                      return Image.network(
                        url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, __, ___) => const _ImageFallback(),
                        loadingBuilder: (c, child, progress) {
                          if (progress == null) return child;
                          return const _ImageShimmer();
                        },
                      );
                    },
                  ),

                  // Oscurecer abajo para legibilidad
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black26],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Acciones (fav / cerrar)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      children: [
                        Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 3,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap:
                                (_isToggling || favAsync.isLoading)
                                    ? null
                                    : () => _toggleFavorite(!isFav),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav ? Colors.red : navyBottom,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RoundIcon(
                          icon: Icons.close,
                          color: navyBottom,
                          onTap: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    right: 14,
                    bottom: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(
                            0xFFFCD34D,
                          ).withValues(alpha: 0.45),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            hasRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 18,
                            color:
                                hasRating
                                    ? const Color(0xFFF59E0B)
                                    : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 4),
                          MyText(
                            text:
                                hasRating ? rating.toStringAsFixed(1) : 'Nuevo',
                            variant: MyTextVariant.bodyBold,
                            fontSize: 13,
                            customColor:
                                hasRating
                                    ? const Color(0xFFB45309)
                                    : AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Dots del carrusel
                  if (hasMultiple)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          gallery.length,
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
                ],
              ),
            ),

            // ===== Contenido =====
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MyText(
                              text:
                                  'PARQUEO EN ${currentParking.name.toUpperCase()}',
                              variant: MyTextVariant.title,
                              fontSize: 18,
                            ),
                            const SizedBox(height: 6),
                            if ((currentParking.descripcion ?? '').isNotEmpty)
                              MyText(
                                text: currentParking.descripcion!,
                                variant: MyTextVariant.body,
                                fontSize: 14,
                                customColor: context.appTextSecondaryColor,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: context.appCardBackgroundSoft,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: context.appBorderColor),
                        ),
                        child: Column(
                          children: [_buildOpenStatus(currentParking)],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.appCardBackgroundSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.appBorderColor),
                    ),
                    child: Column(
                      children: [
                        _InfoTile(
                          icon: Icons.directions_car_filled_rounded,
                          iconColor: const Color(0xFF2563EB),
                          label: 'Espacios disponibles',
                          valueWidget: spacesAsync.when(
                            data:
                                (spaces) => MyText(
                                  text: '$spaces espacios',
                                  variant: MyTextVariant.bodyBold,
                                  fontSize: 14,
                                  customColor: context.appTextPrimaryColor,
                                ),
                            loading:
                                () => MyText(
                                  text: 'Cargando...',
                                  variant: MyTextVariant.body,
                                  fontSize: 14,
                                  customColor: context.appTextSecondaryColor,
                                ),
                            error:
                                (_, __) => MyText(
                                  text: '${currentParking.spaces} espacios',
                                  variant: MyTextVariant.bodyBold,
                                  fontSize: 14,
                                  customColor: context.appTextPrimaryColor,
                                ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          icon: Icons.attach_money_rounded,
                          iconColor: const Color(0xFF2563EB),
                          label: 'Precio',
                          valueWidget: MyText(
                            text: '${_money(currentParking.price)} / hora',
                            variant: MyTextVariant.bodyBold,
                            fontSize: 14,
                            customColor: context.appTextPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InfoTile(
                          icon: Icons.schedule_rounded,
                          iconColor: const Color(0xFF2563EB),
                          label: 'Horario',
                          valueWidget: Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${currentParking.businessHours?['open'] ?? '--'} - ${currentParking.businessHours?['close'] ?? '--'}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.appTextPrimaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          color: context.appBorderColor,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.place_rounded,
                          size: 16,
                          color: context.appTextSecondaryColor,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: context.appBorderColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  MyButton(
                    text: 'Reservar espacio',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ReserveSpacePage(parking: currentParking),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
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

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget valueWidget;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MyText(
            text: label,
            variant: MyTextVariant.body,
            fontSize: 13,
            customColor: context.appTextSecondaryColor,
          ),
        ),
        const SizedBox(width: 8),
        valueWidget,
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoundIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

/// Placeholder mientras carga
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

/// Placeholder de error de red / URL
class _ImageFallback extends StatelessWidget {
  const _ImageFallback();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE9EDF3),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported,
        size: 40,
        color: Colors.grey,
      ),
    );
  }
}
