import 'package:cloud_firestore/cloud_firestore.dart';

enum UserStatus { idle, searching, matched }

/// Read-only mirror of `users/{uid}`. Every stat here is server-written.
class AppUser {
  const AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.emailVerified,
    required this.goalName,
    required this.timezone,
    required this.status,
    required this.reliability,
    required this.totalCheckins,
    required this.totalExpected,
    required this.missedDays,
    required this.totalPacts,
    required this.longestStreak,
    required this.notificationsEnabled,
    this.avatarUrl,
    this.currentPactId,
  });

  final String uid;
  final String username;
  final String email;
  final bool emailVerified;
  final String goalName;
  final String timezone;
  final UserStatus status;
  final double reliability;
  final int totalCheckins;
  final int totalExpected;
  final int missedDays;
  final int totalPacts;
  final int longestStreak;
  final bool notificationsEnabled;
  final String? avatarUrl;
  final String? currentPactId;

  bool get hasPact => currentPactId != null && currentPactId!.isNotEmpty;
  bool get isSearching => status == UserStatus.searching;
  String get reliabilityLabel => '${reliability.toStringAsFixed(reliability % 1 == 0 ? 0 : 1)}%';

  static AppUser? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return null;
    return AppUser(
      uid: doc.id,
      username: d['username'] as String? ?? '',
      email: d['email'] as String? ?? '',
      emailVerified: d['emailVerified'] as bool? ?? false,
      goalName: d['goalName'] as String? ?? '',
      timezone: d['timezone'] as String? ?? 'UTC',
      status: UserStatus.values.firstWhere(
        (s) => s.name == (d['status'] as String? ?? 'idle'),
        orElse: () => UserStatus.idle,
      ),
      reliability: (d['reliability'] as num? ?? 100).toDouble(),
      totalCheckins: (d['totalCheckins'] as num? ?? 0).toInt(),
      totalExpected: (d['totalExpected'] as num? ?? 0).toInt(),
      missedDays: (d['missedDays'] as num? ?? 0).toInt(),
      totalPacts: (d['totalPacts'] as num? ?? 0).toInt(),
      longestStreak: (d['longestStreak'] as num? ?? 0).toInt(),
      notificationsEnabled: d['notificationsEnabled'] as bool? ?? true,
      avatarUrl: d['avatarUrl'] as String?,
      currentPactId: d['currentPactId'] as String?,
    );
  }
}
