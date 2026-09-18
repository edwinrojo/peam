import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Android values from `android/app/google-services.json`.
/// iOS is omitted until `ios/Runner/GoogleService-Info.plist` is added.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('PEAM does not use Firebase on web.');
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      _ => throw UnsupportedError(
        'Firebase is only configured for Android so far. Add an iOS app in '
        'Firebase and ios/Runner/GoogleService-Info.plist to enable iPhone.',
      ),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCtt-e6NcT1mwXIeZkIyXwVIwhWvvyIHDg',
    appId: '1:1092448432341:android:34ddd6862300b9ef0f725c',
    messagingSenderId: '1092448432341',
    projectId: 'peam-c985d',
    storageBucket: 'peam-c985d.firebasestorage.app',
  );
}
