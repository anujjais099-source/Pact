import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

// Point the Admin SDK at the local emulators. Refuse to run otherwise — these
// scripts write test data and must never touch a real project.
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9099';

if (!process.env.FIRESTORE_EMULATOR_HOST.startsWith('127.0.0.1')) {
  throw new Error('Refusing to run against a non-local Firestore.');
}

const projectId = process.env.GCLOUD_PROJECT ?? 'pact-mvp';
initializeApp({ projectId });

export const db = getFirestore();
export const auth = getAuth();
export const now = () => new Date();

export function dayKey(offsetDays = 0, tz = 'UTC') {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + offsetDays);
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(d);
}

export function levelForStreak(streak) {
  if (streak >= 31) return { level: 4, name: 'Legendary Pact' };
  if (streak >= 15) return { level: 3, name: 'Level 3 Pact' };
  if (streak >= 8) return { level: 2, name: 'Level 2 Pact' };
  return { level: 1, name: 'Level 1 Pact' };
}

export function arg(name, fallback = null) {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  if (hit) return hit.split('=')[1];
  const idx = process.argv.indexOf(`--${name}`);
  return idx >= 0 ? process.argv[idx + 1] ?? true : fallback;
}
