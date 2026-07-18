import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAsVxXHCQ_gtC7cwhbPbKAf5hNDnlzs1Ck',
    appId: '1:1079951210273:web:placeholder_web_app_id',
    messagingSenderId: '1079951210273',
    projectId: 'spotify-e2ab7',
    authDomain: 'spotify-e2ab7.firebaseapp.com',
    storageBucket: 'spotify-e2ab7.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAsVxXHCQ_gtC7cwhbPbKAf5hNDnlzs1Ck',
    appId: '1:1079951210273:android:052c66ed9864ff5ae23060',
    messagingSenderId: '1079951210273',
    projectId: 'spotify-e2ab7',
    storageBucket: 'spotify-e2ab7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'placeholder-ios-api-key',
    appId: 'placeholder-ios-app-id',
    messagingSenderId: '1079951210273',
    projectId: 'spotify-e2ab7',
    storageBucket: 'spotify-e2ab7.firebasestorage.app',
    iosBundleId: 'com.example.spotify',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'placeholder-macos-api-key',
    appId: 'placeholder-macos-app-id',
    messagingSenderId: '1079951210273',
    projectId: 'spotify-e2ab7',
    storageBucket: 'spotify-e2ab7.firebasestorage.app',
    iosBundleId: 'com.example.spotify',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'placeholder-windows-api-key',
    appId: 'placeholder-windows-app-id',
    messagingSenderId: '1079951210273',
    projectId: 'spotify-e2ab7',
    storageBucket: 'spotify-e2ab7.firebasestorage.app',
  );
}
