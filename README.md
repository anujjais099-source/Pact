# Pactly

**Your streak is no longer yours alone.**

Pactly pairs you with one stranger. You both commit to a daily goal, you both
check in with a live photo, and the streak belongs to the two of you. One missed
day and it is gone — for both of you. No chat, no followers, no feed.

```
pact/
├── app/            Flutter client (Android first)
├── site/           marketing page, deploys to Vercel as a static file
├── functions/      Cloud Functions — the streak, matchmaking and reminder engine
├── docs/           Phase-by-phase build guide (start at docs/phase-01)
├── scripts/        Emulator seeding + a scripted end-to-end day
├── firestore.rules storage.rules firestore.indexes.json firebase.json
```

## Why the server owns everything

The client renders; it never decides. Streaks, reliability, levels, matches and
day resolution are written only by Cloud Functions. The security rules deny
every one of those writes to the app. That is the difference between a habit
tracker and an accountability product: a streak you can edit is not a streak.

## Quick start

```bash
# 0. tooling
flutter --version                # 3.27+ / Dart 3.6+
npm  --version                   # Node 22 for functions
npm  install -g firebase-tools

# 1. Firebase project
firebase login
firebase projects:create pact-mvp        # or use an existing id
firebase use pact-mvp

# 2. wire the Flutter app to it (writes firebase_options.dart + google-services.json)
dart pub global activate flutterfire_cli
cd app && flutterfire configure --project=pact-mvp --platforms=android

# 3. dependencies
flutter pub get
cd ../functions && npm install && npm run build

# 4. rules, indexes, functions
cd .. && firebase deploy --only firestore:rules,firestore:indexes,storage,functions

# 5. run
cd app && flutter run
```

In the Firebase console, enable **Authentication → Email/Password**, create a
**Firestore** database, and create a **Storage** bucket before first run.

## Local development against the emulator

```bash
firebase emulators:start                 # auth, firestore, functions, storage, UI on :4000
npm --prefix scripts install             # once
node scripts/seed-emulator.mjs           # two verified users, matched, mid-streak
node scripts/simulate-day.mjs --miss b   # force a rollover where user B misses
```

Point the app at the emulators with a dart-define:

```bash
cd app && flutter run --dart-define=USE_EMULATOR=true
```

## The build, in ten phases

| Phase | What it lays down | Doc |
|---|---|---|
| 1 | Database architecture, rules, indexes | [docs/phase-01](docs/phase-01-database-architecture.md) |
| 2 | Flutter app structure | [docs/phase-02](docs/phase-02-flutter-structure.md) |
| 3 | Firebase integration | [docs/phase-03](docs/phase-03-firebase-integration.md) |
| 4 | Authentication + email verification | [docs/phase-04](docs/phase-04-authentication.md) |
| 5 | Matchmaking | [docs/phase-05](docs/phase-05-matchmaking.md) |
| 6 | Camera check-in | [docs/phase-06](docs/phase-06-camera-checkin.md) |
| 7 | Shared streak engine | [docs/phase-07](docs/phase-07-streak-engine.md) |
| 8 | Notifications | [docs/phase-08](docs/phase-08-notifications.md) |
| 9 | UI/UX implementation | [docs/phase-09](docs/phase-09-ui-ux.md) |
| 10 | Google Play launch | [docs/phase-10](docs/phase-10-play-launch.md) |

## The marketing site

`site/` is a single static `index.html` — the public page describing the app.
Deploy it free on Vercel:

```bash
cd site && npx vercel login && npx vercel --prod
```

Full instructions, including the two constants to edit before sharing the link,
are in [site/README.md](site/README.md).

## Status

Everything in `app/` and `functions/` is written and the functions codebase
typechecks clean (`npm --prefix functions run typecheck`). The Flutter side has
not been compiled here — no Flutter SDK on the build machine — so budget one
pass of `flutter analyze` before your first device run.
