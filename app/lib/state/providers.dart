import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/pact_clock.dart';
import '../data/models/app_user.dart';
import '../data/models/pact.dart';
import '../data/models/pact_day.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/pact_repository.dart';
import '../data/repositories/user_repository.dart';

/// uid of whoever is signed in, or null.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);

final emailVerifiedProvider = Provider<bool>(
  (ref) => ref.watch(authStateProvider).value?.emailVerified ?? false,
);

/// Live profile document.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watch(uid);
});

/// The active pact, if any.
final currentPactProvider = StreamProvider<Pact?>((ref) {
  final pactId = ref.watch(currentUserProvider).value?.currentPactId;
  if (pactId == null || pactId.isEmpty) return Stream.value(null);
  return ref.watch(pactRepositoryProvider).watch(pactId);
});

/// A pact's timezone owns the day boundary. Re-emits when the clock rolls over
/// so the UI flips to a fresh day without a restart.
final todayKeyProvider = StreamProvider<String?>((ref) {
  final pact = ref.watch(currentPactProvider).value;
  if (pact == null) return Stream.value(null);

  final tz = pact.timezone;
  final controller = StreamController<String?>();
  var current = PactClock.dayKey(tz);
  controller.add(current);

  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    final next = PactClock.dayKey(tz);
    if (next != current) {
      current = next;
      controller.add(next);
    }
  });

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Today's board for both members.
final todayProvider = StreamProvider<PactDay>((ref) {
  final pact = ref.watch(currentPactProvider).value;
  final dayKey = ref.watch(todayKeyProvider).value;
  if (pact == null || dayKey == null) return Stream.value(PactDay.empty);
  return ref.watch(pactRepositoryProvider).watchDay(pact.id, dayKey);
});

final recentDaysProvider = StreamProvider<List<PactDay>>((ref) {
  final pact = ref.watch(currentPactProvider).value;
  if (pact == null) return Stream.value(const []);
  return ref.watch(pactRepositoryProvider).watchRecentDays(pact.id);
});

/// Countdown to the shared midnight. Ticks once a second inside the final hour,
/// every fifteen otherwise — no reason to burn battery all afternoon.
final deadlineProvider = StreamProvider<Duration>((ref) {
  final pact = ref.watch(currentPactProvider).value;
  if (pact == null) return Stream.value(Duration.zero);

  Duration left() => PactClock.timeUntilDeadline(pact.timezone);

  const slow = Duration(seconds: 15);
  const fast = Duration(seconds: 1);

  final controller = StreamController<Duration>();
  Timer? timer;
  Duration period = slow;

  void tick() {
    final remaining = left();
    controller.add(remaining);

    // Speed up inside the final hour, slow back down after midnight.
    final wanted = remaining <= const Duration(hours: 1) ? fast : slow;
    if (wanted != period) {
      period = wanted;
      timer?.cancel();
      timer = Timer.periodic(period, (_) => tick());
    }
  }

  tick();
  timer ??= Timer.periodic(period, (_) => tick());

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

final isFinalHourProvider = Provider<bool>((ref) {
  final left = ref.watch(deadlineProvider).value;
  return left != null && left <= const Duration(hours: 1) && left > Duration.zero;
});

/// True while this user is sitting in the matchmaking pool.
final inQueueProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(false);
  return ref.watch(pactRepositoryProvider).watchQueue(uid);
});
