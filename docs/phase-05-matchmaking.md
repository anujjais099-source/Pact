# Phase 5 — Matchmaking

## The mechanism

```
requestMatch (callable)
  ├─ already in a pact?         → return it
  ├─ read the 10 oldest waiting entries
  ├─ first matchable stranger?  → bindPact(them, me), delete both queue rows
  └─ nobody waiting             → enqueue me, status = "searching"

sweepMatchQueue (every 1 minute)
  └─ pair off whatever is still waiting, oldest first
```

The sweeper exists because of one race: two users can call `requestMatch` in the
same instant, each read an empty queue, and each enqueue themselves. Without the
sweeper they would wait forever with a partner one document away. With it, the
worst case is sixty seconds.

The client never polls for the result. `MatchmakingScreen` listens to its own
user document; when the server writes `currentPactId`, the router moves it to
Home. Same path whether the match came from the callable or the sweeper.

## `bindPact` — what a new pact gets

```ts
members:      [uidA, uidB].sort()      // sorted, so rules and queries are stable
memberInfo:   { uid: { username, avatarUrl, goalName, reliability } }
status:       "active"
streak:       0
level:        1  ("Level 1 Pact")
timezone:     the longest-waiting user's zone
startDayKey:  today, in that zone
daysTogether: 1
```

Plus the day-zero document, so both people see a board the moment they land on
Home instead of an empty state that resolves a second later.

## Two decisions worth defending

**One timezone per pact.** The user who was waiting longer sets it. The
alternative — each partner judged in their own zone — means a pact can be
simultaneously alive and dead for six hours, and no copy on earth explains that.
One shared midnight is the price of the product making sense. The zone is
recorded on the pact and every day key on both clients and the server is
computed in it.

**No goal matching.** A gym partner and a thesis writer hold each other to the
same standard exactly as well, because the only thing being enforced is *did you
show up*. Filtering by goal would shrink the pool, lengthen the wait, and buy
nothing. The goal is shown for context, not used for pairing.

## Partner privacy

Firestore rules let a user read exactly one user document: their own. Everything
they see about their partner comes from `pacts/{id}.memberInfo`, a denormalised
copy holding four fields. Their partner's email, tokens, timezone and lifetime
counters are not merely hidden in the UI — they are unreadable.

`syncMemberInfo` (a `users` onUpdate trigger) keeps that copy fresh when a
username, avatar, goal or reliability changes.

## Leaving

`cancelMatch` deletes the queue row and returns the user to `idle`. It refuses
if a pact already exists — once you are matched, the only exit is the streak
breaking. That is the deal, and softening it would remove the entire stake.

## Test checklist

- [ ] Two fresh accounts request a match seconds apart → one pact, two happy clients
- [ ] Request a match with an unverified email → `failed-precondition`
- [ ] Request a match with no goal → `failed-precondition`
- [ ] Enqueue, force-quit, reopen → still searching, not double-enqueued
- [ ] Enqueue two users, wait 60s without either app open → sweeper pairs them
- [ ] Read your partner's `users/{uid}` doc from a client → permission denied
