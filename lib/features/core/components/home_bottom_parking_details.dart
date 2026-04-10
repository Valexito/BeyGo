// lib/features/home/widgets/home_parking_detail_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_api/features/core/providers/spaces_provider.dart';
import 'package:mapbox_api/common/utils/components/ui/my_button.dart';
import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/features/core/providers/favorites_provider.dart';
import 'package:mapbox_api/features/reservations/models/parking.dart';
import 'package:mapbox_api/features/reservations/pages/reserve_space_page.dart';

class HomeParkingDetailBottomSheet extends ConsumerStatefulWidget {
  final Parking parking;

  /// Props legacy (opcionales). Si las pasas, las usamos como “estado inicial”
  /// mientras el Stream resuelve por 1ª vez.
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
  List<String> get _gallery {
    final g = <String>[];
    if (widget.parking.photos.isNotEmpty) g.addAll(widget.parking.photos);

    final cover = widget.parking.coverUrl ?? widget.parking.imageUrl;
    if (g.isEmpty && (cover ?? '').isNotEmpty) g.add(cover!);

    if (g.isEmpty) {
      g.add('https://via.placeholder.com/800x400?text=Parking');
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
    final gallery = _gallery;
    final hasMultiple = gallery.length > 1;

    // Escucha en tiempo real si este parking es favorito
    final favAsync = ref.watch(isFavoriteStreamProvider(widget.parking.id));
    final spacesAsync = ref.watch(availableSpacesProvider(widget.parking.id));
    final isFav = favAsync.maybeWhen(data: (v) => v, orElse: () => false);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      child: Material(
        color: Colors.white,
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
                  MyText(
                    text: 'Parqueo en ${widget.parking.name}',
                    variant: MyTextVariant.title,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 6),
                  if ((widget.parking.descripcion ?? '').isNotEmpty)
                    MyText(
                      text: widget.parking.descripcion!,
                      variant: MyTextVariant.body,
                      fontSize: 14,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.attach_money,
                        size: 18,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 4),
                      MyText(
                        text: '${_money(widget.parking.price)} / hora',
                        variant: MyTextVariant.bodyBold,
                        fontSize: 16,
                      ),
                      const Spacer(),
                      Icon(Icons.star, size: 18, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 4),
                      MyText(
                        text: (widget.parking.rating ?? 4.5).toStringAsFixed(1),
                        variant: MyTextVariant.bodyBold,
                        fontSize: 14,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.local_parking,
                        size: 18,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 6),
                      spacesAsync.when(
                        data:
                            (spaces) => MyText(
                              text: '$spaces espacios disponibles',
                              variant: MyTextVariant.body,
                              fontSize: 14,
                            ),
                        loading:
                            () => const MyText(
                              text: 'Cargando...',
                              variant: MyTextVariant.body,
                              fontSize: 14,
                            ),
                        error:
                            (_, __) => MyText(
                              text:
                                  '${widget.parking.spaces} espacios disponibles',
                              variant: MyTextVariant.body,
                              fontSize: 14,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 6),
                      MyText(
                        text:
                            '${widget.parking.businessHours?['open'] ?? '--'} - ${widget.parking.businessHours?['close'] ?? '--'}',
                        variant: MyTextVariant.body,
                        fontSize: 14,
                      ),
                      const Spacer(),
                      _buildOpenStatus(),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(height: 1),
                  const SizedBox(height: 18),

                  MyButton(
                    text: 'Reservar espacio',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ReserveSpacePage(parking: widget.parking),
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
