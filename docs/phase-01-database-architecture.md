# Phase 1 — Database Architecture

> Principle: **the client is a renderer, not an authority.** Streaks, reliability,
> levels, and match assignment are written only by Cloud Functions (Admin SDK).
> Firestore rules deny every one of those writes to the app.

## Collection map

```
users/{uid}                                  profile + lifetime stats
users/{uid}/pactHistory/{pactId}             one row per finished pact
usernames/{usernameLower}                    uniqueness registry -> { uid }
matchQueue/{uid}                             who is waiting for a partner
pacts/{pactId}                               the live shared contract
pacts/{pactId}/days/{dayKey}                 one doc per calendar day (YYYY-MM-DD)
pacts/{pactId}/checkins/{dayKey}__{uid}      immutable proof records
pacts/{pactId}/events/{eventId}              level-ups, breaks (Home timeline)
meta/config                                  public app config / kill switches
```

Cloud Storage:

```
avatars/{uid}/{fileName}.jpg
checkins/{pactId}/{dayKey}/{uid}.jpg         write-once, readable by 2 members
```

## `users/{uid}`

| field | type | owner | notes |
|---|---|---|---|
| `uid` | string | client (create) | mirrors doc id |
| `username` | string | server | 3–20 chars, display case preserved |
| `usernameLower` | string | server | lowercase, matches `usernames/` key |
| `email` | string | client | from Firebase Auth |
| `emailVerified` | bool | client | mirrored from the Auth token |
| `avatarUrl` | string? | client | Storage download URL |
| `goalName` | string | client | "Gym", "Study", … max 40 chars |
| `goalUpdatedAt` | timestamp | client | |
| `timezone` | string | client | IANA, e.g. `Asia/Kolkata` |
| `reminderHourBucket` | number | client | local UTC-offset bucket, indexed for the reminder fan-out |
| `fcmTokens` | string[] | client | max 5, de-duplicated |
| `notificationsEnabled` | bool | client | |
| `status` | string | server | `idle` \| `searching` \| `matched` |
| `currentPactId` | string? | server | null when unmatched |
| `reliability` | number | server | 0–100, one decimal |
| `totalCheckins` | number | server | successful check-ins, lifetime |
| `totalExpected` | number | server | days they were *in* a pact, lifetime |
| `missedDays` | number | server | |
| `totalPacts` | number | server | pacts finished (broken or ended) |
| `longestStreak` | number | server | best shared streak ever reached |
| `streakSafe` | bool | server | reserved for a future one-time freeze |
| `createdAt` / `updatedAt` / `lastActiveAt` | timestamp | mixed | |

**Reliability** = `totalCheckins / max(totalExpected, totalCheckins) × 100`,
recomputed inside the same transaction that moves either counter, so it can
never exceed 100 or flicker.

## `pacts/{pactId}`

| field | type | notes |
|---|---|---|
| `members` | string[2] | sorted uids — every read rule keys off this |
| `memberInfo` | map<uid, {username, avatarUrl, goalName, reliability}> | denormalised so a partner is visible **without** granting read access to their user doc |
| `status` | string | `active` \| `broken` \| `ended` |
| `streak` | number | current shared streak |
| `longestStreak` | number | best this pact reached |
| `level` | number | 1–4, derived from `streak` |
| `levelName` | string | `Level 1 Pact` … `Legendary Pact` |
| `timezone` | string | IANA; **one** timezone governs the whole pact so both partners share an identical midnight |
| `startDayKey` | string | `YYYY-MM-DD`, first day that counts |
| `lastEvaluatedDay` | string? | rollover watermark — makes the daily job idempotent |
| `daysTogether` | number | calendar days since `startDayKey` |
| `createdAt` / `brokenAt` / `endedAt` | timestamp | |
| `brokenBy` | string[] | uids that missed the fatal day |

## `pacts/{pactId}/days/{dayKey}`

```jsonc
{
  "dayKey": "2026-08-19",
  "pactId": "…",
  "members": ["uidA", "uidB"],
  "statuses": { "uidA": "green", "uidB": "pending" },   // pending | green | red
  "checkins": {
    "uidA": { "photoUrl": "https://…", "photoPath": "checkins/…", "submittedAt": <ts> }
  },
  "resolved": false,        // set by the nightly rollover
  "streakAfter": 12,        // streak value once the day closed
  "createdAt": <ts>
}
```

`dayKey` is computed **in the pact's timezone**, on both the client (`timezone`
package) and the server (`luxon`), so the two never disagree about which day it is.

## `matchQueue/{uid}`

```jsonc
{ "uid": "…", "goalName": "Gym", "timezone": "Asia/Kolkata",
  "reliability": 92.5, "status": "waiting", "joinedAt": <ts> }
```

Entry is created and destroyed only by `requestMatch` / `cancelMatch` /
`sweepMatchQueue`. Doc id = uid, which makes double-enqueueing impossible.

## Write ownership summary

| Mutation | Who |
|---|---|
| create profile, claim username | `createProfile` callable |
| edit avatar / goal / timezone / tokens | client (rules-limited field set) |
| enter or leave the queue | `requestMatch` / `cancelMatch` callables |
| create a pact | `requestMatch` or `sweepMatchQueue` |
| record a check-in, bump the streak | `submitCheckIn` callable |
| break a pact, count a miss, close a day | `rolloverPactDays` scheduler |
| send reminders | `sendReminders` scheduler |

Everything else: **denied**.
