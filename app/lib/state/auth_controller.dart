import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/firebase_service.dart';

/// Every auth action the UI can take. One AsyncValue drives every spinner and
/// error banner in the auth flow.
class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _auth => ref.read(authRepositoryProvider);
  UserRepository get _users => ref.read(userRepositoryProvider);

  /// Creates the account, claims the username, sends the verification mail.
  Future<bool> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final available = await _users.isUsernameAvailable(username);
      if (!available) throw const AuthFailure('That username is taken.');

      await _auth.signUp(email: email, password: password);
      // Profile first, goal one screen later.
      await _users.createProfile(username: username);
      await ref.read(pactAnalyticsProvider).signedUp();
    });
    state = result;
    return !result.hasError;
  }

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final user = await _auth.signIn(email: email, password: password);
      await _users.touchSession(user.uid, emailVerified: user.emailVerified);
    });
    state = result;
    return !result.hasError;
  }

  Future<void> signOut() async {
    final uid = _auth.uid;
    if (uid != null) {
      await ref.read(notificationRepositoryProvider).disposeFor(uid);
    }
    await _auth.signOut();
  }

  Future<bool> resendVerification() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(_auth.sendVerificationEmail);
    state = result;
    return !result.hasError;
  }

  /// Polled by the verify screen — nothing pushes the news back to the app.
  Future<bool> checkVerified() async {
    final verified = await _auth.refreshVerification();
    final uid = _auth.uid;
    if (verified && uid != null) {
      await _users.touchSession(uid, emailVerified: true);
    }
    return verified;
  }

  Future<bool> resetPassword(String email) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _auth.sendPasswordReset(email));
    state = result;
    return !result.hasError;
  }
}

final authControllerProvider =
    AutoDisposeAsyncNotifierProvider<AuthController, void>(AuthController.new);
