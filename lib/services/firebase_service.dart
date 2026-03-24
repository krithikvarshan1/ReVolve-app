import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';
import '../models/sensor_data.dart';
import '../models/alert.dart';
import '../models/device.dart';
import '../models/ml_prediction.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sensor Data Operations
  Future<void> saveSensorData(SensorData data) async {
    try {
      await _firestore
          .collection(AppConfig.sensorDataCollection)
          .doc(data.id)
          .set(data.toJson());
    } catch (e) {
      print('Error saving sensor data: $e');
      rethrow;
    }
  }

  Stream<List<SensorData>> getSensorDataStream(String deviceId) {
    return _firestore
        .collection(AppConfig.sensorDataCollection)
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SensorData.fromJson(doc.data()))
            .toList());
  }

  // Alert Operations
  Future<void> saveAlert(Alert alert) async {
    try {
      await _firestore
          .collection(AppConfig.alertsCollection)
          .doc(alert.id)
          .set(alert.toJson());
    } catch (e) {
      print('Error saving alert: $e');
      rethrow;
    }
  }

  Stream<List<Alert>> getAlertsStream(String deviceId) {
    return _firestore
        .collection(AppConfig.alertsCollection)
        .where('deviceId', isEqualTo: deviceId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Alert.fromJson(doc.data()))
            .toList());
  }

  Future<void> resolveAlert(String alertId) async {
    try {
      await _firestore
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
    try {
      await _firestore
          .collection(AppConfig.devicesCollection)
          .doc(device.id)
          .set(device.toJson());
    } catch (e) {
      print('Error saving device: $e');
      rethrow;
    }
  }

  Stream<List<Device>> getDevicesStream() {
    return _firestore
        .collection(AppConfig.devicesCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Device.fromJson(doc.data()))
            .toList());
  }

  Future<void> updateDeviceRelay(String deviceId, bool status) async {
    try {
      await _firestore
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
    try {
      await _firestore
          .collection('ml_predictions') // Could be separate collection
          .doc(prediction.id)
          .set(prediction.toJson());
    } catch (e) {
      print('Error saving ML prediction: $e');
      rethrow;
    }
  }

  // Usage Logs
  Future<void> logUsage(String deviceId, String action, Map<String, dynamic> details) async {
    try {
      await _firestore.collection(AppConfig.logsCollection).add({
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

  // Batch operations for efficiency
  Future<void> saveSensorDataBatch(List<SensorData> dataList) async {
    final batch = _firestore.batch();
    for (final data in dataList) {
      final docRef = _firestore.collection(AppConfig.sensorDataCollection).doc(data.id);
      batch.set(docRef, data.toJson());
    }
    await batch.commit();
  }
}