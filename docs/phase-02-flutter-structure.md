# Phase 2 — Flutter App Structure

## Commands

```bash
cd app
flutter create --platforms=android --org com.pactapp --project-name pact .
# our android/ files already exist; accept them over the generated ones,
# then bring back the two things flutter create gives you for free:
#   android/gradlew, android/gradlew.bat, app/src/main/res/mipmap-*/ic_launcher.png
flutter pub get
```

`flutter create` will not overwrite existing files, so the manifest, gradle and
`MainActivity.kt` in this repo survive. Only the wrapper scripts and launcher
icons come from it.

## Folder layout

```
app/lib/
├── main.dart                      boot: Firebase, timezone db, prefs, runApp
├── firebase_options.dart          replaced by `flutterfire configure`
├── app/
│   ├── app.dart                   MaterialApp.router + session side effects
│   ├── router.dart                go_router + the redirect funnel
│   └── routes.dart                every path, one place
├── core/
│   ├── theme/pact_colors.dart     palette, Gap, Radii
│   ├── theme/pact_theme.dart      the single dark ThemeData
│   ├── utils/pact_clock.dart      day keys + deadlines in the pact's timezone
│   ├── utils/formatters.dart      countdowns, times, percentages
│   ├── utils/validators.dart      username / email / password / goal
│   └── widgets/                   PactButton, PactScaffold, PactCard,
│                                  PactAvatar, StatusPill, DayDots, StreakRing,
│                                  StatTile, StatRow, PactLoader, PactError
├── data/
│   ├── models/                    AppUser, Pact, MemberInfo, PactDay, Proof,
│   │                              DayStatus, PactLevel
│   ├── repositories/              auth, user, pact, checkin, notification
│   └── services/firebase_service.dart  provider seam + Paths + analytics
├── features/
│   ├── auth/                      splash, welcome, sign up, sign in, verify,
│   │                              claim username (recovery)
│   ├── onboarding/                goal setup (also reused for "change goal")
│   ├── matchmaking/               searching screen
│   ├── home/                      home + widgets/partner_card.dart
│   ├── checkin/                   camera + success
│   ├── partner/                   match screen
│   ├── profile/                   profile
│   └── pact_broken/               the break screen
└── state/
    ├── providers.dart             derived streams (user, pact, today, deadline)
    ├── auth_controller.dart       AsyncNotifier for every auth action
    ├── matchmaking_controller.dart
    ├── checkin_controller.dart
    └── pact_memory.dart           remembers a pact that just broke
```

## Why the Gradle files are not committed

`android/` holds only what is genuinely ours: the manifest, `MainActivity.kt`,
resources, ProGuard rules. Every `.gradle` file is generated.

Hand-pinning AGP, Kotlin and the Gradle wrapper broke the build twice — first on
"Gradle 8.9.0 is lower than Flutter's minimum of 8.14.0", then on AGP 9 refusing
to read the old Groovy DSL at all. Pinned versions do not stay correct; they
only stay pinned.

So CI runs `flutter create` to emit the current template, then
`scripts/ci/patch-gradle.mjs` applies the four deltas Pact actually needs:

1. the `google-services` plugin, for Firebase
2. `minSdk 23`, the Firebase Auth floor
3. core library desugaring, required by `flutter_local_notifications`
4. release signing from `key.properties` when present

The patcher is idempotent and fails loudly with the exact missing anchor if the
Flutter template ever changes shape, rather than emitting a subtly broken build
file. Run it locally the same way: `node scripts/ci/patch-gradle.mjs app/android`.

## The three rules the structure enforces

1. **Screens never touch Firebase.** They read providers; providers read
   repositories; repositories are the only files that import `cloud_firestore`
   or `firebase_auth`. Swapping the backend touches `data/`, nothing else.
2. **State is derived, not copied.** `currentPactProvider` is derived from
   `currentUserProvider.currentPactId`, `todayProvider` from the pact's
   timezone. There is no cached mirror of server state to go stale.
3. **One widget per job.** If two screens need a button, it lives in
   `core/widgets/`. There is exactly one button, one card and one avatar in the
   whole app.

## Dependencies and why each one is here

| Package | Job | Why not something else |
|---|---|---|
| `flutter_riverpod` | state + DI | Compile-safe providers, no BuildContext lookups, trivially overridable in tests |
| `go_router` | routing | The funnel is one `redirect` function — auth, verification, goal, match and break states read top to bottom |
| `camera` | live capture | `image_picker` can reach the gallery. That is the one thing this product must not allow |
| `image` | JPEG resize | A 4 MB frame becomes ~180 KB before it touches the network |
| `timezone` + `flutter_timezone` | shared midnight | Both partners must agree what "today" means; matches `luxon` on the server |
| `cached_network_image` | proof photos | Yesterday's proof should not re-download |
| `flutter_local_notifications` | foreground pushes | FCM does not draw a notification while the app is open |
| `shared_preferences` | break memory | Survives the process death between "pact broke" and "user opens app" |
