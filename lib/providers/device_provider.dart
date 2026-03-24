import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/firebase_service.dart';
import '../services/device_control_service.dart';

class DeviceProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final DeviceControlService _deviceControlService = DeviceControlService();

  List<Device> _devices = [];
  Device? _selectedDevice;
  bool _isLoading = false;

  List<Device> get devices => _devices;
  Device? get selectedDevice => _selectedDevice;
  bool get isLoading => _isLoading;

  DeviceProvider() {
    _init();
  }

  void _init() {
    _loadDevices();
  }

  void _loadDevices() {
    _isLoading = true;
    notifyListeners();

    final stream = _firebaseService.getDevicesStream();
    stream.listen((devices) {
      _devices = devices;
      if (_devices.isNotEmpty && _selectedDevice == null) {
        _selectedDevice = _devices.first;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  void selectDevice(Device device) {
    _selectedDevice = device;
    notifyListeners();
  }

  Future<void> toggleRelay(Device device, bool status) async {
    final success = await _deviceControlService.toggleRelay(device.id, status);
    if (success) {
      // Update local state
      final updatedDevice = device.copyWith(
        relayStatus: status,
        lastSeen: DateTime.now(),
      );

      // Update in Firebase
      await _firebaseService.updateDeviceRelay(device.id, status);

      // Update in local list
      final index = _devices.indexWhere((d) => d.id == device.id);
      if (index != -1) {
        _devices[index] = updatedDevice;
        if (_selectedDevice?.id == device.id) {
          _selectedDevice = updatedDevice;
        }
        notifyListeners();
      }
    }
  }

  Future<void> addDevice(Device device) async {
    await _firebaseService.saveDevice(device);
    // The stream will automatically update the list
  }

  Future<void> updateDevice(Device device) async {
    await _firebaseService.saveDevice(device);
    // The stream will automatically update the list
  }

  Future<void> removeDevice(String deviceId) async {
    // In real implementation, you might want to mark as inactive instead of deleting
    // await _firebaseService.deleteDevice(deviceId);
    print('Device removal not implemented yet');
  }

  // Get online devices
  List<Device> get onlineDevices => _devices.where((device) => device.isOnline).toList();

  // Get devices by type
  List<Device> getDevicesByType(String type) {
    return _devices.where((device) => device.type == type).toList();
  }

  // Check if device is online (based on last seen time)
  bool isDeviceOnline(Device device) {
    final now = DateTime.now();
    final timeDiff = now.difference(device.lastSeen);
    return timeDiff.inMinutes < 5; // Consider online if seen within 5 minutes
  }

  // Get device statistics
  Map<String, int> getDeviceStatistics() {
    final stats = <String, int>{
      'total': _devices.length,
      'online': onlineDevices.length,
      'offline': _devices.length - onlineDevices.length,
    };

    // Count by type
    final types = <String>{};
    for (final device in _devices) {
      types.add(device.type);
    }

    for (final type in types) {
      stats[type] = getDevicesByType(type).length;
    }

    return stats;
  }
}