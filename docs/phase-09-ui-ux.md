# Phase 9 — UI / UX Implementation

## Design position

Dark, minimal, one accent, premium. Duolingo's streak stakes, BeReal's proof
mechanic, Notion's restraint, Headspace's calm. The app has **nine screens** and
one loop; everything that does not serve "do I check in right now?" was left out.

Dark only. A light theme doubles the surface area of every state in the app and
buys nothing for a product used at 7am and 11pm.

## Tokens

```dart
PactColors.black         #07070A   app ground
PactColors.surfaceRaised #16161F   cards
PactColors.violet        #7C5CFF   the single accent
PactColors.green         #3DDC97   completed
PactColors.red           #FF5A6E   missed / final hour
PactColors.amber         #FFB84D   pending
Gap.xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · huge 48
Radii.sm 10 · md 16 · lg 22 · pill 999
```

Colour carries one meaning only: **status**. Levels borrow the same family
(violet → blue → green → gold) so progress reads as a journey rather than a
palette. Nothing else in the app is coloured, which is why the streak number
lands.

Type scale is one family with tight negative tracking on the big sizes:
72/44/26/19/16/15.5/14. Drop `Inter` into `assets/fonts/` and register it in
`pubspec.yaml` to finish the look; the theme already names it and falls back to
Roboto.

## Screen by screen

| Screen | The one job |
|---|---|
| Welcome | Make the stake obvious in three lines |
| Sign up | Username availability answered while typing |
| Verify email | Poll silently so the user never has to tap anything |
| Goal setup | Six presets, because a blank field kills motivation |
| Matchmaking | Keep talking during the weakest moment in the funnel |
| **Home** | Answer "do I check in right now?" without scrolling |
| Camera | Nothing but a shutter, and no route to the gallery |
| Success | Distinguish *you are done* from *you are both done* |
| Match | Everything you may know about your partner, and why that is all |
| Profile | Lifetime record: pacts, longest streak, reliability, goal |
| Pact broken | State the fact, name who missed, offer one way forward |

## Home, in order down the screen

1. **Streak ring** — the number, the level band, and an arc that fills toward
   the next level. Animates on change, glows when both are green.
2. **Deadline banner** — quiet grey all day, red inside the final hour with
   *"{time} left. Your partner is exposed."* The clock is the pressure.
3. **Today** — two symmetrical tiles, you and them. Symmetry is the message:
   neither half counts alone.
4. **Partner card** — avatar, goal, reliability, status, submission time. It
   opens a detail screen and nothing else — there is nowhere to tap that starts
   a conversation.
5. **The Pact** — days together, level, reliability, and a fourteen-day dot
   strip.
6. **Check-in button**, pinned at thumb height. It turns red in the last hour
   and becomes a static "Checked in today" once it is done.

## Motion

Four animations, all of them meaning something: the streak ring filling (900ms
easeOutCubic), the success seal (420ms easeOutBack), the matchmaking rings
drifting together, and the shutter. Nothing else moves.

## Accessibility

Text scaling is clamped to 0.9–1.3 rather than ignored. Status is never colour
alone — every pill carries a word (Completed / Missed / Pending). Tap targets
are 48pt minimum; the primary button is 56. Contrast on `textPrimary` over
`black` is ~15:1, and `textSecondary` ~7:1.

## Empty and error states

Every async surface has three states written by hand: loading (`PactLoader`),
error (`PactError` with Retry), and content. There is no spinner-forever screen
in the app — the router's splash is the only place a spinner appears without a
sentence next to it.
