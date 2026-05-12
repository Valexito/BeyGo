import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/core/core.dart';
import 'package:beygo/features/reservations/models/reservation.dart';
import 'package:beygo/features/reservations/models/reservation_chat_message.dart';
import 'package:beygo/features/reservations/providers/reservation_chat_providers.dart';

Future<void> showReservationChatSheet(
  BuildContext context, {
  required Reservation reservation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReservationChatSheet(reservation: reservation),
  );
}

class ReservationChatSheet extends ConsumerStatefulWidget {
  final Reservation reservation;

  const ReservationChatSheet({super.key, required this.reservation});

  @override
  ConsumerState<ReservationChatSheet> createState() =>
      _ReservationChatSheetState();
}

class _ReservationChatSheetState extends ConsumerState<ReservationChatSheet> {
  late final TextEditingController _controller;
  bool _sending = false;

  Color get _chatAccent =>
      context.isDarkMode ? const Color(0xFF3B82F6) : const Color(0xFF315EA8);

  Color get _chatSoft =>
      context.isDarkMode ? const Color(0xFF172036) : const Color(0xFFEAF1FF);

  bool get _chatEnabled {
    final state = widget.reservation.state.toLowerCase().trim();
    return state == 'pending' ||
        state == 'active' ||
        state == 'cancellation_requested';
  }

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

  Future<void> _send() async {
    if (_sending) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await ref.read(sendReservationChatMessageProvider)(
        reservation: widget.reservation,
        text: text,
      );
      if (!mounted) return;
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      reservationChatMessagesProvider(widget.reservation.id),
    );
    final auth = ref.watch(firebaseAuthProvider);
    final currentUid = auth.currentUser?.uid ?? '';
    final peerLabel =
        currentUid == widget.reservation.ownerId ? 'usuario' : 'dueño';

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDarkMode ? 0.24 : 0.12,
              ),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                decoration: BoxDecoration(
                  color: context.appBorderColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors:
                              context.isDarkMode
                                  ? const [Color(0xFF1E3A5F), Color(0xFF0F172A)]
                                  : const [
                                    Color(0xFF4C7FD1),
                                    Color(0xFF315EA8),
                                  ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(
                            text: 'Chat de reservación',
                            variant: MyTextVariant.bodyBold,
                            fontSize: 18,
                            customColor: context.appTextPrimaryColor,
                          ),
                          const SizedBox(height: 2),
                          MyText(
                            text:
                                '${widget.reservation.parkingName} · Espacio ${widget.reservation.spaceNumber}',
                            variant: MyTextVariant.bodyMuted,
                            fontSize: 12,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      context.isDarkMode
                          ? context.appCardBackgroundSoft
                          : _chatSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.appBorderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: context.appTextSecondaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _chatEnabled
                            ? 'Conversación directa con el $peerLabel mientras la reservación esté activa.'
                            : 'La conversación está cerrada porque la reservación ya no está activa.',
                        style: TextStyle(
                          color: context.appTextSecondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: messagesAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (e, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No se pudo cargar el chat: $e',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color:
                                            context.isDarkMode
                                                ? context.appIconCircleColor
                                                : _chatSoft,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.mark_chat_unread_outlined,
                                        color: _chatAccent,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    MyText(
                                      text: 'Todavía no hay mensajes',
                                      variant: MyTextVariant.bodyBold,
                                      textAlign: TextAlign.center,
                                      fontSize: 16,
                                    ),
                                    const SizedBox(height: 8),
                                    MyText(
                                      text:
                                          'Usa este espacio para coordinar detalles rápidos de la reservación.',
                                      variant: MyTextVariant.bodyMuted,
                                      textAlign: TextAlign.center,
                                      fontSize: 13,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }

                    final display = messages.reversed.toList(growable: false);
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      itemCount: display.length,
                      itemBuilder: (context, index) {
                        final message = display[index];
                        final isMine = message.senderId == currentUid;
                        return _ChatBubble(
                          message: message,
                          isMine: isMine,
                          reservation: widget.reservation,
                        );
                      },
                    );
                  },
                ),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 10,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: context.appInputBackground,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color:
                                context.isDarkMode
                                    ? context.appBorderColor
                                    : _chatAccent.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            inputDecorationTheme: const InputDecorationTheme(
                              isCollapsed: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 4,
                              enabled: _chatEnabled && !_sending,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration.collapsed(
                                hintText:
                                    _chatEnabled
                                        ? 'Escribe un mensaje...'
                                        : 'Chat no disponible',
                                hintStyle: TextStyle(
                                  color: context.appTextSecondaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: TextStyle(
                                color: context.appTextPrimaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _chatEnabled && !_sending ? _send : null,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _chatAccent,
                          disabledBackgroundColor:
                              _chatAccent.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child:
                            _sending
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(
                                  Icons.send_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
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
}

class _ChatBubble extends StatelessWidget {
  final ReservationChatMessage message;
  final bool isMine;
  final Reservation reservation;

  const _ChatBubble({
    required this.message,
    required this.isMine,
    required this.reservation,
  });

  @override
  Widget build(BuildContext context) {
    final chatAccent =
        context.isDarkMode ? const Color(0xFF3B82F6) : const Color(0xFF315EA8);
    final chatSoft =
        context.isDarkMode ? context.appCardBackgroundSoft : const Color(0xFFEAF1FF);
    final bubbleColor =
        isMine
            ? chatAccent
            : chatSoft;

    final textColor =
        isMine ? Colors.white : context.appTextPrimaryColor;

    final senderLabel =
        message.senderId == reservation.ownerId ? 'Dueño' : 'Usuario';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 6),
            bottomRight: Radius.circular(isMine ? 6 : 18),
          ),
          border:
              isMine
                  ? null
                  : Border.all(color: context.appBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              senderLabel,
              style: TextStyle(
                color:
                    isMine
                        ? Colors.white.withValues(alpha: 0.86)
                        : context.appTextSecondaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.text,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatTime(message.createdAt),
                style: TextStyle(
                  color:
                      isMine
                          ? Colors.white.withValues(alpha: 0.72)
                          : context.appTextSecondaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
