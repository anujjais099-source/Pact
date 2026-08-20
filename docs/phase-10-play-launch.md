# Phase 10 — Google Play Launch

## 1. Signing

```bash
cd app/android
keytool -genkey -v -keystore pact-upload.jks -keyalg RSA -keysize 2048 \
        -validity 10000 -alias pact-upload
cp key.properties.example key.properties     # fill in, never commit
```

`app/build.gradle` reads `key.properties` when present and falls back to debug
keys when it is not, so a fresh clone still builds. Back the keystore up
somewhere you will still have in three years — losing it means you cannot ship
an update to your own app.

## 2. Icons and store art

```bash
# put a 1024x1024 PNG at app/assets/icons/app_icon.png first
cd app && flutter pub run flutter_launcher_icons
```

Store listing needs: 512×512 icon, 1024×500 feature graphic, 2–8 phone
screenshots (Home with a live streak, the camera screen, the break screen — in
that order; the break screen is the product).

## 3. Build

```bash
cd app
flutter clean && flutter pub get
flutter build appbundle --release
# app/build/app/outputs/bundle/release/app-release.aab
```

Verify before uploading:

```bash
flutter build apk --release --split-per-abi   # sanity check size
flutter install --release                     # smoke test on a real device
```

## 4. Play Console setup

- **App content**: privacy policy URL (required — you collect email and photos),
  ads: none, content rating questionnaire, target audience 18+.
- **Data safety**: declare email address, photos, and approximate usage data;
  state that photos are shared with one other user, encrypted in transit, and
  that users can request deletion.
- **Permissions**: `CAMERA` is justified by the core loop — say so in one
  sentence: *"Pact requires a live photo as daily proof of a habit; images are
  visible only to the user's single matched partner."*
- **Testing track**: internal → closed (20 testers, 14 days is Play's
  requirement for personal developer accounts) → production.

## 5. Pre-launch checklist

- [ ] `firebase deploy --only firestore:rules,storage,firestore:indexes,functions`
- [ ] Rules tested: partner's user doc unreadable, streak unwritable from client
- [ ] Scheduled jobs visible in Cloud Scheduler and green after 24h
- [ ] Crashlytics or Sentry wired (not in this MVP — add before scale)
- [ ] Analytics events firing: `pact_signed_up`, `pact_goal_set`, `pact_matched`,
      `pact_check_in`, `pact_broken`
- [ ] Cold-start on a low-end device under 3s to first paint
- [ ] Camera tested on at least three OEM skins (Samsung, Xiaomi, Pixel)
- [ ] Reminder pushes verified in three timezones
- [ ] Account deletion path documented (Play requires it — a callable that wipes
      `users/{uid}`, releases the username, and ends any active pact)

## 6. Launch metrics that matter

The retention question for Pact is not DAU. It is:

| Metric | Why | Healthy at MVP |
|---|---|---|
| **D1 check-in rate** | Did the loop start at all? | > 60% |
| **Match → first check-in** | The riskiest hop in the funnel | > 75% |
| **Median streak length** | Is the mechanic working? | 4+ days |
| **% pacts reaching level 2** | Did the stake take hold? | > 25% |
| **Re-match rate after a break** | Does losing bring them back, or lose them? | > 50% |

That last one is the product's real test. Losing a streak because of a stranger
should make people want a better stranger, not a different app. Watch it weekly;
if it sinks, the fix is in the break screen's copy and how fast a new match
arrives, not in adding features.

## 7. What is deliberately not in the MVP

Streak freezes, pact history browsing, avatars beyond upload, leaderboards,
partner reporting/blocking, iOS. Ship the loop first.

**Before your public launch**, add two of those: a **report/block** path (Play
requires a way to report user-generated content — your users are exchanging
photos with strangers) and **account deletion**. Both are small; neither is
optional at scale.
