import 'package:flutter_test/flutter_test.dart';
import 'package:pactly/data/models/pact_level.dart';

/// These bands are duplicated in functions/src/levels.ts. If this test and that
/// file ever disagree, the app lies to the user about their own progress.
void main() {
  group('PactLevel.forStreak', () {
    test('band boundaries', () {
      expect(PactLevel.forStreak(0), PactLevel.one);
      expect(PactLevel.forStreak(1), PactLevel.one);
      expect(PactLevel.forStreak(7), PactLevel.one);
      expect(PactLevel.forStreak(8), PactLevel.two);
      expect(PactLevel.forStreak(14), PactLevel.two);
      expect(PactLevel.forStreak(15), PactLevel.three);
      expect(PactLevel.forStreak(30), PactLevel.three);
      expect(PactLevel.forStreak(31), PactLevel.legendary);
      expect(PactLevel.forStreak(999), PactLevel.legendary);
    });

    test('daysToNext counts to the next band, null once Legendary', () {
      expect(PactLevel.one.daysToNext(1), 7);
      expect(PactLevel.one.daysToNext(7), 1);
      expect(PactLevel.two.daysToNext(8), 7);
      expect(PactLevel.legendary.daysToNext(40), isNull);
    });

    test('progress fills across the band and never leaves 0..1', () {
      expect(PactLevel.one.progress(1), closeTo(1 / 7, 0.001));
      expect(PactLevel.one.progress(7), 1);
      expect(PactLevel.three.progress(15), closeTo(1 / 16, 0.001));
      expect(PactLevel.legendary.progress(31), 1);
      expect(PactLevel.one.progress(0), inInclusiveRange(0, 1));
    });

    test('next walks the ladder and stops', () {
      expect(PactLevel.one.next, PactLevel.two);
      expect(PactLevel.three.next, PactLevel.legendary);
      expect(PactLevel.legendary.next, isNull);
    });
  });
}
