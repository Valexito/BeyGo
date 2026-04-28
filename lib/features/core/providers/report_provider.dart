import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

final submitReportProvider = Provider<
  Future<String> Function({
    required String reportType,
    required String subject,
    required String message,
    required String? email,
  })
>((ref) {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  return ({
    required String reportType,
    required String subject,
    required String message,
    required String? email,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final reportId = const Uuid().v4();
    final reportNumber = 'REP-${reportId.split('-').first.toUpperCase()}';

    await db.collection('support_reports').doc(reportId).set({
      'reportId': reportId,
      'reportNumber': reportNumber,
      'userId': user.uid,
      'userEmail': email ?? user.email,
      'reportType': reportType,
      'subject': subject,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return reportNumber;
  };
});
