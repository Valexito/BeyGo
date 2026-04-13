import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mapbox_api/common/utils/components/ui/my_text.dart';
import 'package:mapbox_api/common/utils/components/ui/navy_header.dart';
import 'package:mapbox_api/features/core/pages/userv/report_problem_page.dart';
import 'package:mapbox_api/features/core/providers/firebase_providers.dart';
import 'package:mapbox_api/features/reservations/components/reservation_card.dart';
import 'package:mapbox_api/features/reservations/models/reservation.dart';
import 'package:mapbox_api/features/reservations/providers/reservations_providers.dart';

class ReservationsPage extends ConsumerStatefulWidget {
  const ReservationsPage({super.key});

  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends ConsumerState<ReservationsPage>
    with SingleTickerProviderStateMixin {
  static const navyBottom = Color(0xFF1B3A57);
  static const bg = Color(0xFFF2F4F7);

  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(firebaseAuthProvider);

    if (auth.currentUser == null) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(
          child: MyText(
            text: 'Inicia sesión para ver tus reservaciones',
            variant: MyTextVariant.body,
          ),
        ),
      );
    }

    final asyncList = ref.watch(userReservationsProvider);
    final controlAsync = ref.watch(userReservationControlProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Stack(
              children: [
                NavyHeader(
                  height: 175,
                  roundedBottom: false,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: MyText(
                        text: 'MIS RESERVACIONES',
                        variant: MyTextVariant.title,
                        textAlign: TextAlign.center,
                        customColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    controlAsync.when(
                      loading: () => const SizedBox(height: 18),
                      error: (_, __) => const SizedBox(height: 18),
                      data: (control) {
                        final used =
                            (control?['cancelAttempts'] as num?)?.toInt() ?? 0;
                        final max = Reservation.maxCancellationAttemptsLimit;
                        final limitReached = used >= max;

                        if (limitReached) {
                          return _HeaderLimitMessage(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ReportProblemPage(),
                                ),
                              );
                            },
                          );
                        }

                        return MyText(
                          text: 'Cancelaciones usadas: $used/$max',
                          variant: MyTextVariant.bodyMuted,
                          textAlign: TextAlign.center,
                          customColor: Colors.white70,
                          fontSize: 13,
                        );
                      },
                    ),
                  ],
                ),
                Positioned(
                  left: 10,
                  top: 14,
                  child: SafeArea(
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
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
                child: _SegmentTabs(controller: _tab),
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -8),
                child: asyncList.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (e, __) => Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: MyText(
                            text: 'Error cargando reservaciones: $e',
                            variant: MyTextVariant.bodyBold,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  data: (all) {
                    String norm(String? s) => (s ?? '').toLowerCase().trim();

                    final active =
                        all.where((r) {
                          final state = norm(r.state);
                          return state == 'active' ||
                              state == 'cancellation_requested' ||
                              state == 'pending';
                        }).toList();

                    final completed =
                        all.where((r) => norm(r.state) == 'completed').toList();

                    final cancelled =
                        all.where((r) => norm(r.state) == 'cancelled').toList();

                    return TabBarView(
                      controller: _tab,
                      children: [
                        _ResList(items: active, stateLabel: 'active'),
                        _ResList(items: completed, stateLabel: 'completed'),
                        _ResList(items: cancelled, stateLabel: 'cancelled'),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderLimitMessage extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderLimitMessage({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          const Text(
            'Has superado el límite de cancelaciones.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: onTap,
            child: const Text(
              'Reporta el problema aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFD6E8FF),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFFD6E8FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  const _SegmentTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    const navyBottom = _ReservationsPageState.navyBottom;

    return Material(
      elevation: 8,
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      shadowColor: navyBottom.withOpacity(0.10),
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: TabBar(
          controller: controller,
          labelPadding: EdgeInsets.zero,
          indicator: BoxDecoration(
            color: const Color(0xFFEAF0F7),
            borderRadius: BorderRadius.circular(18),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: navyBottom,
          unselectedLabelColor: Colors.black54,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Activo'),
            Tab(text: 'Completado'),
            Tab(text: 'Cancelado'),
          ],
        ),
      ),
    );
  }
}

class _ResList extends StatelessWidget {
  final List<Reservation> items;
  final String stateLabel;

  const _ResList({required this.items, required this.stateLabel});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyReservationsState(stateLabel: stateLabel);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) => ReservationCard(reservation: items[i]),
    );
  }
}

class _EmptyReservationsState extends StatelessWidget {
  final String stateLabel;

  const _EmptyReservationsState({required this.stateLabel});

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    IconData icon;

    switch (stateLabel) {
      case 'active':
        title = 'No hay reservaciones activas';
        subtitle = 'Tus reservaciones activas o pendientes aparecerán aquí.';
        icon = Icons.local_parking_outlined;
        break;
      case 'completed':
        title = 'No hay reservaciones completadas';
        subtitle = 'Tu historial de reservaciones finalizadas aparecerá aquí.';
        icon = Icons.task_alt_outlined;
        break;
      default:
        title = 'No hay reservaciones canceladas';
        subtitle = 'Tus reservaciones canceladas aparecerán aquí.';
        icon = Icons.cancel_outlined;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _ReservationsPageState.navyBottom.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 34,
                color: _ReservationsPageState.navyBottom,
              ),
            ),
            const SizedBox(height: 18),
            MyText(
              text: title,
              variant: MyTextVariant.bodyBold,
              fontSize: 17,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            MyText(
              text: subtitle,
              variant: MyTextVariant.bodyMuted,
              fontSize: 14,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
