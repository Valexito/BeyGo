import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mapbox_api/features/core/providers/spaces_provider.dart';

import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/common/utils/components/ui/navy_header.dart';
import 'package:mapbox_api/features/core/providers/favorites_provider.dart';
import 'package:mapbox_api/features/reservations/pages/reserve_space_page.dart';

import 'package:mapbox_api/features/users/providers/user_providers.dart';
import 'package:mapbox_api/features/users/models/user_role.dart';
import 'package:mapbox_api/features/core/pages/home_switch.dart';

enum FavFilter { all, rating45, spaces }

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();

  static const bg = Color(0xFFF2F4F7);
  static const navy = Color(0xFF1B3A57);
}

class _FavoritesPageState extends ConsumerState<FavoritesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  FavFilter _getFilter() {
    switch (_tab.index) {
      case 1:
        return FavFilter.rating45;
      case 2:
        return FavFilter.spaces;
      default:
        return FavFilter.all;
    }
  }

  List<FavoriteItem> _applyFilter(List<FavoriteItem> items, FavFilter f) {
    switch (f) {
      case FavFilter.rating45:
        return items.where((e) => e.rating >= 4.5).toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
      case FavFilter.spaces:
        return items.where((e) => e.spaces > 0).toList();
      case FavFilter.all:
      default:
        return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(myRoleStreamProvider);

    return roleAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error de rol: $e'))),
      data: (role) {
        if (role == UserRole.provider || role == UserRole.admin) {
          return _OnlyForUsers(
            onGoHome: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeSwitch()),
              );
            },
          );
        }

        final asyncFavs = ref.watch(favoritesStreamProvider);
        final filter = _getFilter();

        return Scaffold(
          backgroundColor: FavoritesPage.bg,
          body: SafeArea(
            child: Column(
              children: [
                Stack(
                  children: [
                    const NavyHeader(
                      height: 150,
                      roundedBottom: false,
                      children: [
                        MyText(
                          text: 'FAVORITOS',
                          variant: MyTextVariant.title,
                          textAlign: TextAlign.center,
                          customColor: Colors.white,
                        ),
                      ],
                    ),
                    Positioned(
                      left: 12,
                      top: 10,
                      child: SafeArea(
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                          ),
                          label: const Text('Regresar'),
                        ),
                      ),
                    ),
                  ],
                ),

                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _FavoritesTabs(controller: _tab),
                  ),
                ),

                Expanded(
                  child: asyncFavs.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
                    error:
                        (_, __) => const Center(
                          child: MyText(
                            text: 'Error al cargar favoritos',
                            variant: MyTextVariant.body,
                          ),
                        ),
                    data: (all) {
                      final items = _applyFilter(all, filter);

                      if (items.isEmpty) {
                        return const Center(
                          child: MyText(
                            text: 'No tienes favoritos aún',
                            variant: MyTextVariant.bodyMuted,
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _FavoriteCard(item: items[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FavoritesTabs extends StatelessWidget {
  const _FavoritesTabs({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    const navy = FavoritesPage.navy;

    return Material(
      elevation: 8,
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      shadowColor: navy.withOpacity(0.10),
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(6),
        child: TabBar(
          controller: controller,
          labelPadding: EdgeInsets.zero,
          indicator: BoxDecoration(
            color: const Color(0xFFEAF0F7),
            borderRadius: BorderRadius.circular(18),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: navy,
          unselectedLabelColor: Colors.black54,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Mejor calificados'),
            Tab(text: 'Con espacios'),
          ],
        ),
      ),
    );
  }
}

class _FavoriteCard extends ConsumerWidget {
  final FavoriteItem item;
  const _FavoriteCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const navy = FavoritesPage.navy;
    const accentBlue = Color(0xFF2563EB);

    final heroImg =
        item.heroImage ?? 'https://via.placeholder.com/800x450?text=Parking';
    final hasRating = item.rating > 0;
    final spacesAsync = ref.watch(availableSpacesProvider(item.parkingId));

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        final parking = item.toParking();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReserveSpacePage(parking: parking)),
        );
      },
      child: Material(
        elevation: 4,
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        shadowColor: navy.withOpacity(0.10),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      heroImg,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _ImageFallback(),
                      loadingBuilder:
                          (c, child, p) =>
                              p == null ? child : const _ImageShimmer(),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Consumer(
                    builder: (_, r, __) {
                      final favStream = r.watch(
                        isFavoriteStreamProvider(item.parkingId),
                      );
                      final isFav = favStream.maybeWhen(
                        data: (v) => v,
                        orElse: () => false,
                      );

                      return Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.red : navy,
                          ),
                          onPressed:
                              favStream.isLoading
                                  ? null
                                  : () async {
                                    try {
                                      await r.read(toggleFavoriteProvider)(
                                        toFav: !isFav,
                                        p: item.toParking(),
                                      );
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'No se pudo actualizar favorito',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    text: item.name,
                    variant: MyTextVariant.bodyBold,
                    fontSize: 15,
                  ),
                  if ((item.descripcion ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    MyText(
                      text: item.descripcion!,
                      variant: MyTextVariant.bodyMuted,
                      fontSize: 12,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Column(
                              children: [
                                StreamBuilder<DocumentSnapshot>(
                                  stream:
                                      FirebaseFirestore.instance
                                          .collection('parkings')
                                          .doc(item.parkingId)
                                          .snapshots(),
                                  builder: (context, snapshot) {
                                    final data =
                                        snapshot.data?.data()
                                            as Map<String, dynamic>?;
                                    final rating =
                                        (data?['rating'] is num)
                                            ? (data!['rating'] as num)
                                                .toDouble()
                                            : item.rating;

                                    final hasRating = (rating ?? 0) > 0;

                                    return _InfoPill(
                                      icon:
                                          hasRating
                                              ? Icons.star_rounded
                                              : Icons.fiber_new_rounded,
                                      text:
                                          hasRating
                                              ? rating!.toStringAsFixed(1)
                                              : 'Nuevo',
                                      iconColor:
                                          hasRating
                                              ? Colors.amber.shade700
                                              : accentBlue,
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                spacesAsync.when(
                                  data:
                                      (spaces) => _InfoPill(
                                        icon: Icons.local_parking_rounded,
                                        text: '$spaces disponibles',
                                        iconColor: accentBlue,
                                      ),
                                  loading:
                                      () => const _InfoPill(
                                        icon: Icons.local_parking_rounded,
                                        text: '...',
                                      ),
                                  error:
                                      (_, __) => _InfoPill(
                                        icon: Icons.local_parking_rounded,
                                        text: '${item.spaces} disponibles',
                                        iconColor: accentBlue,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StreamBuilder<DocumentSnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('parkings')
                                  .doc(item.parkingId)
                                  .snapshots(),
                          builder: (context, snapshot) {
                            final data =
                                snapshot.data?.data() as Map<String, dynamic>?;

                            final pricePerHour =
                                (data?['pricePerHour'] is num)
                                    ? (data!['pricePerHour'] as num).toInt()
                                    : ((data?['price'] is num)
                                        ? (data!['price'] as num).toInt()
                                        : 0);

                            final hours =
                                data?['businessHours'] as Map<String, dynamic>?;
                            final open = hours?['open']?.toString();
                            final close = hours?['close']?.toString();

                            final schedule =
                                (open != null &&
                                        open.isNotEmpty &&
                                        close != null &&
                                        close.isNotEmpty)
                                    ? '$open - $close'
                                    : 'Horario no disponible';

                            return Column(
                              children: [
                                _InfoPill(
                                  icon: Icons.attach_money_rounded,
                                  text: 'Q$pricePerHour por hora',
                                  iconColor: accentBlue,
                                ),
                                const SizedBox(height: 8),
                                _InfoPill(
                                  icon: Icons.access_time_rounded,
                                  text: schedule,
                                  iconColor: accentBlue,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;

  const _InfoPill({
    required this.icon,
    required this.text,
    this.iconColor = const Color(0xFF2563EB),
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF334155);

    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
      color: const Color(0xFFE7ECF3),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
}

class _OnlyForUsers extends StatelessWidget {
  const _OnlyForUsers({required this.onGoHome});
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: onGoHome,
          child: const Text('Ir a mi inicio'),
        ),
      ),
    );
  }
}
