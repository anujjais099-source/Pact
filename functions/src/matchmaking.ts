import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { firestore } from "firebase-admin";
import { col, db, FieldValue, REGION } from "./firebase";
import { dayKey, safeZone } from "./time";
import { levelForStreak } from "./levels";
import { sendToUsers } from "./notify";
import type { MemberInfo } from "./types";

type Tx = firestore.Transaction;
type Snap = firestore.DocumentSnapshot;

function memberInfoFrom(snap: Snap): MemberInfo {
  return {
    username: snap.get("username") ?? "Someone",
    avatarUrl: snap.get("avatarUrl") ?? null,
    goalName: snap.get("goalName") ?? "Goal",
    reliability: snap.get("reliability") ?? 100,
  };
}

function isMatchable(snap: Snap): boolean {
  return (
    snap.exists &&
    !snap.get("currentPactId") &&
    typeof snap.get("goalName") === "string" &&
    String(snap.get("goalName")).length > 0
  );
}

/**
 * Writes the pact + day-zero document and points both users at it.
 * Callers must have already read `a` and `b` inside the transaction.
 */
function bindPact(tx: Tx, a: Snap, b: Snap): string {
  const members = [a.id, b.id].sort();
  // One timezone governs the pact so both partners share an identical midnight.
  // The user who was waiting longest (a) sets it.
  const timezone = safeZone(a.get("timezone"));
  const startDayKey = dayKey(timezone);
  const level = levelForStreak(0);

  const pactRef = col.pacts().doc();
  const info: Record<string, MemberInfo> = {
    [a.id]: memberInfoFrom(a),
    [b.id]: memberInfoFrom(b),
  };

  tx.set(pactRef, {
    id: pactRef.id,
    members,
    memberInfo: info,
    status: "active",
    streak: 0,
    longestStreak: 0,
    level: level.level,
    levelName: level.name,
    timezone,
    startDayKey,
    lastEvaluatedDay: null,
    daysTogether: 1,
    brokenBy: [],
    createdAt: FieldValue.serverTimestamp(),
  });

  tx.set(col.days(pactRef.id).doc(startDayKey), {
    dayKey: startDayKey,
    pactId: pactRef.id,
    members,
    statuses: { [members[0]]: "pending", [members[1]]: "pending" },
    checkins: {},
    resolved: false,
    streakAfter: 0,
    createdAt: FieldValue.serverTimestamp(),
  });

  tx.set(col.events(pactRef.id).doc(), {
    type: "matched",
    createdAt: FieldValue.serverTimestamp(),
    message: "A Pact was formed.",
  });

  for (const snap of [a, b]) {
    tx.update(snap.ref, {
      currentPactId: pactRef.id,
      status: "matched",
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.delete(col.queue().doc(snap.id));
  }

  return pactRef.id;
}

async function notifyMatched(pactId: string, uids: string[], names: Record<string, string>) {
  await Promise.all(
    uids.map((uid) => {
      const partner = uids.find((u) => u !== uid)!;
      return sendToUsers([uid], {
        title: "You have a Pact.",
        body: `${names[partner] ?? "A stranger"} is counting on you from today.`,
        data: { type: "matched", pactId },
      });
    })
  );
}

/**
 * Join the pool. Either pairs instantly with the longest-waiting stranger, or
 * enqueues the caller (the sweeper picks up anyone left over).
 */
export const requestMatch = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  if (request.auth?.token.email_verified !== true) {
    throw new HttpsError("failed-precondition", "Verify your email first.");
  }

  const result = await db.runTransaction(async (tx) => {
    const meRef = col.users().doc(uid);
    const me = await tx.get(meRef);
    if (!me.exists) throw new HttpsError("not-found", "Finish setting up your profile.");
    if (me.get("currentPactId")) {
      return { pactId: me.get("currentPactId") as string, status: "matched" as const, partner: null };
    }
    if (!me.get("goalName")) throw new HttpsError("failed-precondition", "Set a goal first.");

    const waiting = await tx.get(
      col.queue().where("status", "==", "waiting").orderBy("joinedAt", "asc").limit(10)
    );

    // Firestore transactions demand every read before the first write, so the
    // candidates are fetched up front rather than inside the loop.
    const candidates = waiting.docs.filter((d) => d.id !== uid);
    const candidateUsers = await Promise.all(
      candidates.map((entry) => tx.get(col.users().doc(entry.id)))
    );

    const stale: firestore.DocumentReference[] = [];
    let partnerSnap: Snap | null = null;

    for (let i = 0; i < candidates.length; i++) {
      const other = candidateUsers[i];
      if (isMatchable(other)) {
        partnerSnap = other;
        break;
      }
      stale.push(candidates[i].ref);
    }

    for (const ref of stale) tx.delete(ref); // queue entries that went nowhere

    if (partnerSnap) {
      const pactId = bindPact(tx, partnerSnap, me);
      return {
        pactId,
        status: "matched" as const,
        partner: { uid: partnerSnap.id, username: partnerSnap.get("username") as string },
      };
    }

    tx.set(col.queue().doc(uid), {
      uid,
      goalName: me.get("goalName"),
      timezone: safeZone(me.get("timezone")),
      reliability: me.get("reliability") ?? 100,
      status: "waiting",
      joinedAt: FieldValue.serverTimestamp(),
    });
    tx.update(meRef, { status: "searching", updatedAt: FieldValue.serverTimestamp() });
    return { pactId: null, status: "searching" as const, partner: null };
  });

  if (result.status === "matched" && result.partner) {
    const me = await col.users().doc(uid).get();
    await notifyMatched(result.pactId!, [uid, result.partner.uid], {
      [uid]: me.get("username"),
      [result.partner.uid]: result.partner.username,
    });
  }
  return result;
});

/** Leave the pool. */
export const cancelMatch = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
  await db.runTransaction(async (tx) => {
    const meRef = col.users().doc(uid);
    const me = await tx.get(meRef);
    if (me.get("currentPactId")) return;
    tx.delete(col.queue().doc(uid));
    tx.update(meRef, { status: "idle", updatedAt: FieldValue.serverTimestamp() });
  });
  return { ok: true };
});

/**
 * Safety net: two people can enqueue in the same instant and each see an empty
 * pool. This pairs whatever is left over, every minute.
 */
export const sweepMatchQueue = onSchedule(
  { region: REGION, schedule: "every 1 minutes", timeZone: "UTC" },
  async () => {
    const waiting = await col
      .queue()
      .where("status", "==", "waiting")
      .orderBy("joinedAt", "asc")
      .limit(50)
      .get();

    if (waiting.size < 2) return;

    const ids = waiting.docs.map((d) => d.id);
    let paired = 0;

    for (let i = 0; i + 1 < ids.length; i += 2) {
      const [idA, idB] = [ids[i], ids[i + 1]];
      try {
        const outcome = await db.runTransaction(async (tx) => {
          const [qa, qb] = await Promise.all([
            tx.get(col.queue().doc(idA)),
            tx.get(col.queue().doc(idB)),
          ]);
          if (!qa.exists || !qb.exists) return null;

          const [a, b] = await Promise.all([
            tx.get(col.users().doc(idA)),
            tx.get(col.users().doc(idB)),
          ]);
          if (!isMatchable(a) || !isMatchable(b)) return null;

          const pactId = bindPact(tx, a, b);
          return {
            pactId,
            names: { [idA]: a.get("username") as string, [idB]: b.get("username") as string },
          };
        });

        if (outcome) {
          paired++;
          await notifyMatched(outcome.pactId, [idA, idB], outcome.names);
        }
      } catch (err) {
        logger.error("sweep pairing failed", { idA, idB, err });
      }
    }

    if (paired > 0) logger.info("sweepMatchQueue paired", { paired });
  }
);
