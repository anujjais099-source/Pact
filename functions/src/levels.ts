/**
 * Pact levels evolve automatically with the shared streak.
 *   1–7   Level 1 Pact
 *   8–14  Level 2 Pact
 *   15–30 Level 3 Pact
 *   31+   Legendary Pact
 */
export interface PactLevel {
  level: number;
  name: string;
  /** first streak day of this band */
  from: number;
  /** last streak day of this band, null = open ended */
  to: number | null;
}

export const PACT_LEVELS: PactLevel[] = [
  { level: 1, name: "Level 1 Pact", from: 1, to: 7 },
  { level: 2, name: "Level 2 Pact", from: 8, to: 14 },
  { level: 3, name: "Level 3 Pact", from: 15, to: 30 },
  { level: 4, name: "Legendary Pact", from: 31, to: null },
];

export function levelForStreak(streak: number): PactLevel {
  const s = Math.max(0, streak);
  if (s >= 31) return PACT_LEVELS[3];
  if (s >= 15) return PACT_LEVELS[2];
  if (s >= 8) return PACT_LEVELS[1];
  return PACT_LEVELS[0];
}

export function reliabilityOf(totalCheckins: number, totalExpected: number): number {
  const expected = Math.max(totalExpected, totalCheckins);
  if (expected <= 0) return 100;
  return Math.round((totalCheckins / expected) * 1000) / 10;
}
