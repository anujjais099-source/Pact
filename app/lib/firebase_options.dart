// GENERATED-STYLE PLACEHOLDER — replace by running:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=<your-firebase-project> --platforms=android
//
// That command overwrites this file with your real keys and drops
// android/app/google-services.json in place. The placeholder below keeps the
// project compiling before you have a Firebase project attached.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Pactly ships Android first. Web is not configured.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'No Firebase options for $defaultTargetPlatform. '
          'Run: flutterfire configure',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_ANDROID_API_KEY',
    appId: 'REPLACE_WITH_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_WITH_SENDER_ID',
    projectId: 'pact-mvp',
    storageBucket: 'pact-mvp.firebasestorage.app',
  );
}
