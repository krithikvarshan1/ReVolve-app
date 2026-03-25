import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult({
    required this.isReady,
    this.message,
  });

  final bool isReady;
  final String? message;
}

class FirebaseBootstrap {
  static bool get isInitialized => Firebase.apps.isNotEmpty;

  static Future<FirebaseBootstrapResult> initialize() async {
    if (isInitialized) {
      return const FirebaseBootstrapResult(isReady: true);
    }

    try {
      if (kIsWeb) {
        final options = DefaultFirebaseOptions.currentPlatform;
        if (options == null) {
          return const FirebaseBootstrapResult(
            isReady: false,
            message:
                'Firebase web config is missing. Add your Firebase web keys with '
                '--dart-define before running in Chrome.',
          );
        }

        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }

      return const FirebaseBootstrapResult(isReady: true);
    } catch (error) {
      return FirebaseBootstrapResult(
        isReady: false,
        message: 'Firebase initialization failed: $error',
      );
    }
  }
}
