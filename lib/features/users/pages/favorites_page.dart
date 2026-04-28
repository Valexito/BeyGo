import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:beygo/features/core/core.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/reservations/reservations.dart';
import 'package:beygo/features/users/users.dart';

enum FavFilter { all, rating45, spaces }

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
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
          backgroundColor: context.appPageBackground,
          body: SafeArea(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors:
                              context.isDarkMode
                                  ? const [
                                    Color(0xFF111827),
                                    Color(0xFF0F172A),
                                    Color(0xFF0B1220),
                                  ]
                                  : const [
                                    AppColors.headerTop,
                                    AppColors.headerBottom,
                                  ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: -18,
                      right: -16,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: context.isDarkMode ? 0.04 : 0.09,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 56,
                      left: -18,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: context.isDarkMode ? 0.03 : 0.07,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const Positioned.fill(
                      child: SafeArea(
                        child: Align(
                          alignment: Alignment.center,
                          child: MyText(
                            text: 'FAVORITOS',
                            variant: MyTextVariant.title,
                            textAlign: TextAlign.center,
                            customColor: Colors.white,
                          ),
                        ),
                      ),
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
                        return Center(
                          child: MyText(
                            text: 'No tienes favoritos aún',
                            variant: MyTextVariant.bodyMuted,
                            customColor: context.appTextSecondaryColor,
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
    return Material(
      elevation: context.isDarkMode ? 0 : 8,
      color: context.appCardBackground,
      borderRadius: BorderRadius.circular(24),
      shadowColor: Colors.black.withValues(
        alpha: context.isDarkMode ? 0.18 : 0.10,
      ),
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.appBorderColor),
        ),
        child: TabBar(
          controller: controller,
          labelPadding: EdgeInsets.zero,
          indicator: BoxDecoration(
            color:
                context.isDarkMode
                    ? context.appCardBackgroundSoft
                    : const Color(0xFFEAF0F7),
            borderRadius: BorderRadius.circular(18),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor:
              context.isDarkMode
                  ? Colors.white
                  : const Color(0xFF1B3A57),
          unselectedLabelColor: context.appTextSecondaryColor,
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
    const accentBlue = Color(0xFF2563EB);

    final heroImg =
        item.heroImage ?? 'https://via.placeholder.com/800x450?text=Parqueo';
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
        elevation: context.isDarkMode ? 0 : 4,
        color: context.appCardBackground,
        borderRadius: BorderRadius.circular(18),
        shadowColor: Colors.black.withValues(
          alpha: context.isDarkMode ? 0.16 : 0.10,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: context.appCardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.appBorderColor),
          ),
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
                        color: context.appCardBackground,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color:
                                isFav
                                    ? Colors.red
                                    : context.appTextPrimaryColor,
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

                                    final hasRating = rating > 0;

                                    return _InfoPill(
                                      icon:
                                          hasRating
                                              ? Icons.star_rounded
                                              : Icons.fiber_new_rounded,
                                      text:
                                          hasRating
                                              ? rating.toStringAsFixed(1)
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
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimaryColor,
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
      color: context.appInputBackground,
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
      color: context.appInputBackground,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported,
        color: context.appTextSecondaryColor,
      ),
    );
  }
}

class _OnlyForUsers extends StatelessWidget {
  const _OnlyForUsers({required this.onGoHome});
  final VoidCallback onGoHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      body: Center(
        child: ElevatedButton(
          onPressed: onGoHome,
          child: const Text('Ir a mi inicio'),
        ),
      ),
    );
  }
}
