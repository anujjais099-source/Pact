import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/utils/pact_clock.dart';
import 'demo/demo_mode.dart';
import 'demo/demo_overrides.dart';
import 'firebase_options.dart';
import 'state/pact_memory.dart';

/// Must be a top-level function: Android spins up a fresh isolate for this.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Nothing to do — the system tray draws the notification. The handler exists
  // so data-only payloads never crash the isolate.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A demo build never reaches Firebase, so it must never initialise it
  // either — a placeholder config would fail loudly on the first call.
  if (!kDemoMode) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await _connectEmulatorsIfAsked();
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
  }

  // Timezone database, loaded once: a pact has one midnight and both phones
  // must agree on it.
  await PactClock.init();

  final prefs = await SharedPreferences.getInstance();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF07070A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        if (kDemoMode) ...demoOverrides(),
      ],
      child: const PactApp(),
    ),
  );
}

/// `flutter run --dart-define=USE_EMULATOR=true` points every service at the
/// local suite. 10.0.2.2 is the Android emulator's alias for the host machine.
Future<void> _connectEmulatorsIfAsked() async {
  const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  if (!useEmulator) return;

  const host = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  await FirebaseStorage.instance.useStorageEmulator(host, 9199);
  FirebaseFunctions.instanceFor(region: 'us-central1').useFunctionsEmulator(host, 5001);
}
