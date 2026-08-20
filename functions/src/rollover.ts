import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { firestore } from "firebase-admin";
import { col, db, FieldValue, REGION } from "./firebase";
import { dayKey, daysBetween, dayKeyRange, previousDayKey, shiftDayKey } from "./time";
import { levelForStreak, reliabilityOf } from "./levels";
import { sendToUsers } from "./notify";
import type { DayStatus } from "./types";

type Tx = firestore.Transaction;

interface RolloverResult {
  pactId: string;
  broken: boolean;
  missedBy: string[];
  streakBefore: number;
  members: string[];
}

/**
 * Closes out every fully-elapsed day of one pact.
 *
 * Idempotent by construction: `lastEvaluatedDay` is the watermark, so a retry,
 * a duplicate schedule tick, or a job that was down for three days all land on
 * exactly the same end state.
 */
async function rolloverPact(pactId: string): Promise<RolloverResult | null> {
  return db.runTransaction(async (tx: Tx) => {
    const pactRef = col.pacts().doc(pactId);
    const pact = await tx.get(pactRef);
    if (!pact.exists || pact.get("status") !== "active") return null;

    const tz: string = pact.get("timezone");
    const members: string[] = pact.get("members") ?? [];
    const startDayKey: string = pact.get("startDayKey");
    const todayKey = dayKey(tz);
    const lastDone: string | null = pact.get("lastEvaluatedDay") ?? null;

    // Only days that have fully elapsed in the timezone of the pact are judged.
    const fromKey = lastDone ? shiftDayKey(lastDone, 1) : startDayKey;
    const toKey = previousDayKey(todayKey);

    if (fromKey > toKey) {
      // Nothing has elapsed since the last run; just keep daysTogether fresh.
      const daysTogether = daysBetween(startDayKey, todayKey) + 1;
      if (daysTogether !== pact.get("daysTogether")) {
        tx.update(pactRef, { daysTogether });
      }
      return null;
    }

    const keys = dayKeyRange(fromKey, toKey);
    const dayRefs = keys.map((k) => col.days(pactId).doc(k));
    const daySnaps = await Promise.all(dayRefs.map((r) => tx.get(r)));
    const userSnaps = await Promise.all(members.map((m) => tx.get(col.users().doc(m))));

    const streakBefore: number = pact.get("streak") ?? 0;
    let longest: number = pact.get("longestStreak") ?? 0;
    const completedDays: Record<string, number> = Object.fromEntries(members.map((m) => [m, 0]));
    const missedTally: Record<string, number> = Object.fromEntries(members.map((m) => [m, 0]));

    let broken = false;
    let missedBy: string[] = [];
    let brokenOnKey: string | null = null;

    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const snap = daySnaps[i];
      const statuses: Record<string, DayStatus> = { ...(snap.get("statuses") ?? {}) };
      const missing = members.filter((m) => statuses[m] !== "green");

      for (const m of members) {
        if (statuses[m] === "green") completedDays[m] += 1;
      }

      if (missing.length === 0) {
        tx.set(
          snap.ref,
          { dayKey: key, pactId, members, statuses, resolved: true, streakAfter: streakBefore },
          { merge: true }
        );
        continue;
      }

      // Somebody did not show up. The Pact ends here, for both of them.
      for (const m of missing) {
        statuses[m] = "red";
        missedTally[m] += 1;
      }
      broken = true;
      missedBy = missing;
      brokenOnKey = key;

      tx.set(
        snap.ref,
        {
          dayKey: key,
          pactId,
          members,
          statuses,
          resolved: true,
          streakAfter: 0,
          brokenHere: true,
        },
        { merge: true }
      );
      break;
    }

    const lastEvaluatedDay = brokenOnKey ?? toKey;
    const expectedAdded = keys.indexOf(lastEvaluatedDay) + 1;

    if (broken) {
      longest = Math.max(longest, streakBefore);
      const lvl = levelForStreak(0);
      tx.update(pactRef, {
        status: "broken",
        streak: 0,
        longestStreak: longest,
        level: lvl.level,
        levelName: lvl.name,
        brokenBy: missedBy,
        brokenOnDay: brokenOnKey,
        lastEvaluatedDay,
        brokenAt: FieldValue.serverTimestamp(),
        endedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(col.events(pactId).doc(), {
        type: "broken",
        message: "Your Pact has been broken.",
        streakLost: streakBefore,
        missedBy,
        createdAt: FieldValue.serverTimestamp(),
      });
    } else {
      tx.update(pactRef, {
        lastEvaluatedDay,
        daysTogether: daysBetween(startDayKey, todayKey) + 1,
        longestStreak: Math.max(longest, streakBefore),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    // ---- member counters ----
    for (let i = 0; i < members.length; i++) {
      const uid = members[i];
      const snap = userSnaps[i];
      if (!snap.exists) continue;

      const partnerUid = members.find((m) => m !== uid) ?? null;
      const totalCheckins: number = snap.get("totalCheckins") ?? 0;
      const totalExpected = Math.max(
        (snap.get("totalExpected") ?? 0) + expectedAdded,
        totalCheckins
      );

      const update: Record<string, unknown> = {
        totalExpected,
        reliability: reliabilityOf(totalCheckins, totalExpected),
        missedDays: (snap.get("missedDays") ?? 0) + missedTally[uid],
        longestStreak: Math.max(snap.get("longestStreak") ?? 0, streakBefore),
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (broken) {
        update.currentPactId = null;
        update.status = "idle";
        update.totalPacts = (snap.get("totalPacts") ?? 0) + 1;

        const memberInfo = pact.get("memberInfo") ?? {};
        tx.set(col.history(uid).doc(pactId), {
          pactId,
          partnerUid,
          partnerUsername: partnerUid ? memberInfo[partnerUid]?.username ?? null : null,
          finalStreak: streakBefore,
          level: levelForStreak(streakBefore).level,
          levelName: levelForStreak(streakBefore).name,
          brokenByMe: missedBy.includes(uid),
          daysCompleted: completedDays[uid],
          endedAt: FieldValue.serverTimestamp(),
        });
      }

      tx.update(snap.ref, update);
    }

    return { pactId, broken, missedBy, streakBefore, members };
  });
}

async function announceBreak(result: RolloverResult) {
  await Promise.all(
    result.members.map((uid) => {
      const brokeIt = result.missedBy.includes(uid);
      return sendToUsers([uid], {
        title: "Your Pact has been broken.",
        body: brokeIt
          ? "You missed a day. " + result.streakBefore + " days gone, for both of you."
          : "Your partner missed a day. The " + result.streakBefore + "-day streak is gone.",
        data: { type: "pact_broken", pactId: result.pactId },
      });
    })
  );
}

/**
 * Runs hourly so every timezone on earth gets its midnight served within the
 * hour. The watermark makes the extra runs free.
 */
export const rolloverPactDays = onSchedule(
  { region: REGION, schedule: "every 60 minutes", timeZone: "UTC", timeoutSeconds: 540 },
  async () => {
    let processed = 0;
    let brokenCount = 0;
    let cursor: firestore.QueryDocumentSnapshot | null = null;

    for (;;) {
      let q = col.pacts().where("status", "==", "active").orderBy("__name__").limit(200);
      if (cursor) q = q.startAfter(cursor);
      const page = await q.get();
      if (page.empty) break;

      for (const doc of page.docs) {
        try {
          const result = await rolloverPact(doc.id);
          processed++;
          if (result?.broken) {
            brokenCount++;
            await announceBreak(result);
          }
        } catch (err) {
          logger.error("rollover failed", { pactId: doc.id, err });
        }
      }

      cursor = page.docs[page.docs.length - 1];
      if (page.size < 200) break;
    }

    logger.info("rolloverPactDays complete", { processed, broken: brokenCount });
  }
);

/** Manual trigger, used by the emulator test-suite and by support. */
export const rolloverPactNow = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  const pactId = String(request.data?.pactId ?? "");
  const pact = await col.pacts().doc(pactId).get();
  if (!pact.exists || !((pact.get("members") ?? []) as string[]).includes(uid)) {
    throw new HttpsError("permission-denied", "Not your Pact.");
  }
  const result = await rolloverPact(pactId);
  if (result?.broken) await announceBreak(result);
  return { ok: true, broken: result?.broken ?? false };
});
