import { logger } from "firebase-functions";
import { col, db, FieldValue, messaging } from "./firebase";

export interface PushPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

const DEAD_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

/**
 * Fans a notification out to every device of every uid, then prunes tokens FCM
 * reports as dead so the token arrays do not rot.
 */
export async function sendToUsers(uids: string[], payload: PushPayload): Promise<number> {
  if (uids.length === 0) return 0;

  const snaps = await db.getAll(...uids.map((uid) => col.users().doc(uid)));
  const tokenOwner = new Map<string, string>();

  for (const snap of snaps) {
    if (!snap.exists) continue;
    if (snap.get("notificationsEnabled") === false) continue;
    const tokens: string[] = snap.get("fcmTokens") ?? [];
    for (const t of tokens) tokenOwner.set(t, snap.id);
  }

  const tokens = [...tokenOwner.keys()];
  if (tokens.length === 0) return 0;

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: { title: payload.title, body: payload.body },
    data: { ...(payload.data ?? {}), click_action: "FLUTTER_NOTIFICATION_CLICK" },
    android: {
      priority: "high",
      notification: {
        channelId: "pact_reminders",
        color: "#7C5CFF",
        icon: "ic_stat_pact",
      },
    },
  });

  const dead: Array<{ uid: string; token: string }> = [];
  response.responses.forEach((res, i) => {
    if (!res.success && res.error && DEAD_TOKEN_CODES.has(res.error.code)) {
      dead.push({ uid: tokenOwner.get(tokens[i])!, token: tokens[i] });
    }
  });

  if (dead.length > 0) {
    const batch = db.batch();
    for (const { uid, token } of dead) {
      batch.update(col.users().doc(uid), { fcmTokens: FieldValue.arrayRemove(token) });
    }
    await batch.commit();
    logger.info("pruned dead tokens", { count: dead.length });
  }

  return response.successCount;
}
