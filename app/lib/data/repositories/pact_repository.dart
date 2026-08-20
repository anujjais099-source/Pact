import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pact.dart';
import '../models/pact_day.dart';
import '../services/firebase_service.dart';

class MatchOutcome {
  const MatchOutcome({required this.pactId, required this.searching});
  final String? pactId;
  final bool searching;
}

class PactRepository {
  const PactRepository(this._db, this._fn);

  final FirebaseFirestore _db;
  final FirebaseFunctions _fn;

  Stream<Pact?> watch(String pactId) =>
      Paths.pact(_db, pactId).snapshots().map(Pact.fromDoc);

  Stream<PactDay> watchDay(String pactId, String dayKey) =>
      Paths.day(_db, pactId, dayKey).snapshots().map(PactDay.fromDoc);

  /// Last 14 days, newest first — the little dot strip on Home.
  Stream<List<PactDay>> watchRecentDays(String pactId) => Paths.days(_db, pactId)
      .orderBy(FieldPath.documentId, descending: true)
      .limit(14)
      .snapshots()
      .map((s) => s.docs.map(PactDay.fromDoc).toList());

  Stream<bool> watchQueue(String uid) =>
      Paths.queue(_db, uid).snapshots().map((d) => d.exists);

  Future<MatchOutcome> requestMatch() async {
    final res = await _fn.httpsCallable('requestMatch').call<Map<String, dynamic>>();
    final data = res.data;
    return MatchOutcome(
      pactId: data['pactId'] as String?,
      searching: data['status'] == 'searching',
    );
  }

  Future<void> cancelMatch() => _fn.httpsCallable('cancelMatch').call<Map<String, dynamic>>();

  /// QA / support hook — forces the nightly evaluation for one pact.
  Future<void> forceRollover(String pactId) =>
      _fn.httpsCallable('rolloverPactNow').call<Map<String, dynamic>>({'pactId': pactId});
}

final pactRepositoryProvider = Provider<PactRepository>(
  (ref) => PactRepository(ref.watch(firestoreProvider), ref.watch(functionsProvider)),
);
