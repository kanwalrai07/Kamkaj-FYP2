import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAT0PTLaf8sADjNiTCfxR2v6qDFDB4R9n0',
    appId: '1:1084398802536:android:c18185c657414addad0ddd',
    messagingSenderId: '1084398802536',
    projectId: 'kamkaj-d64b5',
    databaseURL: 'https://kamkaj-d64b5-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'kamkaj-d64b5.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAT0PTLaf8sADjNiTCfxR2v6qDFDB4R9n0',
    appId: '1:1084398802536:web:c18185c657414addad0ddd',
    messagingSenderId: '1084398802536',
    projectId: 'kamkaj-d64b5',
    authDomain: 'kamkaj-d64b5.firebaseapp.com',
    databaseURL: 'https://kamkaj-d64b5-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'kamkaj-d64b5.firebasestorage.app',
    measurementId: 'G-7F9H8J5K2L',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can re-configure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can re-configure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can re-configure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can re-configure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}
