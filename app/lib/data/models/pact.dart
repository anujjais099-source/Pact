import 'package:cloud_firestore/cloud_firestore.dart';

import 'pact_level.dart';

enum PactStatus { active, broken, ended }

class MemberInfo {
  const MemberInfo({
    required this.uid,
    required this.username,
    required this.goalName,
    required this.reliability,
    this.avatarUrl,
  });

  final String uid;
  final String username;
  final String goalName;
  final double reliability;
  final String? avatarUrl;

  String get reliabilityLabel =>
      '${reliability.toStringAsFixed(reliability % 1 == 0 ? 0 : 1)}%';

  static MemberInfo from(String uid, Map<String, dynamic>? m) => MemberInfo(
        uid: uid,
        username: m?['username'] as String? ?? 'Stranger',
        goalName: m?['goalName'] as String? ?? 'Their goal',
        reliability: (m?['reliability'] as num? ?? 100).toDouble(),
        avatarUrl: m?['avatarUrl'] as String?,
      );
}

/// Mirror of `pacts/{id}`. The partner is read from [memberInfo] — their user
/// document is deliberately unreadable to us.
class Pact {
  const Pact({
    required this.id,
    required this.members,
    required this.memberInfo,
    required this.status,
    required this.streak,
    required this.longestStreak,
    required this.timezone,
    required this.startDayKey,
    required this.daysTogether,
    required this.brokenBy,
    this.brokenAt,
  });

  final String id;
  final List<String> members;
  final Map<String, MemberInfo> memberInfo;
  final PactStatus status;
  final int streak;
  final int longestStreak;
  final String timezone;
  final String startDayKey;
  final int daysTogether;
  final List<String> brokenBy;
  final DateTime? brokenAt;

  PactLevel get level => PactLevel.forStreak(streak);
  bool get isActive => status == PactStatus.active;
  bool get isBroken => status == PactStatus.broken;

  MemberInfo partnerOf(String uid) {
    final other = members.firstWhere((m) => m != uid, orElse: () => uid);
    return memberInfo[other] ?? MemberInfo.from(other, null);
  }

  MemberInfo meIn(String uid) => memberInfo[uid] ?? MemberInfo.from(uid, null);
  bool brokenByMe(String uid) => brokenBy.contains(uid);

  static Pact? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return null;
    final raw = (d['memberInfo'] as Map<String, dynamic>? ?? {});
    return Pact(
      id: doc.id,
      members: (d['members'] as List? ?? []).cast<String>(),
      memberInfo: {
        for (final e in raw.entries)
          e.key: MemberInfo.from(e.key, (e.value as Map).cast<String, dynamic>()),
      },
      status: PactStatus.values.firstWhere(
        (s) => s.name == (d['status'] as String? ?? 'active'),
        orElse: () => PactStatus.active,
      ),
      streak: (d['streak'] as num? ?? 0).toInt(),
      longestStreak: (d['longestStreak'] as num? ?? 0).toInt(),
      timezone: d['timezone'] as String? ?? 'UTC',
      startDayKey: d['startDayKey'] as String? ?? '',
      daysTogether: (d['daysTogether'] as num? ?? 1).toInt(),
      brokenBy: (d['brokenBy'] as List? ?? []).cast<String>(),
      brokenAt: (d['brokenAt'] as Timestamp?)?.toDate(),
    );
  }
}
