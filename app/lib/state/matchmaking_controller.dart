import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/pact_repository.dart';
import '../data/services/firebase_service.dart';
import 'providers.dart';

enum MatchPhase { idle, searching, matched, failed }

class MatchState {
  const MatchState({this.phase = MatchPhase.idle, this.pactId, this.error});

  final MatchPhase phase;
  final String? pactId;
  final String? error;

  MatchState copyWith({MatchPhase? phase, String? pactId, String? error}) =>
      MatchState(
        phase: phase ?? this.phase,
        pactId: pactId ?? this.pactId,
        error: error,
      );
}

/// Joining the pool is one call. If nobody is waiting we stay enqueued and the
/// server's sweeper pairs us within the minute — the screen just listens to the
/// user document for `currentPactId` to appear.
class MatchmakingController extends AutoDisposeNotifier<MatchState> {
  @override
  MatchState build() => const MatchState();

  Future<void> find() async {
    state = const MatchState(phase: MatchPhase.searching);
    try {
      final outcome = await ref.read(pactRepositoryProvider).requestMatch();
      if (outcome.pactId != null) {
        await ref.read(pactAnalyticsProvider).matched();
        state = MatchState(phase: MatchPhase.matched, pactId: outcome.pactId);
      } else {
        state = const MatchState(phase: MatchPhase.searching);
      }
    } catch (e) {
      state = MatchState(phase: MatchPhase.failed, error: _readable(e));
    }
  }

  Future<void> cancel() async {
    try {
      await ref.read(pactRepositoryProvider).cancelMatch();
    } finally {
      state = const MatchState();
    }
  }

  /// Called by the screen when the user document shows a pact appeared.
  void confirmMatched(String pactId) {
    if (state.phase == MatchPhase.matched) return;
    ref.read(pactAnalyticsProvider).matched();
    state = MatchState(phase: MatchPhase.matched, pactId: pactId);
  }

  String _readable(Object e) {
    final s = e.toString();
    if (s.contains('failed-precondition')) {
      return s.contains('email') ? 'Verify your email first.' : 'Set a goal first.';
    }
    if (s.contains('unavailable') || s.contains('network')) {
      return 'No connection. Try again.';
    }
    return 'Could not find a partner. Try again.';
  }
}

final matchmakingControllerProvider =
    AutoDisposeNotifierProvider<MatchmakingController, MatchState>(
  MatchmakingController.new,
);

/// Fires once the server hands us a pact while we are waiting.
final matchArrivedProvider = Provider<String?>((ref) {
  final pactId = ref.watch(currentUserProvider).value?.currentPactId;
  return (pactId != null && pactId.isNotEmpty) ? pactId : null;
});
