/**
 * Seeds the emulator with two verified users already matched into a pact with
 * `--streak` days of history behind them.
 *
 *   node scripts/seed-emulator.mjs --streak 6 --tz UTC
 *
 * Sign in as alex@pact.test / partner@pact.test, password "pact1234".
 */
import { FieldValue } from 'firebase-admin/firestore';
import { db, auth, dayKey, levelForStreak, arg } from './common.mjs';

const STREAK = Number(arg('streak', 6));
const TZ = String(arg('tz', 'UTC'));
const PASSWORD = 'pact1234';

const PEOPLE = [
  { email: 'alex@pact.test', username: 'alex_am', goal: 'Gym' },
  { email: 'partner@pact.test', username: 'quiet_run', goal: 'Study' },
];

async function upsertUser({ email, username, goal }) {
  let record;
  try {
    record = await auth.getUserByEmail(email);
  } catch {
    record = await auth.createUser({ email, password: PASSWORD, emailVerified: true });
  }
  await auth.updateUser(record.uid, { emailVerified: true, password: PASSWORD });

  const totalCheckins = STREAK;
  const totalExpected = STREAK;

  await db.collection('users').doc(record.uid).set({
    uid: record.uid,
    username,
    usernameLower: username.toLowerCase(),
    email,
    emailVerified: true,
    avatarUrl: null,
    goalName: goal,
    timezone: TZ,
    fcmTokens: [],
    notificationsEnabled: true,
    status: 'matched',
    currentPactId: null,
    reliability: 100,
    totalCheckins,
    totalExpected,
    missedDays: 0,
    totalPacts: 0,
    longestStreak: STREAK,
    streakSafe: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await db.collection('usernames').doc(username.toLowerCase()).set({
    uid: record.uid,
    username,
    claimedAt: FieldValue.serverTimestamp(),
  });

  return { uid: record.uid, username, goal };
}

async function main() {
  const [a, b] = await Promise.all(PEOPLE.map(upsertUser));
  const members = [a.uid, b.uid].sort();
  const lvl = levelForStreak(STREAK);
  const startDayKey = dayKey(-STREAK, TZ);

  const pactRef = db.collection('pacts').doc();
  await pactRef.set({
    id: pactRef.id,
    members,
    memberInfo: {
      [a.uid]: { username: a.username, avatarUrl: null, goalName: a.goal, reliability: 100 },
      [b.uid]: { username: b.username, avatarUrl: null, goalName: b.goal, reliability: 100 },
    },
    status: 'active',
    streak: STREAK,
    longestStreak: STREAK,
    level: lvl.level,
    levelName: lvl.name,
    timezone: TZ,
    startDayKey,
    lastEvaluatedDay: dayKey(-1, TZ),
    daysTogether: STREAK + 1,
    brokenBy: [],
    createdAt: FieldValue.serverTimestamp(),
  });

  // Green history behind them, plus today still open.
  const batch = db.batch();
  for (let i = STREAK; i >= 1; i--) {
    const key = dayKey(-i, TZ);
    batch.set(pactRef.collection('days').doc(key), {
      dayKey: key,
      pactId: pactRef.id,
      members,
      statuses: { [members[0]]: 'green', [members[1]]: 'green' },
      checkins: {},
      resolved: true,
      streakAfter: STREAK - i + 1,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  const today = dayKey(0, TZ);
  batch.set(pactRef.collection('days').doc(today), {
    dayKey: today,
    pactId: pactRef.id,
    members,
    statuses: { [members[0]]: 'pending', [members[1]]: 'pending' },
    checkins: {},
    resolved: false,
    streakAfter: STREAK,
    createdAt: FieldValue.serverTimestamp(),
  });
  for (const uid of members) {
    batch.update(db.collection('users').doc(uid), { currentPactId: pactRef.id });
  }
  await batch.commit();

  console.log(`seeded pact ${pactRef.id} — streak ${STREAK}, tz ${TZ}`);
  console.log(`  ${PEOPLE[0].email} / ${PASSWORD}  (${a.uid})`);
  console.log(`  ${PEOPLE[1].email} / ${PASSWORD}  (${b.uid})`);
  console.log(`  today (${today}) is open for both`);
}

main().then(() => process.exit(0));
