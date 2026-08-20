import 'package:flutter_test/flutter_test.dart';
import 'package:pactly/core/utils/pact_clock.dart';

/// The whole product rests on both partners agreeing what "today" is. These
/// assertions mirror functions/src/time.ts.
void main() {
  setUpAll(() async => PactClock.init());

  test('dayKey is YYYY-MM-DD in the pact timezone, not the device one', () {
    // 2026-08-19T22:30Z is already the 20th in Kolkata (+05:30) and still the
    // 19th in New York (-04:00).
    final instant = DateTime.utc(2026, 8, 19, 22, 30);
    expect(PactClock.dayKey('Asia/Kolkata', instant), '2026-08-20');
    expect(PactClock.dayKey('America/New_York', instant), '2026-08-19');
    expect(PactClock.dayKey('UTC', instant), '2026-08-19');
  });

  test('an unknown zone degrades to UTC instead of throwing', () {
    final instant = DateTime.utc(2026, 1, 2, 3, 4);
    expect(PactClock.dayKey('Mars/Olympus_Mons', instant), '2026-01-02');
  });

  test('deadline is the next local midnight and is always in the future', () {
    final left = PactClock.timeUntilDeadline('Asia/Kolkata');
    expect(left, greaterThan(Duration.zero));
    expect(left, lessThanOrEqualTo(const Duration(days: 1)));
  });
}
