import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/sensor_provider.dart';
import '../providers/alert_provider.dart';
import '../providers/device_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/sensor_chart.dart';
import '../widgets/alert_card.dart';
import '../models/sensor_data.dart';
import '../models/alert.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Start sensor monitoring when dashboard loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SensorProvider>().startSensorMonitoring();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReVolve Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: Consumer3<SensorProvider, AlertProvider, DeviceProvider>(
        builder: (context, sensor, alert, device, _) {
          return RefreshIndicator(
            onRefresh: () async {
              // Refresh data
              sensor.startSensorMonitoring();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Health Score Card
                  _buildHealthScoreCard(sensor),

                  const SizedBox(height: 24),

                  // Sensor Charts
                  _buildSensorCharts(sensor),

                  const SizedBox(height: 24),

                  // ML Insights
                  _buildMLInsights(sensor),

                  const SizedBox(height: 24),

                  // Alerts Section
                  _buildAlertsSection(alert),

                  const SizedBox(height: 24),

                  // Device Control
                  _buildDeviceControl(device),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to device control screen
          Navigator.pushNamed(context, '/device-control');
        },
        child: const Icon(Icons.settings_remote),
        tooltip: 'Device Control',
      ),
    );
  }

  Widget _buildHealthScoreCard(SensorProvider sensor) {
    final latestData = sensor.latestData;
    final healthScore = latestData?.healthScore ?? 0.0;

    Color healthColor;
    String healthText;

    if (healthScore >= 80) {
      healthColor = Colors.green;
      healthText = 'Healthy';
    } else if (healthScore >= 60) {
      healthColor = Colors.yellow;
      healthText = 'Warning';
    } else {
      healthColor = Colors.red;
      healthText = 'Critical';
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'System Health Score',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            CircularProgressIndicator(
              value: healthScore / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(healthColor),
            ),
            const SizedBox(height: 8),
            Text(
              '${healthScore.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: healthColor,
              ),
            ),
            Text(
              healthText,
              style: TextStyle(color: healthColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCharts(SensorProvider sensor) {
    final history = sensor.sensorHistory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sensor Readings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            SensorChart(
              title: 'Temperature',
              data: history.map((d) => FlSpot(
                d.timestamp.millisecondsSinceEpoch.toDouble(),
                d.temperature,
              )).toList(),
              color: Colors.red,
              unit: '°C',
            ),
            SensorChart(
              title: 'Vibration',
              data: history.map((d) => FlSpot(
                d.timestamp.millisecondsSinceEpoch.toDouble(),
                d.vibration,
              )).toList(),
              color: Colors.orange,
              unit: 'g',
            ),
            SensorChart(
              title: 'Current',
              data: history.map((d) => FlSpot(
                d.timestamp.millisecondsSinceEpoch.toDouble(),
                d.current,
              )).toList(),
              color: Colors.blue,
              unit: 'A',
            ),
            SensorChart(
              title: 'Gas Level',
              data: history.map((d) => FlSpot(
                d.timestamp.millisecondsSinceEpoch.toDouble(),
                d.gas,
              )).toList(),
              color: Colors.purple,
              unit: 'ppm',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMLInsights(SensorProvider sensor) {
    final prediction = sensor.latestPrediction;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Insights',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (prediction != null) ...[
              Row(
                children: [
                  const Icon(Icons.timeline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'RUL: ${prediction.remainingUsefulLife.toStringAsFixed(0)} hours',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Failure Probability: ${(prediction.failureProbability * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Insights:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...prediction.insights.map((insight) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(child: Text(insight)),
                  ],
                ),
              )),
            ] else ...[
              const Text('Loading AI insights...'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection(AlertProvider alert) {
    final unresolvedAlerts = alert.unresolvedAlerts.take(3).toList(); // Show top 3

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Active Alerts',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/alerts'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (unresolvedAlerts.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No active alerts'),
            ),
          )
        else
          ...unresolvedAlerts.map((alert) => AlertCard(alert: alert)),
      ],
    );
  }

  Widget _buildDeviceControl(DeviceProvider device) {
    final selectedDevice = device.selectedDevice;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Control',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (selectedDevice != null) ...[
              Text('Device: ${selectedDevice.name}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Status: '),
                  Icon(
                    selectedDevice.relayStatus ? Icons.power : Icons.power_off,
                    color: selectedDevice.relayStatus ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(selectedDevice.relayStatus ? 'ON' : 'OFF'),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => device.toggleRelay(
                  selectedDevice,
                  !selectedDevice.relayStatus,
                ),
                child: Text(
                  selectedDevice.relayStatus ? 'Turn OFF' : 'Turn ON',
                ),
              ),
            ] else ...[
              const Text('No device selected'),
            ],
          ],
        ),
      ),
    );
  }
}