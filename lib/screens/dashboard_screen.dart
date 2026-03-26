import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/activity_log.dart';
import '../models/alert.dart';
import '../models/sensor_data.dart';
import '../providers/alert_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/device_provider.dart';
import '../providers/log_provider.dart';
import '../providers/sensor_provider.dart';
import '../widgets/alert_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;
  bool _navExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SensorProvider>().startSensorMonitoring();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userName = auth.user?.displayName?.isNotEmpty == true
        ? auth.user!.displayName
        : 'Operations Team';

    return Consumer4<SensorProvider, AlertProvider, DeviceProvider, LogProvider>(
      builder: (context, sensor, alertProvider, deviceProvider, logProvider, _) {
        final alerts = _alerts(sensor, alertProvider);

        final pages = [
          _overview(sensor, alerts, deviceProvider, userName),
          _alertsPage(alerts),
          _devicesPage(deviceProvider, sensor.latestData),
          _logsPage(sensor, logProvider),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF3F6FB),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ReVolve Command Center',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Welcome back, $userName',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.tonalIcon(
                  onPressed: () => context.read<AuthProvider>().signOut(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
          body: Row(
            children: [
              _buildSidebar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: pages[_index],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar() {
    const items = [
      (Icons.dashboard_outlined, 'Overview'),
      (Icons.warning_amber_rounded, 'Alerts'),
      (Icons.memory_rounded, 'Devices'),
      (Icons.receipt_long_rounded, 'Logs'),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: _navExpanded ? 220 : 84,
      margin: const EdgeInsets.fromLTRB(16, 8, 0, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1C24),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: _navExpanded ? Alignment.centerRight : Alignment.center,
            child: IconButton(
              onPressed: () => setState(() => _navExpanded = !_navExpanded),
              icon: Icon(
                _navExpanded ? Icons.keyboard_double_arrow_left_rounded : Icons.keyboard_double_arrow_right_rounded,
                color: Colors.white70,
              ),
              tooltip: _navExpanded ? 'Collapse menu' : 'Expand menu',
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              children: List.generate(items.length, (itemIndex) {
                final item = items[itemIndex];
                final isSelected = _index == itemIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => setState(() => _index = itemIndex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: _navExpanded ? 14 : 0,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF4B445E)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: _navExpanded
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.$1,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                          if (_navExpanded) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.$2,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overview(
    SensorProvider sensor,
    List<Alert> alerts,
    DeviceProvider deviceProvider,
    String userName,
  ) {
    final latest = sensor.latestData;
    final prediction = sensor.latestPrediction;
    final wide = MediaQuery.of(context).size.width > 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1D4ED8),
                  Color(0xFF0F766E),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.spaceBetween,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Industrial AI Monitoring Workspace',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Factory-grade monitoring for $userName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Track live sensor streams, predict remaining useful life, and trigger safety automation from one polished hackathon dashboard.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.84),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _heroMetric('Health', '${sensor.healthScore.toStringAsFixed(0)}%'),
                    _heroMetric(
                      'RUL',
                      prediction == null
                          ? '--'
                          : '${prediction.remainingUsefulLife.toStringAsFixed(0)}h',
                    ),
                    _heroMetric(
                      'Alerts',
                      '${alerts.where((a) => !a.isResolved).length}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: wide ? 4 : 2,
          childAspectRatio: wide ? 1.5 : 1.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          children: [
            _kpi(
              'Health Score',
              '${sensor.healthScore.toStringAsFixed(1)}%',
              Icons.favorite_rounded,
              _healthColor(sensor.healthScore),
            ),
            _kpi(
              'Failure Risk',
              prediction == null
                  ? '--'
                  : '${(prediction.failureProbability * 100).toStringAsFixed(1)}%',
              Icons.warning_rounded,
              const Color(0xFFF97316),
            ),
            _kpi(
              'Remaining Life',
              prediction == null
                  ? '--'
                  : '${prediction.remainingUsefulLife.toStringAsFixed(0)} h',
              Icons.timer_rounded,
              const Color(0xFF2563EB),
            ),
            _kpi(
              'Usage Window',
              '${sensor.usageHours.toStringAsFixed(2)} hrs',
              Icons.schedule_rounded,
              const Color(0xFF0F766E),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: wide ? 720 : double.infinity,
              child: _panel(
                title: 'Real-Time Sensor Trends',
                subtitle: 'Temperature, vibration, and current comparison',
                child: SizedBox(
                  height: 280,
                  child: _trendChart(sensor.sensorHistory),
                ),
              ),
            ),
            SizedBox(
              width: wide ? 420 : double.infinity,
              child: _panel(
                title: 'AI Insights',
                subtitle: 'Simulated ML output ready for Python backend integration',
                child: prediction == null
                    ? const Text('Waiting for sensor history...')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: prediction.insights
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.lightbulb_rounded,
                                      color: Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(item)),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _panel(
          title: 'Live Snapshot',
          subtitle: 'Current device telemetry and fleet summary',
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _valueTile(
                'Temperature',
                latest == null ? '--' : '${latest.temperature.toStringAsFixed(1)} C',
              ),
              _valueTile(
                'Vibration',
                latest == null ? '--' : '${latest.vibration.toStringAsFixed(2)} g',
              ),
              _valueTile(
                'Current',
                latest == null ? '--' : '${latest.current.toStringAsFixed(2)} A',
              ),
              _valueTile(
                'Gas / Dust',
                latest == null ? '--' : '${latest.gas.toStringAsFixed(0)} ppm',
              ),
              _valueTile(
                'Dust',
                latest == null ? '--' : '${latest.dust.toStringAsFixed(0)} ug/m3',
              ),
              _valueTile(
                'Sound',
                latest == null ? '--' : '${latest.sound.toStringAsFixed(1)} dB',
              ),
              _valueTile(
                'Connected Devices',
                '${deviceProvider.devices.length}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _alertsPage(List<Alert> alerts) => _panel(
        title: 'Alert Center',
        subtitle: 'Safety events from temperature, vibration, current, and gas thresholds',
        child: alerts.isEmpty
            ? const Text('No active alerts right now.')
            : Column(
                children: alerts.map((item) => AlertCard(alert: item)).toList(),
              ),
      );

  Widget _devicesPage(DeviceProvider deviceProvider, SensorData? latest) {
    final selected = deviceProvider.selectedDevice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          title: 'Connected Devices',
          subtitle: 'Mock fallback is included so demos stay complete without seeded Firestore data',
          child: Column(
            children: deviceProvider.devices
                .map(
                  (device) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: () => deviceProvider.selectDevice(device),
                      leading: CircleAvatar(
                        backgroundColor: device.isOnline
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                        child: Icon(
                          Icons.memory_rounded,
                          color: device.isOnline
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                      title: Text(device.name),
                      subtitle: Text(
                        '${device.type} - ${device.isOnline ? 'Online' : 'Offline'}',
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () => deviceProvider.toggleRelay(
                          device,
                          !device.relayStatus,
                        ),
                        child: Text(device.relayStatus ? 'Turn Off' : 'Turn On'),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (selected != null) ...[
          const SizedBox(height: 18),
          _panel(
            title: 'Selected Device',
            subtitle: 'Relay state, GPS location, and future-ready ESP32 mapping',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${selected.name} - Relay ${selected.relayStatus ? 'ON' : 'OFF'}'),
                const SizedBox(height: 8),
                Text(
                  'Last seen ${DateFormat('dd MMM, HH:mm').format(selected.lastSeen)}',
                ),
                if (latest != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Live temperature ${latest.temperature.toStringAsFixed(1)} C',
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 280,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(selected.latitude, selected.longitude),
                        zoom: 13,
                      ),
                      markers: {
                        Marker(
                          markerId: MarkerId(selected.id),
                          position: LatLng(
                            selected.latitude,
                            selected.longitude,
                          ),
                          infoWindow: InfoWindow(title: selected.name),
                        ),
                      },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _logsPage(SensorProvider sensor, LogProvider logProvider) => _panel(
        title: 'Usage & Maintenance Logs',
        subtitle: 'Operational activity, maintenance prompts, and system review history',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anomalies detected: ${sensor.anomalyCount}'),
            const SizedBox(height: 12),
            ...logProvider.logs.map((log) => _logTile(log)).toList(),
          ],
        ),
      );

  Widget _panel({
    String? title,
    String? subtitle,
    required Widget child,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      );

  Widget _heroMetric(String label, String value) => Container(
        width: 118,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.76),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  Widget _kpi(String title, String value, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      );

  Widget _valueTile(String label, String value) => Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  Widget _logTile(ActivityLog log) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(log.message),
            const SizedBox(height: 6),
            Text(
              '${log.category} - ${DateFormat('dd MMM, HH:mm').format(log.timestamp)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );

  Widget _trendChart(List<SensorData> history) {
    if (history.isEmpty) {
      return const Center(child: Text('Waiting for live sensor data...'));
    }

    final temperature = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.temperature))
        .toList();
    final vibration = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.vibration * 10))
        .toList();
    final current = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.current * 6))
        .toList();

    return LineChart(
      LineChartData(
        minY: 0,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ),
        lineBarsData: [
          _line(temperature, const Color(0xFFEF4444)),
          _line(vibration, const Color(0xFFF59E0B)),
          _line(current, const Color(0xFF2563EB)),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
        spots: spots,
        isCurved: true,
        color: color,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withOpacity(0.08),
        ),
      );

  List<Alert> _alerts(SensorProvider sensor, AlertProvider provider) {
    if (provider.alerts.isNotEmpty) {
      return provider.alerts;
    }

    final now = DateTime.now();
    return sensor.checkForAlerts().asMap().entries.map((entry) {
      final message = entry.value.replaceAll('Â', '');
      return Alert(
        id: 'derived-${entry.key}',
        title: 'Live threshold warning',
        message: message,
        severity: message.toLowerCase().contains('gas')
            ? AlertSeverity.critical
            : message.toLowerCase().contains('temperature')
                ? AlertSeverity.high
                : AlertSeverity.medium,
        timestamp: now.subtract(Duration(minutes: entry.key * 2)),
        deviceId: 'device-001',
      );
    }).toList();
  }

  Color _healthColor(double value) {
    if (value >= 80) {
      return const Color(0xFF16A34A);
    }
    if (value >= 60) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFFDC2626);
  }
}
