/**
 * Drives the streak engine without waiting for midnight.
 *
 *   node scripts/simulate-day.mjs --miss none   # both checked in yesterday
 *   node scripts/simulate-day.mjs --miss a      # first member missed
 *   node scripts/simulate-day.mjs --miss both
 *
 * It writes yesterday's outcome and rewinds `lastEvaluatedDay` so the day is
 * unjudged. Then run the job itself — the emulator does not fire schedules:
 *
 *   firebase functions:shell
 *   > rolloverPactDays()
 *
 * or call the `rolloverPactNow` callable from a signed-in client.
 */
import { FieldValue } from 'firebase-admin/firestore';
import { db, dayKey, arg } from './common.mjs';

const MISS = String(arg('miss', 'none')).toLowerCase(); // none | a | b | both

async function main() {
  const pacts = await db.collection('pacts').where('status', '==', 'active').get();
  if (pacts.empty) {
    console.error('No active pact. Run seed-emulator.mjs first.');
    process.exit(1);
  }

  for (const pact of pacts.docs) {
    const members = pact.get('members');
    const tz = pact.get('timezone') ?? 'UTC';
    const yesterday = dayKey(-1, tz);

    const statuses = {
      [members[0]]: MISS === 'a' || MISS === 'both' ? 'pending' : 'green',
      [members[1]]: MISS === 'b' || MISS === 'both' ? 'pending' : 'green',
    };

    await pact.ref.collection('days').doc(yesterday).set(
      {
        dayKey: yesterday,
        pactId: pact.id,
        members,
        statuses,
        resolved: false,
        createdAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    // Rewind the watermark so the rollover treats yesterday as unjudged.
    await pact.ref.update({ lastEvaluatedDay: dayKey(-2, tz) });

    console.log(`pact ${pact.id}: ${yesterday} set to`, statuses);
  }

  console.log('\nNow run the job:  firebase functions:shell  ->  rolloverPactDays()');
}

main().then(() => process.exit(0));
