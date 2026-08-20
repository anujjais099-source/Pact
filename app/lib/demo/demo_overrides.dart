import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/checkin_controller.dart';
import '../state/providers.dart';
import 'demo_mode.dart';

/// Submits nothing anywhere. Waits long enough to feel like an upload, then
/// turns the day green locally.
class DemoCheckInController extends CheckInController {
  @override
  Future<bool> submit(File photo) async {
    state = const CheckInState(phase: CheckInPhase.uploading);
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final demo = ref.read(demoProvider.notifier);
    demo.recordMyCheckIn();

    state = CheckInState(
      phase: CheckInPhase.done,
      streak: ref.read(demoProvider).pact.streak,
      // The partner arrives a few seconds later, so this half is done alone.
      bothGreen: false,
    );

    if (await photo.exists()) {
      try {
        await photo.delete();
      } catch (_) {}
    }
    return true;
  }
}

/// Everything the app would normally read from Firebase, served from memory.
List<Override> demoOverrides() => [
      demoModeProvider.overrideWithValue(true),

      currentUidProvider.overrideWithValue(kDemoUid),
      emailVerifiedProvider.overrideWithValue(true),

      currentUserProvider.overrideWith(
        (ref) => Stream.value(ref.watch(demoProvider).user),
      ),
      currentPactProvider.overrideWith(
        (ref) => Stream.value(ref.watch(demoProvider).pact),
      ),
      todayProvider.overrideWith(
        (ref) => Stream.value(ref.watch(demoProvider).today),
      ),
      recentDaysProvider.overrideWith(
        (ref) => Stream.value(ref.watch(demoProvider).history),
      ),
      todayKeyProvider.overrideWith(
        (ref) => Stream.value(ref.watch(demoProvider).today.dayKey),
      ),
      inQueueProvider.overrideWith((ref) => Stream.value(false)),

      // A countdown that visibly moves, without needing a timezone database.
      deadlineProvider.overrideWith((ref) {
        var left = const Duration(hours: 3, minutes: 42);
        return Stream<Duration>.periodic(const Duration(seconds: 1), (_) {
          left -= const Duration(seconds: 1);
          return left.isNegative ? Duration.zero : left;
        }).asBroadcastStream();
      }),

      checkInControllerProvider.overrideWith(DemoCheckInController.new),
    ];
