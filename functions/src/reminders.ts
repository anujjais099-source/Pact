import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";
import { col, REGION } from "./firebase";
import { dayKey, localHour } from "./time";
import { sendToUsers } from "./notify";
import type { DayStatus } from "./types";

type Slot = "morning" | "evening" | "deadline";

/** Local hours (in the timezone of the pact) at which each nudge fires. */
const SLOT_HOURS: Record<number, Slot> = {
  9: "morning",
  19: "evening",
  23: "deadline",
};

const COPY: Record<Slot, { title: string; body: string }> = {
  morning: {
    title: "Don't break the Pact.",
    body: "One photo. That is the whole deal.",
  },
  evening: {
    title: "Someone is counting on you.",
    body: "Your partner cannot save this one for you.",
  },
  deadline: {
    title: "Your partner's streak is at risk.",
    body: "Under an hour left. Check in now.",
  },
};

/**
 * Runs every hour. For each active pact we ask what time it is *inside that
 * pact*, and nudge only the members who are still pending today — nobody gets
 * pestered about something they already did.
 */
export const sendReminders = onSchedule(
  { region: REGION, schedule: "every 60 minutes", timeZone: "UTC", timeoutSeconds: 540 },
  async () => {
    const pacts = await col.pacts().where("status", "==", "active").get();
    let sent = 0;

    for (const pact of pacts.docs) {
      const tz: string = pact.get("timezone");
      const slot = SLOT_HOURS[localHour(tz)];
      if (!slot) continue;

      const members: string[] = pact.get("members") ?? [];
      const key = dayKey(tz);

      try {
        const day = await col.days(pact.id).doc(key).get();
        const statuses: Record<string, DayStatus> = day.get("statuses") ?? {};
        const pending = members.filter((m) => statuses[m] !== "green");
        if (pending.length === 0) continue;

        const streak: number = pact.get("streak") ?? 0;
        const copy = COPY[slot];
        const body =
          streak > 0 && slot !== "morning"
            ? copy.body + " " + streak + "-day streak on the line."
            : copy.body;

        sent += await sendToUsers(pending, {
          title: copy.title,
          body,
          data: { type: "reminder", slot, pactId: pact.id },
        });
      } catch (err) {
        logger.error("reminder failed", { pactId: pact.id, err });
      }
    }

    logger.info("sendReminders complete", { pacts: pacts.size, sent });
  }
);
