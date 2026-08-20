import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/pact_clock.dart';
import '../data/repositories/checkin_repository.dart';
import '../data/services/firebase_service.dart';
import 'providers.dart';

enum CheckInPhase { idle, uploading, done, failed }

class CheckInState {
  const CheckInState({
    this.phase = CheckInPhase.idle,
    this.streak = 0,
    this.bothGreen = false,
    this.error,
  });

  final CheckInPhase phase;
  final int streak;
  final bool bothGreen;
  final String? error;

  bool get busy => phase == CheckInPhase.uploading;
}

/// Compress, upload, then let the server rule on it. The client never decides
/// what a check-in is worth.
class CheckInController extends AutoDisposeNotifier<CheckInState> {
  @override
  CheckInState build() => const CheckInState();

  Future<bool> submit(File photo) async {
    final pact = ref.read(currentPactProvider).value;
    final uid = ref.read(currentUidProvider);
    if (pact == null || uid == null) {
      state = const CheckInState(phase: CheckInPhase.failed, error: 'No active Pact.');
      return false;
    }

    state = const CheckInState(phase: CheckInPhase.uploading);
    try {
      final result = await ref.read(checkInRepositoryProvider).submit(
            pactId: pact.id,
            dayKey: PactClock.dayKey(pact.timezone),
            uid: uid,
            photo: photo,
          );
      await ref.read(pactAnalyticsProvider).checkedIn(result.streak);
      state = CheckInState(
        phase: CheckInPhase.done,
        streak: result.streak,
        bothGreen: result.bothGreen,
      );
      return true;
    } catch (e) {
      state = CheckInState(phase: CheckInPhase.failed, error: _readable(e));
      return false;
    } finally {
      // The temp frame has served its purpose either way.
      if (await photo.exists()) {
        try {
          await photo.delete();
        } catch (_) {}
      }
    }
  }

  void reset() => state = const CheckInState();

  String _readable(Object e) {
    final s = e.toString();
    if (s.contains('unauthenticated')) return 'Sign in again.';
    if (s.contains('failed-precondition')) return 'This Pact is no longer active.';
    if (s.contains('permission-denied')) return 'You already checked in today.';
    if (s.contains('network') || s.contains('unavailable')) {
      return 'Upload failed. Check your connection and retry.';
    }
    return 'Could not submit. Try once more.';
  }
}

final checkInControllerProvider =
    AutoDisposeNotifierProvider<CheckInController, CheckInState>(CheckInController.new);
