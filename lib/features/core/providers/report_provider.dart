import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:beygo/features/core/providers/firebase_providers.dart';

class SubmitReportException implements Exception {
  final String userMessage;

  const SubmitReportException(this.userMessage);

  @override
  String toString() => userMessage;
}

final submitReportProvider = Provider<
  Future<String> Function({
    required String reportType,
    required String subject,
    required String message,
    required String? email,
    required List<Uint8List> screenshots,
  })
>((ref) {
  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final storage = ref.watch(storageProvider);

  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  DateTime _monthStart(DateTime date) => DateTime(date.year, date.month, 1);

  return ({
    required String reportType,
    required String subject,
    required String message,
    required String? email,
    required List<Uint8List> screenshots,
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      throw const SubmitReportException('Debes iniciar sesión para enviar un reporte.');
    }

    final cleanSubject = subject.trim();
    final cleanMessage = message.trim();
    if (cleanSubject.isEmpty || cleanMessage.isEmpty) {
      throw const SubmitReportException(
        'Completa el asunto y la descripción del reporte.',
      );
    }
    if (screenshots.length > 3) {
      throw const SubmitReportException(
        'Solo puedes adjuntar hasta 3 capturas.',
      );
    }

    final userSnap = await db.collection('users').doc(user.uid).get();
    final userData = userSnap.data() ?? <String, dynamic>{};
    final role = '${userData['role'] ?? 'user'}'.trim().toLowerCase();
    final monthlyLimit = role == 'provider' ? 15 : 10;
    final now = DateTime.now();
    final monthKey = _monthKey(now);
    final monthStart = _monthStart(now);
    final quotaRef = db
        .collection('users')
        .doc(user.uid)
        .collection('support_report_limits')
        .doc(monthKey);

    final quotaSnap = await quotaRef.get();
    final currentCount = (quotaSnap.data()?['usedReports'] as num?)?.toInt() ?? 0;
    if (currentCount >= monthlyLimit) {
      throw SubmitReportException(
        'Ya alcanzaste tu límite mensual de reportes ($monthlyLimit). '
        'Podrás enviar más el próximo mes.',
      );
    }

    final reportId = const Uuid().v4();
    final reportNumber = 'REP-${reportId.split('-').first.toUpperCase()}';
    final uploadedRefs = <Reference>[];
    final screenshotUrls = <String>[];

    try {
      for (var i = 0; i < screenshots.length; i++) {
        final refSt = storage.ref(
          'support_reports/${user.uid}/$reportId/screenshot_${i + 1}.jpg',
        );
        uploadedRefs.add(refSt);
        await refSt.putData(
          screenshots[i],
          SettableMetadata(contentType: 'image/jpeg'),
        );
        screenshotUrls.add(await refSt.getDownloadURL());
      }

      await db.runTransaction((tx) async {
        final latestQuotaSnap = await tx.get(quotaRef);
        final latestCount =
            (latestQuotaSnap.data()?['usedReports'] as num?)?.toInt() ?? 0;
        if (latestCount >= monthlyLimit) {
          throw SubmitReportException(
            'Ya alcanzaste tu límite mensual de reportes ($monthlyLimit). '
            'Podrás enviar más el próximo mes.',
          );
        }

        tx.set(db.collection('support_reports').doc(reportId), {
          'reportId': reportId,
          'reportNumber': reportNumber,
          'userId': user.uid,
          'userEmail': email ?? user.email,
          'reportType': reportType,
          'subject': cleanSubject,
          'message': cleanMessage,
          'screenshotUrls': screenshotUrls,
          'screenshotCount': screenshotUrls.length,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.set(quotaRef, {
          'monthKey': monthKey,
          'usedReports': latestCount + 1,
          'limit': monthlyLimit,
          'roleSnapshot': role,
          'periodStart': Timestamp.fromDate(monthStart),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt':
              latestQuotaSnap.exists
                  ? (latestQuotaSnap.data()?['createdAt'] ??
                      FieldValue.serverTimestamp())
                  : FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } on SubmitReportException {
      rethrow;
    } on FirebaseException catch (e) {
      for (final refSt in uploadedRefs) {
        try {
          await refSt.delete();
        } catch (_) {}
      }
      throw SubmitReportException(
        e.message?.trim().isNotEmpty == true
            ? e.message!.trim()
            : 'No se pudo enviar el reporte en este momento.',
      );
    } catch (e) {
      for (final refSt in uploadedRefs) {
        try {
          await refSt.delete();
        } catch (_) {}
      }
      if (e is SubmitReportException) rethrow;
      throw SubmitReportException('No se pudo enviar el reporte en este momento.');
    }

    return reportNumber;
  };
});
