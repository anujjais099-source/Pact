import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single seam between the app and Firebase. Swap these overrides in tests or
/// point them at the emulator suite; nothing else in the app knows Firebase
/// exists by name.
final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);
final storageProvider = Provider<FirebaseStorage>((_) => FirebaseStorage.instance);
final messagingProvider = Provider<FirebaseMessaging>((_) => FirebaseMessaging.instance);
final analyticsProvider = Provider<FirebaseAnalytics>((_) => FirebaseAnalytics.instance);

final functionsProvider = Provider<FirebaseFunctions>(
  (_) => FirebaseFunctions.instanceFor(region: 'us-central1'),
);

/// Thin analytics wrapper so screens never import Firebase directly.
class PactAnalytics {
  const PactAnalytics(this._analytics);
  final FirebaseAnalytics _analytics;

  Future<void> log(String name, [Map<String, Object>? params]) =>
      _analytics.logEvent(name: name, parameters: params);

  Future<void> screen(String name) =>
      _analytics.logScreenView(screenName: name);

  Future<void> identify(String uid) => _analytics.setUserId(id: uid);

  // The five events that actually drive the retention dashboard.
  Future<void> signedUp() => log('pact_signed_up');
  Future<void> goalSet(String goal) => log('pact_goal_set', {'goal': goal});
  Future<void> matched() => log('pact_matched');
  Future<void> checkedIn(int streak) => log('pact_check_in', {'streak': streak});
  Future<void> broken(int streak, bool byMe) =>
      log('pact_broken', {'streak_lost': streak, 'by_me': byMe.toString()});
}

final pactAnalyticsProvider =
    Provider<PactAnalytics>((ref) => PactAnalytics(ref.watch(analyticsProvider)));

/// Firestore paths, in one place.
abstract final class Paths {
  static CollectionReference<Map<String, dynamic>> users(FirebaseFirestore db) =>
      db.collection('users');
  static DocumentReference<Map<String, dynamic>> user(FirebaseFirestore db, String uid) =>
      db.collection('users').doc(uid);
  static DocumentReference<Map<String, dynamic>> pact(FirebaseFirestore db, String id) =>
      db.collection('pacts').doc(id);
  static DocumentReference<Map<String, dynamic>> day(
    FirebaseFirestore db,
    String pactId,
    String dayKey,
  ) =>
      pact(db, pactId).collection('days').doc(dayKey);
  static CollectionReference<Map<String, dynamic>> days(FirebaseFirestore db, String pactId) =>
      pact(db, pactId).collection('days');
  static CollectionReference<Map<String, dynamic>> history(FirebaseFirestore db, String uid) =>
      user(db, uid).collection('pactHistory');
  static DocumentReference<Map<String, dynamic>> queue(FirebaseFirestore db, String uid) =>
      db.collection('matchQueue').doc(uid);

  static String proofPath(String pactId, String dayKey, String uid) =>
      'checkins/$pactId/$dayKey/$uid.jpg';
  static String avatarPath(String uid) => 'avatars/$uid/avatar.jpg';
}
