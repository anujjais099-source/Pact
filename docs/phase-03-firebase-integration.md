

10.0.2.2 is the Android emulator's alias for your host machine; pass
`--dart-define=EMULATOR_HOST=<lan-ip>` for a physical device.# Phase 3 — Firebase Integration

## Console setup (once)

1. **Authentication → Sign-in method → Email/Password**: enable. Leave email
   link (passwordless) off.
2. **Authentication → Templates → Email address verification**: set the sender
   name to `Pact` and the subject to `Verify your email to start your Pact`.
3. **Firestore Database**: create in production mode, pick a region close to
   your first market and never change it.
4. **Storage**: create the default bucket.
5. **Project settings → Cloud Messaging**: note the sender id.

## Wire the app

```bash
dart pub global activate flutterfire_cli
cd app
flutterfire configure --project=pact-mvp --platforms=android
```

This rewrites `lib/firebase_options.dart` with real keys and drops
`android/app/google-services.json`. Both are git-ignored except the options
file, which is safe to commit (the Android API key is a client identifier, not a
secret — your rules are the security boundary).

## Deploy the backend

```bash
cd functions && npm install && npm run build && cd ..
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

Scheduled functions (`sweepMatchQueue`, `rolloverPactDays`, `sendReminders`)
need the Blaze plan and enable Cloud Scheduler on first deploy.

## The provider seam

Everything Firebase enters the app through `data/services/firebase_service.dart`:

```dart
final firestoreProvider = Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);
final functionsProvider = Provider<FirebaseFunctions>(
  (_) => FirebaseFunctions.instanceFor(region: 'us-central1'),
);
```

Tests override these with fakes; nothing else in the app knows Firebase by name.
`Paths` in the same file is the only place a collection name is spelled out —
if `pacts/{id}/days/{dayKey}` ever moves, it moves once.

## Emulator wiring

`main.dart` already carries this, behind a dart-define:

```dart
Future<void> _connectEmulatorsIfAsked() async {
  const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  if (!useEmulator) return;

  const host = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  FirebaseFunctions.instanceFor(region: 'us-central1').useFunctionsEmulator(host, 5001);
}
```

```bash
firebase emulators:start
flutter run --dart-define=USE_EMULATOR=true
```

10.0.2.2 is the Android emulator's alias for the host machine; pass
`--dart-define=EMULATOR_HOST=<your-lan-ip>` when testing on a physical device.

## Regions

Functions are pinned to `us-central1` in `functions/src/firebase.ts` and in
`functionsProvider`. If you move them, change both — a mismatch fails with an
opaque `NOT_FOUND` on every callable.

## Cost shape at MVP scale

Per active pair per day: 2 check-in writes, ~6 document reads on Home, one
~180 KB photo, and 2–6 push messages. Ten thousand pairs land inside single
digit dollars a day, dominated by Storage. If that changes, the first lever is a
lifecycle rule expiring `checkins/` objects after 30 days — the streak lives in
Firestore, not in the pixels.
