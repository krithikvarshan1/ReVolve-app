import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../config/app_config.dart';
import '../models/sensor_data.dart';
import '../models/alert.dart';
import '../models/device.dart';
import '../models/ml_prediction.dart';
import '../models/activity_log.dart';
import '../models/predictive_maintenance_result.dart';

class FirebaseService {
  FirebaseFirestore? get _firestoreOrNull {
    if (Firebase.apps.isEmpty) {
      return null;
    }
    return FirebaseFirestore.instance;
  }

  FirebaseDatabase? get _databaseOrNull {
    if (Firebase.apps.isEmpty) {
      return null;
    }

    final dbUrl = AppConfig.realtimeDatabaseUrl.trim();
    if (dbUrl.isNotEmpty) {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: dbUrl,
      );
    }

    return FirebaseDatabase.instance;
  }

  bool get isAvailable => _databaseOrNull != null || _firestoreOrNull != null;

  DatabaseReference _sensorRootRef(FirebaseDatabase database) {
    final sensorPath = AppConfig.realtimeSensorDataPath.trim();
    if (sensorPath.isEmpty || sensorPath == '/') {
      return database.ref('sensor_data');
    }

    final normalizedPath = sensorPath
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');

    return normalizedPath.isEmpty
      ? database.ref('sensor_data')
      : database.ref(normalizedPath);
  }

  // Sensor Data Operations
  Future<void> saveSensorData(SensorData data) async {
    final firestore = _firestoreOrNull;
    final database = _databaseOrNull;
    if (firestore == null && database == null) {
      return;
    }

    try {
      final writes = <Future<void>>[];

      if (firestore != null) {
        writes.add(
          firestore
              .collection(AppConfig.sensorDataCollection)
              .doc(data.id)
              .set(data.toJson()),
        );
      }

      if (database != null) {
        final devicePath = data.deviceId.isEmpty ? 'default_device' : data.deviceId;
        final rootRef = _sensorRootRef(database);
        writes.add(rootRef.child(devicePath).child(data.id).set(data.toJson()));
      }

      await Future.wait(writes);
    } catch (e) {
      print('Error saving sensor data: $e');
      rethrow;
    }
  }

  Stream<List<SensorData>> getSensorDataStream(String deviceId) {
    final database = _databaseOrNull;
    if (database != null) {
      final sensorRef = _sensorRootRef(database);
      final latestSensorQuery = sensorRef.orderByChild('time').limitToLast(1);

      return latestSensorQuery.onValue.map((event) {
        Map<String, dynamic>? latestData;
        String latestId = '';

        for (final child in event.snapshot.children) {
          final value = child.value;
          if (value is Map) {
            latestId = child.key ?? '';
            latestData = Map<String, dynamic>.from(
              value.map((key, inner) => MapEntry(key.toString(), inner)),
            );
          }
        }

        print('Latest sensor_data: $latestData');

        if (latestData == null) {
          return const <SensorData>[];
        }

        final parsed = SensorData.fromJson({
          ...latestData,
          if ((latestData['id'] ?? '').toString().isEmpty && latestId.isNotEmpty)
            'id': latestId,
          if ((latestData['deviceId'] ?? '').toString().isEmpty &&
              (latestData['device_id'] ?? '').toString().isEmpty &&
              deviceId.isNotEmpty)
            'deviceId': deviceId,
        });

        final normalized = parsed.id.isEmpty
            ? parsed.copyWith(
                id:
                    '${parsed.deviceId.isEmpty ? 'sensor' : parsed.deviceId}-${parsed.timestamp.millisecondsSinceEpoch}',
              )
            : parsed;

        return <SensorData>[normalized];
      });
    }

    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return const Stream<List<SensorData>>.empty();
    }

    return firestore
        .collection(AppConfig.sensorDataCollection)
        .limit(300)
        .snapshots()
        .map((snapshot) {
          final parsed = snapshot.docs
              .map(
                (doc) => SensorData.fromFirestoreDocument(
                  doc.id,
                  doc.data(),
                  fallbackDeviceId: deviceId,
                ),
              )
              .toList();

          final filtered = parsed
              .where((item) => deviceId.isEmpty || item.deviceId == deviceId)
              .toList();

          filtered.sort((a, b) => a.timestamp.compareTo(b.timestamp));

          if (filtered.length <= 100) {
            return filtered;
          }

          return filtered.sublist(filtered.length - 100);
        });
  }

  List<SensorData> _extractSensorDataEntries(
    dynamic node, {
    required String fallbackDeviceId,
  }) {
    final results = <SensorData>[];

    void visit(dynamic value, String fallbackId) {
      if (value is Map) {
        final mapped = Map<String, dynamic>.from(
          value.map((key, inner) => MapEntry(key.toString(), inner)),
        );

        if (_looksLikeSensorPayload(mapped)) {
          final parsed = SensorData.fromJson({
            ...mapped,
            if ((mapped['id'] ?? '').toString().isEmpty) 'id': fallbackId,
            if ((mapped['deviceId'] ?? '').toString().isEmpty &&
                (mapped['device_id'] ?? '').toString().isEmpty &&
                fallbackDeviceId.isNotEmpty)
              'deviceId': fallbackDeviceId,
          });
          results.add(parsed.id.isEmpty
              ? parsed.copyWith(
                  id:
                      '${parsed.deviceId.isEmpty ? 'device' : parsed.deviceId}-${parsed.timestamp.millisecondsSinceEpoch}',
                )
              : parsed);
        }

        for (final entry in mapped.entries) {
          if (entry.value is Map || entry.value is List) {
            visit(entry.value, entry.key);
          }
        }
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          visit(value[i], '$fallbackId-$i');
        }
      }
    }

    visit(node, fallbackDeviceId.isEmpty ? 'sensor' : fallbackDeviceId);
    return results;
  }

  bool _looksLikeSensorPayload(Map<String, dynamic> value) {
    const sensorKeys = <String>{
      'temperature',
      'temp',
      'temperatureC',
      'temperature_c',
      'vibration',
      'vib',
      'current',
      'currentA',
      'current_a',
      'gas',
      'gasPpm',
      'gas_ppm',
      'dust',
      'dustPpm',
      'dust_ppm',
      'sound',
      'soundDb',
      'sound_db',
      'time',
      'timestamp',
      'mpu_ax',
      'mpu_ay',
      'mpu_az',
      'adxl_x',
      'adxl_y',
      'adxl_z',
    };

    for (final key in sensorKeys) {
      if (value.containsKey(key)) {
        return true;
      }
    }
    return false;
  }

  // Alert Operations
  Future<void> saveAlert(Alert alert) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return;
    }

    try {
      await firestore
          .collection(AppConfig.alertsCollection)
          .doc(alert.id)
          .set(alert.toJson());
    } catch (e) {
      print('Error saving alert: $e');
      rethrow;
    }
  }

  Stream<List<Alert>> getAlertsStream(String deviceId) {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return const Stream<List<Alert>>.empty();
    }

    return firestore
        .collection(AppConfig.alertsCollection)
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Alert.fromJson(doc.data()))
            .toList());
  }

  Future<void> resolveAlert(String alertId) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return;
    }

    try {
      await firestore
          .collection(AppConfig.alertsCollection)
          .doc(alertId)
          .update({'isResolved': true});
    } catch (e) {
      print('Error resolving alert: $e');
      rethrow;
    }
  }

  // Device Operations
  Future<void> saveDevice(Device device) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return;
    }

    try {
      await firestore
          .collection(AppConfig.devicesCollection)
          .doc(device.id)
          .set(device.toJson());
    } catch (e) {
      print('Error saving device: $e');
      rethrow;
    }
  }

  Stream<List<Device>> getDevicesStream() {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return const Stream<List<Device>>.empty();
    }

    return firestore
        .collection(AppConfig.devicesCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Device.fromJson(doc.data()))
            .toList());
  }

  Future<void> updateDeviceRelay(String deviceId, bool status) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return;
    }

    try {
      await firestore
          .collection(AppConfig.devicesCollection)
          .doc(deviceId)
          .update({
            'relayStatus': status,
            'lastSeen': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Error updating device relay: $e');
      rethrow;
    }
  }

  // ML Prediction Operations
  Future<void> saveMLPrediction(MLPrediction prediction) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return;
    }

    try {
      await firestore
          .collection('ml_predictions') // Could be separate collection
          .doc(prediction.id)
          .set(prediction.toJson());
    } catch (e) {
      print('Error saving ML prediction: $e');
      rethrow;
    }
  }

  Future<void> savePredictiveMaintenanceResult(
    PredictiveMaintenanceResult result,
  ) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return;
    }

    try {
      await firestore
          .collection('predictive_maintenance_results')
          .doc('${result.deviceId}-${result.timestamp.millisecondsSinceEpoch}')
          .set(result.toJson());
    } catch (e) {
      print('Error saving predictive maintenance result: $e');
      rethrow;
    }
  }

  // Usage Logs
  Future<void> logUsage(String deviceId, String action, Map<String, dynamic> details) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return;
    }

    try {
      await firestore.collection(AppConfig.logsCollection).add({
        'deviceId': deviceId,
        'action': action,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error logging usage: $e');
      rethrow;
    }
  }

  Stream<List<ActivityLog>> getLogsStream(String deviceId) {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return const Stream<List<ActivityLog>>.empty();
    }

    return firestore
        .collection(AppConfig.logsCollection)
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ActivityLog.fromJson(doc.data()))
              .toList(),
        );
  }

  // Batch operations for efficiency
  Future<void> saveSensorDataBatch(List<SensorData> dataList) async {
    final firestore = _firestoreOrNull;
    if (firestore == null) {
      return;
    }

    final batch = firestore.batch();
    for (final data in dataList) {
      final docRef = firestore.collection(AppConfig.sensorDataCollection).doc(data.id);
      batch.set(docRef, data.toJson());
    }
    await batch.commit();
  }
}
