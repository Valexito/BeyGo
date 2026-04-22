// lib/features/users/models/notification_settings.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSettings {
  final bool enabled;
  final bool reminders;
  final bool updates;
  final bool soundEnabled;

  const NotificationSettings({
    required this.enabled,
    required this.reminders,
    required this.updates,
    required this.soundEnabled,
  });

  factory NotificationSettings.defaults() => const NotificationSettings(
    enabled: true,
    reminders: true,
    updates: true,
    soundEnabled: true,
  );

  factory NotificationSettings.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return NotificationSettings(
      enabled: (d['enabled'] as bool?) ?? true,
      reminders: (d['reminders'] as bool?) ?? true,
      updates: (d['updates'] as bool?) ?? true,
      soundEnabled: (d['soundEnabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'reminders': reminders,
    'updates': updates,
    'soundEnabled': soundEnabled,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  NotificationSettings copyWith({
    bool? enabled,
    bool? reminders,
    bool? updates,
    bool? soundEnabled,
  }) => NotificationSettings(
    enabled: enabled ?? this.enabled,
    reminders: reminders ?? this.reminders,
    updates: updates ?? this.updates,
    soundEnabled: soundEnabled ?? this.soundEnabled,
  );
}
