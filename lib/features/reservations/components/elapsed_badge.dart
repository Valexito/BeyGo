import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beygo/features/reservations/reservations.dart';

/// Muestra el tiempo transcurrido desde [start], actualizándose cada segundo.
/// Uso: ElapsedBadge(start: reservation.startedAt)
class ElapsedBadge extends ConsumerWidget {
  const ElapsedBadge({super.key, required this.start, this.compact = false});

  final DateTime start;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Forzamos rebuild cada segundo
    ref.watch(nowTickerProvider);

    final elapsed = DateTime.now().difference(start);
    final text = _fmt(elapsed, compact: compact);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1B3A57).withValues(alpha: .15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF1B3A57)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF1B3A57),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _fmt(Duration d, {bool compact = false}) {
    final totalSeconds = d.inSeconds < 0 ? 0 : d.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (compact && hours == 0) {
      // mm:ss
      return '${_two(minutes)}:${_two(seconds)}';
    }
    // hh:mm:ss
    return '${_two(hours)}:${_two(minutes)}:${_two(seconds)}';
    // Si prefieres "1h 23m 45s", cambia el retorno a:
    // return '${hours}h ${_two(minutes)}m ${_two(seconds)}s';
  }
}
