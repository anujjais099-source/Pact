/**
 * Pact — Cloud Functions entry point.
 *
 * Callables (client-invoked):
 *   createProfile     claim username + create the profile document
 *   checkUsername     availability probe for the sign-up form
 *   requestMatch      join the pool, pair instantly when possible
 *   cancelMatch       leave the pool
 *   submitCheckIn     record proof, advance the shared streak
 *   rolloverPactNow   support/QA hook to force a day evaluation
 *
 * Triggers / schedules:
 *   syncMemberInfo    keeps the partner card fresh (users onUpdate)
 *   sweepMatchQueue   every 1 min  — pairs leftovers
 *   rolloverPactDays  every 60 min — closes elapsed days, breaks pacts
 *   sendReminders     every 60 min — morning / evening / deadline nudges
 */
export { createProfile, checkUsername, syncMemberInfo } from "./profile";
export { requestMatch, cancelMatch, sweepMatchQueue } from "./matchmaking";
export { submitCheckIn } from "./checkins";
export { rolloverPactDays, rolloverPactNow } from "./rollover";
export { sendReminders } from "./reminders";
