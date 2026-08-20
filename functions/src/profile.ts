import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { col, db, FieldValue, REGION } from "./firebase";
import { safeZone } from "./time";
import type { UserDoc } from "./types";

const USERNAME_RE = /^[a-zA-Z0-9_]{3,20}$/;
const RESERVED = new Set(["pact", "admin", "support", "root", "system", "moderator", "help"]);

// Empty is allowed: sign-up claims the username, the goal is picked one screen
// later. `requestMatch` is what refuses to run without a goal.
function normaliseGoal(goal: unknown): string {
  const g = String(goal ?? "").trim();
  if (g.length === 0) return "";
  if (g.length < 2 || g.length > 40) {
    throw new HttpsError("invalid-argument", "Goal must be 2-40 characters.");
  }
  return g;
}

/**
 * Claims the username and creates the profile document in one transaction.
 * Two people racing for "alex" — exactly one wins, deterministically.
 */
export const createProfile = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  const email = request.auth?.token.email ?? "";
  if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

  const username = String(request.data?.username ?? "").trim();
  const goalName = normaliseGoal(request.data?.goalName);
  const timezone = safeZone(request.data?.timezone);

  if (!USERNAME_RE.test(username)) {
    throw new HttpsError("invalid-argument", "3–20 letters, numbers or underscores.");
  }
  const lower = username.toLowerCase();
  if (RESERVED.has(lower)) {
    throw new HttpsError("already-exists", "That username is reserved.");
  }

  const userRef = col.users().doc(uid);
  const nameRef = col.usernames().doc(lower);

  await db.runTransaction(async (tx) => {
    const [nameSnap, userSnap] = await Promise.all([tx.get(nameRef), tx.get(userRef)]);

    if (nameSnap.exists && nameSnap.get("uid") !== uid) {
      throw new HttpsError("already-exists", "Username is taken.");
    }

    if (userSnap.exists) {
      // Re-running onboarding: allow a rename, release the old name.
      const previous = userSnap.get("usernameLower") as string | undefined;
      if (previous && previous !== lower) {
        tx.delete(col.usernames().doc(previous));
      }
      const patch: Record<string, unknown> = {
        username,
        usernameLower: lower,
        timezone,
        updatedAt: FieldValue.serverTimestamp(),
      };
      // Never clobber an existing goal with the empty sign-up placeholder.
      if (goalName) {
        patch.goalName = goalName;
        patch.goalUpdatedAt = FieldValue.serverTimestamp();
      }
      tx.update(userRef, patch);
    } else {
      const doc: UserDoc & Record<string, unknown> = {
        uid,
        username,
        usernameLower: lower,
        email,
        emailVerified: request.auth?.token.email_verified === true,
        avatarUrl: null,
        goalName,
        timezone,
        fcmTokens: [],
        notificationsEnabled: true,
        status: "idle",
        currentPactId: null,
        reliability: 100,
        totalCheckins: 0,
        totalExpected: 0,
        missedDays: 0,
        totalPacts: 0,
        longestStreak: 0,
        streakSafe: false,
      };
      tx.set(userRef, {
        ...doc,
        goalUpdatedAt: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        lastActiveAt: FieldValue.serverTimestamp(),
      });
    }

    tx.set(nameRef, { uid, username, claimedAt: FieldValue.serverTimestamp() });
  });

  logger.info("profile created", { uid, username });
  return { ok: true, username };
});

/** Lightweight availability probe for the sign-up form. */
export const checkUsername = onCall({ region: REGION }, async (request) => {
  const username = String(request.data?.username ?? "").trim();
  if (!USERNAME_RE.test(username)) return { available: false, reason: "invalid" };
  const lower = username.toLowerCase();
  if (RESERVED.has(lower)) return { available: false, reason: "reserved" };
  const snap = await col.usernames().doc(lower).get();
  const available = !snap.exists || snap.get("uid") === request.auth?.uid;
  return { available, reason: available ? null : "taken" };
});

/**
 * A partner's card is rendered from `pacts.memberInfo`, never from their user
 * document (which the rules keep private). Keep that copy fresh.
 */
export const syncMemberInfo = onDocumentUpdated(
  { region: REGION, document: "users/{uid}" },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const watched = ["username", "avatarUrl", "goalName", "reliability"] as const;
    const changed = watched.some((k) => before[k] !== after[k]);
    if (!changed) return;

    const pactId = after.currentPactId as string | null;
    if (!pactId) return;

    const uid = event.params.uid;
    await col.pacts().doc(pactId).set(
      {
        memberInfo: {
          [uid]: {
            username: after.username,
            avatarUrl: after.avatarUrl ?? null,
            goalName: after.goalName,
            reliability: after.reliability,
          },
        },
      },
      { merge: true }
    );
  }
);
