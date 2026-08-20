import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { col, db, FieldValue, REGION } from "./firebase";
import { dayKey } from "./time";
import { levelForStreak, reliabilityOf } from "./levels";
import { sendToUsers } from "./notify";
import type { DayStatus } from "./types";

/**
 * The heart of the app. The client uploads the live photo to
 *   checkins/{pactId}/{dayKey}/{uid}.jpg
 * (Storage rules make that path write-once and member-only), then calls this.
 *
 * Server side we mark the day green, write the immutable proof record, move the
 * user's lifetime counters, and — only when BOTH members are green — advance the
 * shared streak and re-derive the level.
 */
export const submitCheckIn = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  const pactId = String(request.data?.pactId ?? "");
  const photoUrl = String(request.data?.photoUrl ?? "");
  const photoPath = String(request.data?.photoPath ?? "");
  if (!pactId || !photoUrl || !photoPath) {
    throw new HttpsError("invalid-argument", "pactId, photoUrl and photoPath are required.");
  }

  const outcome = await db.runTransaction(async (tx) => {
    const pactRef = col.pacts().doc(pactId);
    const pact = await tx.get(pactRef);
    if (!pact.exists) throw new HttpsError("not-found", "Pact not found.");

    const members: string[] = pact.get("members") ?? [];
    if (!members.includes(uid)) throw new HttpsError("permission-denied", "Not your Pact.");
    if (pact.get("status") !== "active") {
      throw new HttpsError("failed-precondition", "This Pact is no longer active.");
    }

    const tz: string = pact.get("timezone");
    const key = dayKey(tz);

    // The photo must sit at the exact path Storage rules allow for today.
    const expectedPrefix = "checkins/" + pactId + "/" + key + "/" + uid;
    if (!photoPath.startsWith(expectedPrefix)) {
      throw new HttpsError("invalid-argument", "Proof photo does not match today's check-in.");
    }

    const dayRef = col.days(pactId).doc(key);
    const day = await tx.get(dayRef);
    const meRef = col.users().doc(uid);
    const me = await tx.get(meRef);

    const statuses: Record<string, DayStatus> = day.exists
      ? { ...(day.get("statuses") ?? {}) }
      : Object.fromEntries(members.map((m) => [m, "pending" as DayStatus]));

    if (statuses[uid] === "green") {
      return {
        alreadyDone: true,
        streak: (pact.get("streak") ?? 0) as number,
        bothGreen: false,
        members,
      };
    }

    statuses[uid] = "green";
    const bothGreen = members.every((m) => statuses[m] === "green");

    let streak: number = pact.get("streak") ?? 0;
    let longest: number = pact.get("longestStreak") ?? 0;

    if (bothGreen) {
      const previousLevel = pact.get("level") ?? 1;
      streak += 1;
      longest = Math.max(longest, streak);
      const lvl = levelForStreak(streak);

      tx.update(pactRef, {
        streak,
        longestStreak: longest,
        level: lvl.level,
        levelName: lvl.name,
        lastGreenDay: key,
        updatedAt: FieldValue.serverTimestamp(),
      });

      if (lvl.level !== previousLevel) {
        tx.set(col.events(pactId).doc(), {
          type: "level_up",
          level: lvl.level,
          message: lvl.name + " unlocked.",
          createdAt: FieldValue.serverTimestamp(),
        });
      }
    }

    const proof = { photoUrl, photoPath, submittedAt: FieldValue.serverTimestamp() };

    tx.set(
      dayRef,
      {
        dayKey: key,
        pactId,
        members,
        statuses,
        checkins: { [uid]: proof },
        resolved: false,
        streakAfter: streak,
        createdAt: day.exists ? day.get("createdAt") : FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(col.checkins(pactId).doc(key + "__" + uid), { pactId, uid, dayKey: key, ...proof });

    // Lifetime counters. `totalExpected` is normally advanced by the nightly
    // rollover; raising the floor here keeps reliability honest for a user who
    // checks in on their very first day.
    const totalCheckins = (me.get("totalCheckins") ?? 0) + 1;
    const totalExpected = Math.max(me.get("totalExpected") ?? 0, totalCheckins);
    tx.update(meRef, {
      totalCheckins,
      totalExpected,
      reliability: reliabilityOf(totalCheckins, totalExpected),
      longestStreak: Math.max(me.get("longestStreak") ?? 0, streak),
      lastCheckInAt: FieldValue.serverTimestamp(),
      lastActiveAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { alreadyDone: false, streak, bothGreen, members };
  });

  if (!outcome.alreadyDone) {
    const partner = outcome.members.find((m) => m !== uid);
    if (partner) {
      const me = await col.users().doc(uid).get();
      const name = me.get("username") ?? "Your partner";
      await sendToUsers(
        [partner],
        outcome.bothGreen
          ? {
              title: "Day " + outcome.streak + " secured.",
              body: "You and " + name + " both showed up.",
              data: { type: "streak_up", pactId },
            }
          : {
              title: name + " checked in.",
              body: "Your half of the Pact is still open.",
              data: { type: "partner_checked_in", pactId },
            }
      );
    }
    logger.info("check-in recorded", { uid, pactId, bothGreen: outcome.bothGreen });
  }

  return { ok: true, streak: outcome.streak, bothGreen: outcome.bothGreen };
});
