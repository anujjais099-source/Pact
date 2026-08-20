import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/pact_colors.dart';

enum DayStatus {
  pending('Pending', PactColors.amber, PactColors.amberSoft),
  green('Completed', PactColors.green, PactColors.greenSoft),
  red('Missed', PactColors.red, PactColors.redSoft);

  const DayStatus(this.label, this.color, this.softColor);

  final String label;
  final Color color;
  final Color softColor;

  static DayStatus parse(String? v) => switch (v) {
        'green' => DayStatus.green,
        'red' => DayStatus.red,
        _ => DayStatus.pending,
      };
}

class Proof {
  const Proof({required this.photoUrl, required this.submittedAt});

  final String photoUrl;
  final DateTime? submittedAt;

  static Proof? from(Map<String, dynamic>? m) {
    if (m == null) return null;
    final url = m['photoUrl'] as String?;
    if (url == null || url.isEmpty) return null;
    return Proof(photoUrl: url, submittedAt: (m['submittedAt'] as Timestamp?)?.toDate());
  }
}

/// Mirror of `pacts/{id}/days/{dayKey}` — today's board for both people.
class PactDay {
  const PactDay({
    required this.dayKey,
    required this.statuses,
    required this.proofs,
    required this.resolved,
  });

  final String dayKey;
  final Map<String, DayStatus> statuses;
  final Map<String, Proof> proofs;
  final bool resolved;

  static const PactDay empty = PactDay(
    dayKey: '',
    statuses: {},
    proofs: {},
    resolved: false,
  );

  DayStatus statusOf(String uid) => statuses[uid] ?? DayStatus.pending;
  Proof? proofOf(String uid) => proofs[uid];
  bool didCheckIn(String uid) => statusOf(uid) == DayStatus.green;
  bool get bothGreen => statuses.isNotEmpty && statuses.values.every((s) => s == DayStatus.green);

  static PactDay fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return PactDay.empty;
    final st = (d['statuses'] as Map<String, dynamic>? ?? {});
    final ck = (d['checkins'] as Map<String, dynamic>? ?? {});
    final proofs = <String, Proof>{};
    for (final e in ck.entries) {
      final p = Proof.from((e.value as Map).cast<String, dynamic>());
      if (p != null) proofs[e.key] = p;
    }
    return PactDay(
      dayKey: d['dayKey'] as String? ?? doc.id,
      statuses: {for (final e in st.entries) e.key: DayStatus.parse(e.value as String?)},
      proofs: proofs,
      resolved: d['resolved'] as bool? ?? false,
    );
  }
}
