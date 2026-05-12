// lib/features/owner/pages/owner_reservations_page.dart
//
// ✅ ADDED: Reject button in _OwnerApproveCard (alongside Approve)
// ✅ Uses ownerRejectReservationProvider from reservations_providers.dart
//
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/owner/owner.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/reservations/reservations.dart';

enum OwnerReservationsTab { active, pending }

class OwnerReservationsPage extends ConsumerStatefulWidget {
  final String? initialReservationId;
  final OwnerReservationsTab initialTab;
  final bool initialOpenChat;

  const OwnerReservationsPage({
    super.key,
    this.initialReservationId,
    this.initialTab = OwnerReservationsTab.active,
    this.initialOpenChat = false,
  });

  @override
  ConsumerState<OwnerReservationsPage> createState() =>
      _OwnerReservationsPageState();
}

class _OwnerReservationsPageState extends ConsumerState<OwnerReservationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab == OwnerReservationsTab.active ? 0 : 1,
  );
  bool _handledInitialAction = false;

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(ownerAllReservationsProvider);
    final isDark = context.isDarkMode;

    allAsync.whenData((items) {
      if (_handledInitialAction ||
          widget.initialReservationId == null ||
          widget.initialReservationId!.isEmpty ||
          !widget.initialOpenChat) {
        return;
      }

      final target = items.cast<Reservation?>().firstWhere(
        (reservation) => reservation?.id == widget.initialReservationId,
        orElse: () => null,
      );

      if (target == null) return;

      _handledInitialAction = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showReservationChatSheet(context, reservation: target);
      });
    });

    return OwnerOnly(
      builder:
          (_) => Scaffold(
            backgroundColor: context.appPageBackground,
            body: Column(
              children: [
                const AppHeader(
                  title: 'Reservaciones',
                  subtitle: 'Gestiona tus reservas y solicitudes',
                  showBack: true,
                ),
                Transform.translate(
                  offset: const Offset(0, -8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Material(
                      elevation: isDark ? 0 : 12,
                      color: context.appCardBackground,
                      borderRadius: BorderRadius.circular(24),
                      shadowColor: Colors.black.withValues(
                        alpha: isDark ? 0.24 : 0.10,
                      ),
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.appCardBackground,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: context.appBorderColor),
                        ),
                        child: TabBar(
                          controller: _tab,
                          indicator: BoxDecoration(
                            color:
                                isDark
                                    ? context.appCardBackgroundSoft
                                    : const Color(0xFFEAF0F7),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          labelColor:
                              isDark ? Colors.white : const Color(0xFF1B3A57),
                          unselectedLabelColor: context.appTextSecondaryColor,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'Activas'),
                            Tab(text: 'Solicitadas'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: TabBarView(
                      controller: _tab,
                      children: [
                      // Active
                      allAsync.when(
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        error: (e, _) => Center(child: Text('$e')),
                        data: (items) {
                          final active =
                              items.where((r) => r.state == 'active').toList();
                          final visible =
                              widget.initialReservationId == null
                                  ? active
                                  : [
                                    ...active.where(
                                      (r) =>
                                          r.id == widget.initialReservationId,
                                    ),
                                    ...active.where(
                                      (r) =>
                                          r.id != widget.initialReservationId,
                                    ),
                                  ];
                          if (visible.isEmpty) {
                            return const _EmptyState(
                              icon: Icons.local_parking,
                              title: 'Sin reservas activas',
                              subtitle: 'Las reservas activas aparecerán aquí',
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: visible.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 14),
                            itemBuilder:
                                (_, i) => _ActiveCard(
                                  reservation: visible[i],
                                  highlighted:
                                      visible[i].id ==
                                      widget.initialReservationId,
                                ),
                          );
                        },
                      ),

                      // Pending
                      allAsync.when(
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        error: (e, _) => Center(child: Text('$e')),
                        data: (items) {
                          final pending =
                              items
                                  .where(
                                    (r) =>
                                        r.state == 'pending' &&
                                        r.providerApprovalStatus == 'pending',
                                  )
                                  .toList();
                          final visible =
                              widget.initialReservationId == null
                                  ? pending
                                  : [
                                    ...pending.where(
                                      (r) =>
                                          r.id == widget.initialReservationId,
                                    ),
                                    ...pending.where(
                                      (r) =>
                                          r.id != widget.initialReservationId,
                                    ),
                                  ];
                          if (visible.isEmpty) {
                            return const _EmptyState(
                              icon: Icons.hourglass_empty,
                              title: 'Sin solicitudes',
                              subtitle:
                                  'Las reservas pendientes aparecerán aquí',
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: visible.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 14),
                            itemBuilder:
                                (_, i) => _ApproveCard(
                                  reservation: visible[i],
                                  highlighted:
                                      visible[i].id ==
                                      widget.initialReservationId,
                                ),
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
    );
  }
}

// ─── Active card ─────────────────────────────────────────────────────────
class _ActiveCard extends ConsumerWidget {
  final Reservation reservation;
  final bool highlighted;

  const _ActiveCard({required this.reservation, this.highlighted = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      header: 'No. ${reservation.reservationNumber ?? "N/A"}',
      highlighted: highlighted,
      rows: [
        _Row(Icons.info_outline, 'Estado', 'Activa'),
        _Row(Icons.access_time, 'Inicio', _fmt(reservation.reservedAt)),
        _Row(Icons.person_outline, 'Usuario', reservation.userName ?? 'N/A'),
        _Row(
          Icons.directions_car_outlined,
          'Placa',
          reservation.plate ?? 'N/A',
        ),
        _Row(
          Icons.local_parking_outlined,
          'Espacio',
          '${reservation.spaceNumber}',
        ),
      ],
      actions: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed:
                    () => showReservationChatSheet(
                      context,
                      reservation: reservation,
                    ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: context.appBrandIconColor.withValues(alpha: 0.28),
                  ),
                  backgroundColor:
                      context.isDarkMode
                          ? context.appCardBackgroundSoft
                          : const Color(0xFFF4F7FB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: context.appBrandIconColor,
                ),
                label: Text(
                  'Chat',
                  style: TextStyle(
                    color: context.appBrandTextColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MyButton(
              text: 'Finalizar',
              height: 42,
              margin: EdgeInsets.zero,
              onTap: () async {
                final reason = await _forceCancelDialog(context);
                if (reason == null) return;
                try {
                  await ref.read(ownerForceCancelProvider)(
                    reservation: reservation,
                    reason: reason,
                  );
                } catch (e) {
                  if (context.mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('$e')));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _forceCancelDialog(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => const _ForceCancelDialog(),
    );
  }

  String _fmt(DateTime v) {
    return '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')} '
        '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }
}

class _ForceCancelDialog extends StatefulWidget {
  const _ForceCancelDialog();

  @override
  State<_ForceCancelDialog> createState() => _ForceCancelDialogState();
}

class _ForceCancelDialogState extends State<_ForceCancelDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: context.appCardBackground,
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: context.appBorderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: context.isDarkMode ? 0.28 : 0.10,
                ),
                blurRadius: 36,
                spreadRadius: 2,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _GradHeader(
                'Forzar finalización',
                icon: Icons.flag_rounded,
                topRadius: 34,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.appCardBackgroundSoft,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: context.appBorderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color:
                                  context.isDarkMode
                                      ? Colors.white.withValues(alpha: 0.10)
                                      : AppColors.headerBottom.withValues(
                                        alpha: 0.10,
                                      ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.info_outline_rounded,
                              color:
                                  context.isDarkMode
                                      ? Colors.white
                                      : AppColors.headerBottom,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MyText(
                              text:
                                  'Esta acción cerrará la reservación y notificará al usuario.',
                              variant: MyTextVariant.bodyMuted,
                              fontSize: 12,
                              customColor: context.appTextSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    MyText(
                      text: 'Motivo',
                      variant: MyTextVariant.bodyBold,
                      fontSize: 13,
                      customColor: context.appTextPrimaryColor,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: 'Ej: Usuario no llegó...',
                        filled: true,
                        fillColor: context.appCardBackgroundSoft,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: context.appBorderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: context.appBorderColor),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          borderSide: BorderSide(
                            color: AppColors.headerBottom,
                            width: 1.4,
                          ),
                        ),
                      ),
                      style: TextStyle(color: context.appTextPrimaryColor),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: context.appBrandIconColor.withValues(
                                    alpha: .35,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                backgroundColor: context.appCardBackground,
                              ),
                              child: MyText(
                                text: 'Cancelar',
                                variant: MyTextVariant.normalBold,
                                customColor:
                                    context.isDarkMode
                                        ? context.appBrandTextColor
                                        : AppColors.headerBottom,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MyButton(
                            text: 'Confirmar',
                            height: 46,
                            onTap:
                                () => Navigator.pop(context, _controller.text),
                            margin: EdgeInsets.zero,
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

// ─── Pending approval card — Approve + Reject ─────────────────────────────
class _ApproveCard extends ConsumerStatefulWidget {
  final Reservation reservation;
  final bool highlighted;

  const _ApproveCard({required this.reservation, this.highlighted = false});

  @override
  ConsumerState<_ApproveCard> createState() => _ApproveCardState();
}

class _ApproveCardState extends ConsumerState<_ApproveCard> {
  bool _approving = false;
  bool _rejecting = false;
  bool get _busy => _approving || _rejecting;

  @override
  Widget build(BuildContext context) {
    final approve = ref.read(ownerApproveReservationProvider);
    final reject = ref.read(ownerRejectReservationProvider);

    return _Card(
      header: 'No. ${widget.reservation.reservationNumber ?? "N/A"}',
      highlighted: widget.highlighted,
      rows: [
        _Row(Icons.hourglass_top, 'Estado', 'Pendiente'),
        _Row(
          Icons.person_outline,
          'Usuario',
          widget.reservation.userName ?? 'N/A',
        ),
        _Row(
          Icons.directions_car_outlined,
          'Placa',
          widget.reservation.plate ?? 'N/A',
        ),
        _Row(
          Icons.local_parking_outlined,
          'Espacio',
          '${widget.reservation.spaceNumber}',
        ),
      ],
      actions: Row(
        children: [
          // ── Reject ──────────────────────────────────────────────────────
          Expanded(
            child: SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed:
                    _busy
                        ? null
                        : () async {
                          final ok = await _confirmDialog(
                            context,
                            icon: Icons.cancel_outlined,
                            title: 'Rechazar reserva',
                            message: '¿Rechazar esta solicitud?',
                            confirmText: 'Rechazar',
                            confirmColor: const Color(0xFFDC2626),
                          );
                          if (ok != true || !mounted) return;
                          setState(() => _rejecting = true);
                          try {
                            await reject(reservation: widget.reservation);
                          } catch (e) {
                            if (mounted)
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$e')));
                          } finally {
                            if (mounted) setState(() => _rejecting = false);
                          }
                        },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: const Color(0xFFFEF2F2),
                ),
                child:
                    _rejecting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFDC2626),
                          ),
                        )
                        : const Text(
                          'Rechazar',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Approve ─────────────────────────────────────────────────────
          Expanded(
            child: MyButton(
              text: _approving ? 'Aprobando...' : 'Aprobar',
              height: 44,
              margin: EdgeInsets.zero,
              onTap:
                  _busy
                      ? null
                      : () async {
                        final ok = await _confirmDialog(
                          context,
                          icon: Icons.check_circle_outline_rounded,
                          title: 'Aprobar reserva',
                          message: '¿Aprobar esta solicitud?',
                          confirmText: 'Aprobar',
                        );
                        if (ok != true || !mounted) return;
                        setState(() => _approving = true);
                        try {
                          await approve(reservation: widget.reservation);
                        } catch (e) {
                          if (mounted)
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('$e')));
                        } finally {
                          if (mounted) setState(() => _approving = false);
                        }
                      },
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String confirmText,
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            child: Container(
              decoration: BoxDecoration(
                color: ctx.appCardBackground,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: ctx.appBorderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: ctx.isDarkMode ? 0.28 : 0.10,
                    ),
                    blurRadius: 36,
                    spreadRadius: 2,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GradHeader(title, icon: icon, topRadius: 34),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color:
                                context.isDarkMode
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : (confirmColor ?? AppColors.headerBottom)
                                        .withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  context.isDarkMode
                                      ? Colors.white.withValues(alpha: 0.16)
                                      : (confirmColor ?? AppColors.headerBottom)
                                          .withValues(alpha: 0.16),
                            ),
                          ),
                          child: Icon(
                            icon,
                            color:
                                context.isDarkMode
                                    ? Colors.white
                                    : (confirmColor ?? AppColors.headerBottom),
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 16),
                        MyText(
                          text: message,
                          variant: MyTextVariant.bodyMuted,
                          textAlign: TextAlign.center,
                          fontSize: 13,
                          customColor: ctx.appTextSecondaryColor,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: ctx.appBrandIconColor.withValues(
                                        alpha: .35,
                                      ),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    backgroundColor: ctx.appCardBackground,
                                  ),
                                  child: MyText(
                                    text: 'Cancelar',
                                    variant: MyTextVariant.normalBold,
                                    customColor:
                                        ctx.isDarkMode
                                            ? ctx.appBrandTextColor
                                            : AppColors.headerBottom,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child:
                                  confirmColor != null
                                      ? SizedBox(
                                        height: 46,
                                        child: ElevatedButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: confirmColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: Text(
                                            confirmText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      )
                                      : MyButton(
                                        text: confirmText,
                                        height: 46,
                                        onTap: () => Navigator.pop(ctx, true),
                                        margin: EdgeInsets.zero,
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

// ─── Reusable card shell ──────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String header;
  final List<_Row> rows;
  final Widget actions;
  final bool highlighted;
  const _Card({
    required this.header,
    required this.rows,
    required this.actions,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.appCardBackground,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color:
            highlighted
                ? AppColors.headerBottom.withValues(alpha: 0.45)
                : context.appBorderColor,
        width: highlighted ? 1.6 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: context.isDarkMode ? 0.18 : 0.05,
          ),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        _GradHeader(header, topRadius: 22),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ...rows.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: r,
                ),
              ),
              const SizedBox(height: 6),
              actions,
            ],
          ),
        ),
      ],
    ),
  );
}

class _GradHeader extends StatelessWidget {
  final String label;
  final IconData? icon;
  final double topRadius;
  const _GradHeader(this.label, {this.icon, this.topRadius = 0});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.headerTop, AppColors.headerBottom],
      ),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(topRadius),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: MyText(
            text: label,
            variant: MyTextVariant.bodyBold,
            customColor: Colors.white,
            textAlign: TextAlign.center,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: context.appIconCircleColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: context.appBrandIconColor),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: MyText(
          text: label,
          variant: MyTextVariant.bodyMuted,
          fontSize: 12,
          customColor:
              context.isDarkMode
                  ? context.appBrandTextColor
                  : AppColors.headerBottom,
        ),
      ),
      MyText(
        text: value,
        variant: MyTextVariant.bodyBold,
        fontSize: 13,
        customColor: context.appTextPrimaryColor,
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 40,
          color: context.isDarkMode ? Colors.white : AppColors.headerBottom,
        ),
        const SizedBox(height: 12),
        MyText(text: title, variant: MyTextVariant.bodyBold),
        const SizedBox(height: 6),
        MyText(text: subtitle, variant: MyTextVariant.bodyMuted),
      ],
    ),
  );
}
