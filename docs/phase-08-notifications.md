# Phase 8 — Notifications

## The schedule

`sendReminders` runs hourly, asks each active pact what time it is *in that
pact's timezone*, and only messages members who are still pending today.

| Local hour | Title | Body |
|---|---|---|
| 09:00 | **Don't break the Pact.** | One photo. That is the whole deal. |
| 19:00 | **Someone is counting on you.** | Your partner cannot save this one for you. |
| 23:00 | **Your partner's streak is at risk.** | Under an hour left. Check in now. |

Past the first day, the evening and deadline bodies gain `"N-day streak on the
line."` — the number is the whole argument, so it goes in as soon as there is
one.

Event-driven pushes, sent from the functions that cause them:

| Trigger | Message |
|---|---|
| matched | *You have a Pact.* — `{partner} is counting on you from today.` |
| partner checks in first | *{partner} checked in.* — Your half of the Pact is still open. |
| both green | *Day N secured.* — You and {partner} both showed up. |
| pact broken | *Your Pact has been broken.* — names who missed |

## Why nobody gets nagged about something they did

The reminder job reads today's day document and filters to `statuses[uid] !=
"green"`. A user who checked in at 07:00 hears nothing else that day except
their partner's good news. The fastest way to get uninstalled is to be told to
do something already done.

Three scheduled nudges a day is the ceiling, and the last one only fires for
people genuinely at risk.

## Token lifecycle

```
init(uid)  → request permission → getToken → users/{uid}.fcmTokens arrayUnion
           → onTokenRefresh → arrayUnion
signOut    → arrayRemove for this device
send       → sendEachForMulticast → prune tokens FCM reports as dead
```

Dead-token pruning matters more than it looks: without it, arrays grow forever,
every send costs more, and delivery stats become fiction.

## Android specifics

- **Channel `pact_reminders`** is created in `NotificationRepository.init` *and*
  declared as the FCM default in `AndroidManifest.xml`. Both must say the same
  string or messages that arrive while the app is dead land in a silent channel.
- **Icon** must be white-on-transparent — `res/drawable/ic_stat_pact.xml`.
  A coloured icon renders as a grey square on Android 5+.
- **Android 13+** requires the runtime `POST_NOTIFICATIONS` grant. Pact asks
  once, after sign-in, and never gates a feature behind it. A user who declines
  still has a working app; they just have to remember on their own.
- **Foreground messages** are not drawn by FCM, so `FirebaseMessaging.onMessage`
  hands them to `flutter_local_notifications`.
- **Background isolate**: `_onBackgroundMessage` in `main.dart` is a top-level
  `@pragma('vm:entry-point')` function that re-initialises Firebase. Without it,
  data payloads crash a fresh isolate.

## Cost and pacing

Roughly three scheduled sends per unmatched-today user plus a handful of event
pushes. FCM is free; the cost is attention, and the budget for attention is much
smaller than the budget for messages.

## Test checklist

- [ ] Check in at 08:00 → no 09:00, 19:00 or 23:00 reminder that day
- [ ] Do not check in → exactly three reminders, at the pact's local hours
- [ ] Partner checks in → you get one push, they get none
- [ ] Kill the app, trigger a reminder → tray notification with the right icon
- [ ] Decline the permission prompt → app still fully functional
- [ ] Sign out → this device goes quiet, the other one does not
