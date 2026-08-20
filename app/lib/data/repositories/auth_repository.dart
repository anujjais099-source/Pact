import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/firebase_service.dart';

/// A failure we are willing to show a human.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthRepository {
  const AuthRepository(this._auth);
  final FirebaseAuth _auth;

  Stream<User?> get changes => _auth.userChanges();
  User? get current => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;

  Future<User> signUp({required String email, required String password}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.sendEmailVerification();
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_readable(e));
    }
  }

  Future<User> signIn({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_readable(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthFailure('You are signed out.');
    if (user.emailVerified) return;
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_readable(e));
    }
  }

  /// Verification happens in a mail client, so nothing pushes the news back to
  /// the app — we reload the token to find out.
  Future<bool> refreshVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    await user.getIdToken(true);
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_readable(e));
    }
  }

  String _readable(FirebaseAuthException e) => switch (e.code) {
        'email-already-in-use' => 'That email already has an account.',
        'invalid-email' => 'That email looks wrong.',
        'weak-password' => 'Pick a stronger password.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Email or password is incorrect.',
        'too-many-requests' => 'Too many tries. Wait a minute.',
        'network-request-failed' => 'No connection.',
        _ => e.message ?? 'Something went wrong.',
      };
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(firebaseAuthProvider)));

/// The single source of truth for "who is signed in".
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).changes,
);
