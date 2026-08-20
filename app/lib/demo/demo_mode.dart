import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_user.dart';
import '../data/models/pact.dart';
import '../data/models/pact_day.dart';

/// Compile-time switch:
///   flutter build apk --release --dart-define=DEMO_MODE=true
///
/// A demo build never touches Firebase. It boots straight into a live Home
/// screen with a partner, an eleven-day streak and a working camera check-in,
/// so someone can judge the idea in thirty seconds without making an account.
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE');

const String kDemoUid = 'demo-you';
const String kDemoPartnerUid = 'demo-partner';

/// Everything the demo app knows. One object, mutated by one controller.
class DemoData {
  const DemoData({
    required this.user,
    required this.pact,
    required this.today,
    required this.history,
  });

  final AppUser user;
  final Pact pact;
  final PactDay today;
  final List<PactDay> history;

  DemoData copyWith({AppUser? user, Pact? pact, PactDay? today}) => DemoData(
        user: user ?? this.user,
        pact: pact ?? this.pact,
        today: today ?? this.today,
        history: history,
      );
}

class DemoController extends Notifier<DemoData> {
  Timer? _partnerTimer;

  @override
  DemoData build() {
    ref.onDispose(() => _partnerTimer?.cancel());
    return _seed();
  }

  static const _me = AppUser(
    uid: kDemoUid,
    username: 'earlybird_92',
    email: 'you@example.com',
    emailVerified: true,
    goalName: 'Gym',
    timezone: 'UTC',
    status: UserStatus.matched,
    reliability: 92,
    totalCheckins: 58,
    totalExpected: 63,
    missedDays: 5,
    totalPacts: 3,
    longestStreak: 21,
    notificationsEnabled: true,
    currentPactId: 'demo-pact',
  );

  static const _partner = MemberInfo(
    uid: kDemoPartnerUid,
    username: 'quiet_run',
    goalName: 'Study',
    reliability: 96,
  );

  static const _mine = MemberInfo(
    uid: kDemoUid,
    username: 'earlybird_92',
    goalName: 'Gym',
    reliability: 92,
  );

  static DemoData _seed() {
    const pact = Pact(
      id: 'demo-pact',
      members: [kDemoPartnerUid, kDemoUid],
      memberInfo: {kDemoUid: _mine, kDemoPartnerUid: _partner},
      status: PactStatus.active,
      streak: 11,
      longestStreak: 11,
      timezone: 'UTC',
      startDayKey: '2026-08-08',
      daysTogether: 12,
      brokenBy: [],
    );

    const today = PactDay(
      dayKey: '2026-08-20',
      statuses: {kDemoUid: DayStatus.pending, kDemoPartnerUid: DayStatus.pending},
      proofs: {},
      resolved: false,
    );

    // Eleven green days and one red, so the dot strip shows a real history.
    final history = <PactDay>[
      for (var i = 0; i < 14; i++)
        PactDay(
          dayKey: 'demo-$i',
          statuses: {
            kDemoUid: i == 2 ? DayStatus.red : DayStatus.green,
            kDemoPartnerUid: i == 2 ? DayStatus.red : DayStatus.green,
          },
          proofs: const {},
          resolved: true,
        ),
    ];

    return DemoData(user: _me, pact: pact, today: today, history: history);
  }

  /// The user submitted their photo. Their half turns green immediately.
  void recordMyCheckIn() {
    final now = DateTime.now();
    state = state.copyWith(
      today: PactDay(
        dayKey: state.today.dayKey,
        statuses: {...state.today.statuses, kDemoUid: DayStatus.green},
        proofs: {
          ...state.today.proofs,
          kDemoUid: Proof(photoUrl: '', submittedAt: now),
        },
        resolved: false,
      ),
      user: _me,
    );

    // The whole point of the product is that the day is not yours to close.
    // A few seconds later the partner shows up and the streak moves — that
    // beat is what a demo has to convey.
    _partnerTimer?.cancel();
    _partnerTimer = Timer(const Duration(seconds: 6), _partnerChecksIn);
  }

  void _partnerChecksIn() {
    if (state.today.statusOf(kDemoUid) != DayStatus.green) return;

    final pact = state.pact;
    state = state.copyWith(
      today: PactDay(
        dayKey: state.today.dayKey,
        statuses: {
          kDemoUid: DayStatus.green,
          kDemoPartnerUid: DayStatus.green,
        },
        proofs: {
          ...state.today.proofs,
          kDemoPartnerUid: Proof(photoUrl: '', submittedAt: DateTime.now()),
        },
        resolved: false,
      ),
      pact: Pact(
        id: pact.id,
        members: pact.members,
        memberInfo: pact.memberInfo,
        status: pact.status,
        streak: pact.streak + 1,
        longestStreak: pact.longestStreak + 1,
        timezone: pact.timezone,
        startDayKey: pact.startDayKey,
        daysTogether: pact.daysTogether,
        brokenBy: pact.brokenBy,
      ),
    );
  }

  /// Streak already advanced by the time the success screen reads it, so the
  /// number it shows is the one the partner will see too.
  int get streakAfterBoth => state.pact.streak + 1;

  void reset() {
    _partnerTimer?.cancel();
    state = _seed();
  }
}

final demoProvider = NotifierProvider<DemoController, DemoData>(DemoController.new);

/// Read by the router and by the session side effects in app.dart, both of
/// which must not reach for Firebase in a demo build.
final demoModeProvider = Provider<bool>((_) => kDemoMode);
