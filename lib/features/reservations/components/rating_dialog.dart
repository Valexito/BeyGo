// lib/features/reservations/components/rating_dialog.dart
//
// Shows a rating dialog after the owner confirms a user's exit.
// Call showRatingDialog() from reservation_details_sheet.dart
// when the reservation transitions to 'completed'.
//
// Saves:
//   • parkings/{id}/reviews/{uid}  → individual review
//   • parkings/{id}               → rating (avg) + totalReviews (updated)
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:beygo/common/common.dart';
import 'package:beygo/features/reservations/reservations.dart';

/// Show the rating dialog. Returns true if rating was submitted.
Future<bool> showRatingDialog(
  BuildContext context, {
  required Reservation reservation,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RatingDialog(reservation: reservation),
  );
  return result == true;
}

class _RatingDialog extends StatefulWidget {
  final Reservation reservation;
  const _RatingDialog({required this.reservation});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  double _parkingRating = 0;
  double _serviceRating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  double get _avgRating =>
      _parkingRating > 0 && _serviceRating > 0
          ? (_parkingRating + _serviceRating) / 2
          : 0;

  bool get _canSubmit =>
      _parkingRating > 0 && _serviceRating > 0 && !_submitting;

  Future<void> _skip() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservation.id)
          .set({
            'ratingPromptHandled': true,
            'ratingSubmitted': false,
            'ratingSkippedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) Navigator.of(context).pop(false);
    } catch (e) {
      debugPrint('[Rating] Skip error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo omitir la calificación: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final parkingId = widget.reservation.parkingId;
      if (uid == null || parkingId.isEmpty) return;

      final db = FirebaseFirestore.instance;
      final parkingRef = db.collection('parkings').doc(parkingId);
      final reviewRef = parkingRef.collection('reviews').doc(
        widget.reservation.id,
      );

      // Write the individual review
      await reviewRef.set({
        'uid': uid,
        'reservationId': widget.reservation.id,
        'parkingRating': _parkingRating,
        'serviceRating': _serviceRating,
        'rating': _avgRating,
        'comment': _commentCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await db.collection('reservations').doc(widget.reservation.id).set({
        'ratingPromptHandled': true,
        'ratingSubmitted': true,
        'ratingSubmittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Recalculate overall rating from all reviews
      final reviewsSnap = await parkingRef.collection('reviews').get();
      final ratings =
          reviewsSnap.docs
              .map((d) => (d.data()['rating'] as num?)?.toDouble() ?? 0.0)
              .where((r) => r > 0)
              .toList();

      if (ratings.isNotEmpty) {
        final avg = ratings.reduce((a, b) => a + b) / ratings.length;
        await parkingRef.set({
          'rating': double.parse(avg.toStringAsFixed(1)),
          'totalReviews': ratings.length,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[Rating] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar la calificación: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: context.appCardBackground,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDarkMode ? 0.24 : 0.16,
              ),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors:
                      context.isDarkMode
                          ? const [
                            Color(0xFF1E3A5F),
                            Color(0xFF0F172A),
                          ]
                          : const [
                            AppColors.headerTop,
                            AppColors.headerBottom,
                          ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.26),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const MyText(
                    text: '¡Califica tu experiencia!',
                    variant: MyTextVariant.bodyBold,
                    customColor: Colors.white,
                    textAlign: TextAlign.center,
                    fontSize: 18,
                  ),
                  const SizedBox(height: 4),
                  MyText(
                    text: widget.reservation.parkingName,
                    variant: MyTextVariant.bodyMuted,
                    customColor: Colors.white70,
                    textAlign: TextAlign.center,
                    fontSize: 13,
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parking quality
                  _StarSection(
                    label: 'Calidad del parqueo',
                    icon: Icons.local_parking_outlined,
                    rating: _parkingRating,
                    onChanged: (v) => setState(() => _parkingRating = v),
                  ),
                  const SizedBox(height: 18),

                  // Service quality
                  _StarSection(
                    label: 'Servicio del dueño',
                    icon: Icons.person_outline_rounded,
                    rating: _serviceRating,
                    onChanged: (v) => setState(() => _serviceRating = v),
                  ),
                  const SizedBox(height: 18),

                  // Average chip
                  if (_avgRating > 0) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.headerBottom.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFBBF24),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Promedio: ${_avgRating.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.headerBottom,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Comment (optional)
                  TextField(
                    controller: _commentCtrl,
                    maxLines: 2,
                    maxLength: 200,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Comentario opcional...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: context.appTextSecondaryColor,
                      ),
                      filled: true,
                      fillColor: context.appInputBackground,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      counterStyle: const TextStyle(fontSize: 10),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed:
                                _submitting ? null : _skip,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.headerBottom.withValues(
                                  alpha: 0.35,
                                ),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              backgroundColor: context.appCardBackground,
                            ),
                            child: const MyText(
                              text: 'Omitir',
                              variant: MyTextVariant.normalBold,
                              customColor: AppColors.headerBottom,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MyButton(
                          text: _submitting ? 'Enviando...' : 'Calificar',
                          onTap: _canSubmit ? _submit : null,
                          margin: EdgeInsets.zero,
                          height: 48,
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

// ─── Star rating row ──────────────────────────────────────────────────────
class _StarSection extends StatelessWidget {
  final String label;
  final IconData icon;
  final double rating;
  final ValueChanged<double> onChanged;

  const _StarSection({
    required this.label,
    required this.icon,
    required this.rating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color:
                    context.isDarkMode
                        ? context.appIconCircleColor
                        : AppColors.headerBottom.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: AppColors.headerBottom),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final starVal = i + 1.0;
            return GestureDetector(
              onTap: () => onChanged(starVal),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  rating >= starVal
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 36,
                  color:
                      rating >= starVal
                          ? const Color(0xFFFBBF24)
                          : context.appBorderColor,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
