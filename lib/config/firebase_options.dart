import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform {
    if (!kIsWeb) {
      return null;
    }

    const fallbackApiKey = 'AIzaSyA6Nqf1wh-U2xXqzeMzknO6Q1URsBaP-E4';
    const fallbackAppId = '1:391967469264:web:a9f6805da8074a8b6238d5';
    const fallbackMessagingSenderId = '391967469264';
    const fallbackProjectId = 'revolve-4edcf';
    const fallbackAuthDomain = 'revolve-4edcf.firebaseapp.com';
    const fallbackStorageBucket = 'revolve-4edcf.firebasestorage.app';
    const fallbackMeasurementId = 'G-41ZB1QMH5Q';
    const fallbackDatabaseUrl =
      'https://revolve-4edcf-default-rtdb.firebaseio.com';

    const apiKey = String.fromEnvironment(
      'FIREBASE_WEB_API_KEY',
      defaultValue: fallbackApiKey,
    );
    const appId = String.fromEnvironment(
      'FIREBASE_WEB_APP_ID',
      defaultValue: fallbackAppId,
    );
    const messagingSenderId = String.fromEnvironment(
      'FIREBASE_WEB_MESSAGING_SENDER_ID',
      defaultValue: fallbackMessagingSenderId,
    );
    const projectId = String.fromEnvironment(
      'FIREBASE_WEB_PROJECT_ID',
      defaultValue: fallbackProjectId,
    );
    const authDomain = String.fromEnvironment(
      'FIREBASE_WEB_AUTH_DOMAIN',
      defaultValue: fallbackAuthDomain,
    );
    const storageBucket = String.fromEnvironment(
      'FIREBASE_WEB_STORAGE_BUCKET',
      defaultValue: fallbackStorageBucket,
    );
    const measurementId = String.fromEnvironment(
      'FIREBASE_WEB_MEASUREMENT_ID',
      defaultValue: fallbackMeasurementId,
    );
    const databaseUrl = String.fromEnvironment(
      'FIREBASE_WEB_DATABASE_URL',
      defaultValue: fallbackDatabaseUrl,
    );

    final requiredValues = [apiKey, appId, messagingSenderId, projectId];
    final hasRequiredValues = requiredValues.every((value) => value.isNotEmpty);

    if (!hasRequiredValues) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      measurementId: measurementId.isEmpty ? null : measurementId,
      databaseURL: databaseUrl.isEmpty ? null : databaseUrl,
    );
  }
}
