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

    if (!_firebaseService.isAvailable) {
      _devices = _mockDevices();
      _selectedDevice = _devices.first;
      _isLoading = false;
      notifyListeners();
      return;
    }

    final stream = _firebaseService.getDevicesStream();
    stream.listen((devices) {
      _devices = devices.isEmpty ? _mockDevices() : devices;
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
      await _firebaseService.logUsage(
        device.id,
        'relay_toggle',
        {
          'status': status ? 'ON' : 'OFF',
          'message': 'Relay switched ${status ? 'ON' : 'OFF'} from the dashboard.',
        },
      );

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

  List<Device> _mockDevices() {
    final now = DateTime.now();
    return [
      Device(
        id: 'device-001',
        name: 'Forge Line Motor',
        type: 'AC Motor',
        isOnline: true,
        relayStatus: true,
        latitude: 13.0827,
        longitude: 80.2707,
        lastSeen: now.subtract(const Duration(minutes: 1)),
        specs: const {
          'power': '5 HP',
          'voltage': '220V',
          'current': '8.4A',
        },
      ),
      Device(
        id: 'device-002',
        name: 'Dust Extraction Fan',
        type: 'Ventilation',
        isOnline: true,
        relayStatus: false,
        latitude: 13.0843,
        longitude: 80.2719,
        lastSeen: now.subtract(const Duration(minutes: 3)),
        specs: const {
          'power': '3 HP',
          'voltage': '220V',
          'current': '5.6A',
        },
      ),
      Device(
        id: 'device-003',
        name: 'Packaging Conveyor',
        type: 'Conveyor',
        isOnline: false,
        relayStatus: false,
        latitude: 13.0861,
        longitude: 80.2694,
        lastSeen: now.subtract(const Duration(minutes: 14)),
        specs: const {
          'power': '2 HP',
          'voltage': '110V',
          'current': '3.9A',
        },
      ),
    ];
  }
}
