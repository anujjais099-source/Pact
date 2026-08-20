# Phase 7 — Shared Streak Engine

The one piece of this app that must never be wrong.

## Two halves

**Increment** happens live, inside `submitCheckIn`, at the moment the *second*
member goes green. It has to be immediate — the reward for showing up cannot
arrive tomorrow morning.

**Judgement** happens in `rolloverPactDays`, hourly, after a day has fully
elapsed in the pact's timezone. Only then can "missed" mean anything.

## The rollover, in order

```
for each pact where status == "active":
  fromKey = lastEvaluatedDay ? lastEvaluatedDay + 1 : startDayKey
  toKey   = yesterday, in the pact's timezone
  if fromKey > toKey: refresh daysTogether, done

  for each dayKey in [fromKey .. toKey]:
     missing = members where statuses[uid] != "green"
     if none missing → mark the day resolved, keep going
     else            → mark the missers red, break the pact, stop
```

`lastEvaluatedDay` is a watermark, which makes the whole job **idempotent**. Run
it twice in a minute, or once after three days of downtime, and the end state is
identical. That property is worth more than any amount of clever scheduling: it
means a failed run is a non-event.

## Breaking

When a day comes up short, in the same transaction:

| Document | Change |
|---|---|
| `pacts/{id}` | `status: broken`, `streak: 0`, `brokenBy`, `brokenOnDay`, `brokenAt`, level reset |
| `pacts/{id}/days/{key}` | missers set to `red`, `resolved: true`, `streakAfter: 0` |
| `pacts/{id}/events` | a `broken` event carrying `streakLost` |
| both `users/{uid}` | `currentPactId: null`, `status: idle`, `totalPacts +1`, `longestStreak` kept, `missedDays +1` for the miss, `totalExpected` advanced, reliability recomputed |
| `users/{uid}/pactHistory/{pactId}` | a permanent record, including `brokenByMe` |

Then both partners get one push: **"Your Pact has been broken."**

The person who showed up loses the streak too. That is the entire product. It is
also why the break screen names who missed — carrying someone else's failure is
bearable; not knowing which of you failed is not.

## Levels

Derived, never stored as truth (`functions/src/levels.ts`, mirrored in
`app/lib/data/models/pact_level.dart`):

| Streak | Level |
|---|---|
| 1–7 | Level 1 Pact |
| 8–14 | Level 2 Pact |
| 15–30 | Level 3 Pact |
| 31+ | Legendary Pact |

Crossing a boundary writes a `level_up` event and the success screen announces
it. Partners are kept until the streak breaks, so a Legendary Pact is a
relationship with real weight behind it.

## Reliability

```
reliability = totalCheckins / max(totalExpected, totalCheckins) × 100
```

`totalExpected` advances one per pact-day during the rollover; `totalCheckins`
advances at check-in. The `max` is not cosmetic — it stops a user who checks in
on day one from briefly showing 200%, and it holds the number in [0, 100]
without a clamp that would hide a real accounting bug.

Reliability survives every break. It is the only cross-pact reputation in the
app, which is why it is on the match screen: it is what a stranger knows about
you before you have shown them anything.

## Timezones

One IANA zone per pact, set at creation from the longest-waiting member's
device. Day keys are `YYYY-MM-DD` computed in that zone — with `luxon` on the
server, the `timezone` package on the client. Both produce identical strings,
which is why `dayKey` can be a document id and comparisons can be plain string
comparisons.

## Test checklist

- [ ] Both check in → streak +1 immediately on both devices
- [ ] One checks in, the other does not, run rollover → pact broken, both idle
- [ ] Run rollover twice → nothing changes the second time
- [ ] Skip the job for three days, then run → breaks on the *first* missed day
- [ ] Streak 7 → 8 → level 2 announced once, not on every subsequent check-in
- [ ] Reliability after 9 of 10 days → 90%

Use `scripts/simulate-day.mjs` against the emulator to drive these without
waiting for midnight, or call the `rolloverPactNow` callable from a client.
