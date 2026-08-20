import { DateTime } from "luxon";

export const DEFAULT_TZ = "UTC";

/** Normalises anything the client sends into a real IANA zone. */
export function safeZone(tz?: string | null): string {
  if (!tz) return DEFAULT_TZ;
  return DateTime.now().setZone(tz).isValid ? tz : DEFAULT_TZ;
}

/** `YYYY-MM-DD` for "now" (or a given instant) inside a pact's timezone. */
export function dayKey(tz: string, at: Date = new Date()): string {
  return DateTime.fromJSDate(at, { zone: safeZone(tz) }).toFormat("yyyy-MM-dd");
}

export function localHour(tz: string, at: Date = new Date()): number {
  return DateTime.fromJSDate(at, { zone: safeZone(tz) }).hour;
}

export function shiftDayKey(key: string, days: number): string {
  return DateTime.fromISO(key, { zone: "UTC" }).plus({ days }).toFormat("yyyy-MM-dd");
}

export function previousDayKey(key: string): string {
  return shiftDayKey(key, -1);
}

/** Inclusive count of calendar days between two day keys. */
export function daysBetween(fromKey: string, toKey: string): number {
  const a = DateTime.fromISO(fromKey, { zone: "UTC" });
  const b = DateTime.fromISO(toKey, { zone: "UTC" });
  return Math.max(0, Math.round(b.diff(a, "days").days));
}

/** Every dayKey in [fromKey, toKey], capped so a stalled job can't fan out forever. */
export function dayKeyRange(fromKey: string, toKey: string, cap = 45): string[] {
  const out: string[] = [];
  let cursor = fromKey;
  while (cursor <= toKey && out.length < cap) {
    out.push(cursor);
    cursor = shiftDayKey(cursor, 1);
  }
  return out;
}
