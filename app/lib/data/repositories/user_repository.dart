import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/pact_clock.dart';
import '../models/app_user.dart';
import '../services/firebase_service.dart';

class UserRepository {
  const UserRepository(this._db, this._fn, this._storage);

  final FirebaseFirestore _db;
  final FirebaseFunctions _fn;
  final FirebaseStorage _storage;

  Stream<AppUser?> watch(String uid) =>
      Paths.user(_db, uid).snapshots().map(AppUser.fromDoc);

  Future<AppUser?> fetch(String uid) async =>
      AppUser.fromDoc(await Paths.user(_db, uid).get());

  /// Claims the username and writes the profile. Server-side and transactional,
  /// so two people racing for the same name cannot both win.
  Future<void> createProfile({
    required String username,
    String goalName = '',
  }) async {
    final timezone = await PactClock.deviceTimezone();
    await _fn.httpsCallable('createProfile').call<Map<String, dynamic>>({
      'username': username.trim(),
      'goalName': goalName.trim(),
      'timezone': timezone,
    });
  }

  Future<bool> isUsernameAvailable(String username) async {
    final res = await _fn.httpsCallable('checkUsername').call<Map<String, dynamic>>({
      'username': username.trim(),
    });
    return res.data['available'] == true;
  }

  Future<void> updateGoal(String uid, String goalName) => Paths.user(_db, uid).update({
        'goalName': goalName.trim(),
        'goalUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> setNotifications(String uid, bool enabled) => Paths.user(_db, uid).update({
        'notificationsEnabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Called on every cold start: timezone travel must not silently move the
  /// user's deadline out from under them without the server knowing.
  Future<void> touchSession(String uid, {required bool emailVerified}) async {
    final tz = await PactClock.deviceTimezone();
    await Paths.user(_db, uid).set({
      'timezone': tz,
      'emailVerified': emailVerified,
      'lastActiveAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true),);
  }

  Future<void> saveFcmToken(String uid, String token) => Paths.user(_db, uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });

  Future<void> removeFcmToken(String uid, String token) => Paths.user(_db, uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });

  Future<String> uploadAvatar(String uid, File file) async {
    final ref = _storage.ref(Paths.avatarPath(uid));
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await Paths.user(_db, uid).update({
      'avatarUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return url;
  }

  Stream<List<Map<String, dynamic>>> watchHistory(String uid) => Paths.history(_db, uid)
      .orderBy('endedAt', descending: true)
      .limit(20)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(
    ref.watch(firestoreProvider),
    ref.watch(functionsProvider),
    ref.watch(storageProvider),
  ),
);
