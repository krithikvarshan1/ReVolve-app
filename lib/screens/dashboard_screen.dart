import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/activity_log.dart';
import '../models/alert.dart';
import '../models/predictive_maintenance_result.dart';
import '../models/sensor_data.dart';
import '../providers/alert_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/device_provider.dart';
import '../providers/log_provider.dart';
import '../providers/sensor_provider.dart';
import '../services/chatbot_service.dart';
import '../services/report_export_service.dart';
import '../widgets/alert_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;
  bool _navExpanded = true;
  bool _isExportingReport = false;
  bool _isChatLoading = false;
  ChatbotMode _chatbotMode = ChatbotMode.fallbackMode;
  final ReportExportService _reportExportService = ReportExportService();
  final ChatbotService _chatbotService = ChatbotService();
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<_ChatMessage> _chatMessages = [
    const _ChatMessage(
      role: _ChatRole.assistant,
      content:
          'Hi, I am the ReVolve assistant. Ask me about login, dashboard sections, alerts, devices, analytics, or report export.',
    ),
  ];
  List<String> _chatSuggestions = const [];
  String? _lastAlertNotificationKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SensorProvider>().startSensorMonitoring();
      _loadChatbotMode();
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    _chatbotService.dispose();
    super.dispose();
  }

  Future<void> _loadChatbotMode() async {
    final mode = await _chatbotService.getMode();
    if (!mounted) {
      return;
    }
    setState(() {
      _chatbotMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userName = auth.user?.displayName.isNotEmpty == true
        ? auth.user!.displayName
        : 'Operations Team';

    return Consumer4<SensorProvider, AlertProvider, DeviceProvider, LogProvider>(
      builder: (context, sensor, alertProvider, deviceProvider, logProvider, _) {
        final alerts = _alerts(sensor, alertProvider);
        _triggerPredictiveNotification(sensor.latestPredictiveResult);
        final isCompact = MediaQuery.sizeOf(context).width < 920;

        final pages = [
          _overview(sensor, alerts, deviceProvider, userName),
          _alertsPage(alerts),
          _devicesPage(deviceProvider, sensor.latestData),
          _logsPage(sensor, logProvider),
          _analyticsPage(sensor),
          _assistantPage(),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7FB),
          drawer: isCompact
              ? Drawer(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: SafeArea(child: _buildSidebar(drawerMode: true)),
                )
              : null,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 76,
            titleSpacing: isCompact ? 0 : 8,
            leading: isCompact
                ? Builder(
                    builder: (context) => IconButton(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu_rounded),
                      tooltip: 'Open navigation',
                    ),
                  )
                : null,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ReVolve Command Center',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                ),
                Text(
                  'Welcome back, $userName',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
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
          body: isCompact
              ? Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [pages[_index]],
                      ),
                    ),
                    _chatLauncherButton(),
                  ],
                )
              : Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSidebar(),
                        // Assistant page: full-height fixed layout (no outer scroll)
                        if (_index == 5)
                          Expanded(child: _assistantPage())
                        else
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight - 8 - 24,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [pages[_index]],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    _chatLauncherButton(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSidebar({bool drawerMode = false}) {
    const items = [
      (Icons.dashboard_outlined, 'Overview'),
      (Icons.warning_amber_rounded, 'Alerts'),
      (Icons.memory_rounded, 'Devices'),
      (Icons.receipt_long_rounded, 'Logs'),
      (Icons.analytics_outlined, 'Analytics'),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: drawerMode ? double.infinity : (_navExpanded ? 240 : 92),
      margin: drawerMode
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 8, 0, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_navExpanded || drawerMode)
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFE0EAFF),
                  child: Icon(
                    Icons.blur_on_rounded,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ReVolve',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Operations workspace',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: drawerMode
                      ? () => Navigator.of(context).pop()
                      : () => setState(() => _navExpanded = !_navExpanded),
                  icon: Icon(
                    drawerMode
                        ? Icons.close_rounded
                        : Icons.keyboard_double_arrow_left_rounded,
                    color: const Color(0xFF64748B),
                  ),
                  tooltip: drawerMode ? 'Close menu' : 'Collapse menu',
                ),
              ],
            )
          else
            Column(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFE0EAFF),
                  child: Icon(
                    Icons.blur_on_rounded,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  onPressed: () => setState(() => _navExpanded = !_navExpanded),
                  icon: const Icon(
                    Icons.keyboard_double_arrow_right_rounded,
                    color: Color(0xFF64748B),
                  ),
                  tooltip: 'Expand menu',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          if (_navExpanded || drawerMode) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF8FAFF), Color(0xFFEFF6FF)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Command hub',
                    style: TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Monitor alerts, devices, and live analytics from one place.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ] else
            const SizedBox(height: 10),
          Expanded(
            child: Column(
              children: List.generate(items.length, (itemIndex) {
                final item = items[itemIndex];
                final isSelected = _index == itemIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      setState(() => _index = itemIndex);
                      if (drawerMode) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: _navExpanded ? 14 : 10,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEFF6FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        border: isSelected
                            ? Border.all(color: const Color(0xFFBFDBFE))
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: _navExpanded
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.$1,
                            color: isSelected
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF64748B),
                          ),
                          if (_navExpanded) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.$2,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF1D4ED8)
                                      : const Color(0xFF334155),
                                  fontWeight:
                                      isSelected ? FontWeight.w800 : FontWeight.w600,
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

  Widget _chatLauncherButton() {
    // Hide the FAB when the chatbot page (index 5) is already open
    if (_index == 5) return const SizedBox.shrink();

    return Positioned(
      right: 20,
      bottom: 20,
      child: FloatingActionButton.extended(
        heroTag: 'chatbot-launcher',
        onPressed: () {
          setState(() {
            _index = 5;
          });
        },
        icon: const Icon(Icons.smart_toy_rounded),
        label: const Text('Chatbot'),
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
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
    final predictive = sensor.latestPredictiveResult;
    final displayHealthScore = predictive?.healthScore.toDouble() ?? sensor.healthScore;
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
                    _heroMetric('Health', '${displayHealthScore.toStringAsFixed(0)}%'),
                    _heroMetric(
                      'RUL',
                      predictive == null && prediction == null
                          ? '--'
                          : '${(predictive?.remainingUsefulLife ?? prediction!.remainingUsefulLife.toInt())}h',
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
              '${displayHealthScore.toStringAsFixed(1)}%',
              Icons.favorite_rounded,
              _healthColor(displayHealthScore),
            ),
            _kpi(
              'Failure Risk',
              predictive == null && prediction == null
                  ? '--'
                  : '${(predictive?.faultConfidence ?? (prediction!.failureProbability * 100)).toStringAsFixed(1)}%',
              Icons.warning_rounded,
              const Color(0xFFF97316),
            ),
            _kpi(
              'Remaining Life',
              predictive == null && prediction == null
                  ? '--'
                  : '${(predictive?.remainingUsefulLife ?? prediction!.remainingUsefulLife.toInt())} h',
              Icons.timer_rounded,
              const Color(0xFF2563EB),
            ),
            _kpi(
              'Data Duration',
              '${sensor.usageMinutes.toStringAsFixed(1)} min',
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
                subtitle: 'Unified AI output from fault, RUL, anomaly, and forecast models',
                child: prediction == null
                    ? const Text('Waiting for sensor history...')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (sensor.isPredictiveLoading) ...[
                            const LinearProgressIndicator(minHeight: 3),
                            const SizedBox(height: 8),
                            const Text(
                              'Analyzing sensor data...',
                              style: TextStyle(
                                color: Color(0xFF334155),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (sensor.predictiveError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              sensor.predictiveError!,
                              style: const TextStyle(
                                color: Color(0xFFB45309),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (predictive != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.lightbulb_rounded,
                                    color: Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${predictive.aiEmoji ?? '💡'} ${predictive.aiInsight ?? prediction.insights.join(' ')}',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Recommendation: ${predictive.maintenanceRecommendation}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _recommendationColor(
                                  predictive.maintenanceRecommendation,
                                ),
                              ),
                            ),
                          ] else ...[
                            Text(prediction.insights.join(' ')),
                          ],
                        ],
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
                latest == null ? '--' : '${latest.temperature.toStringAsFixed(1)} °C',
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
                'Gas',
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
        const SizedBox(height: 18),
        _panel(
          title: 'Predictive Maintenance Console',
          subtitle:
              'Fault prediction, anomaly detection, RUL life bar, risk class, and recommendation',
          child: _buildPredictiveConsole(sensor, predictive),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: wide ? 720 : double.infinity,
              child: _panel(
                title: 'Future RUL Trend',
                subtitle: 'Predicted degradation trajectory (LSTM model)',
                child: SizedBox(
                  height: 252,
                  child: _futureRulChart(predictive),
                ),
              ),
            ),
            SizedBox(
              width: wide ? 420 : double.infinity,
              child: _panel(
                title: 'Simulation Input Panel',
                subtitle: 'Adjust synthetic sensor values for demos and testing',
                child: _simulationPanel(sensor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _panel(
          title: 'Historical Prediction Logs',
          subtitle: 'Latest inference records saved from continuous prediction stream',
          child: _predictionHistoryTable(sensor.predictionHistory),
        ),
        const SizedBox(height: 18),
        _panel(
          title: 'Downloadable Reports',
          subtitle: 'Export predictive maintenance summary as CSV or PDF',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: _isExportingReport
                    ? null
                    : () => _exportReport(sensor.predictionHistory, isPdf: false),
                icon: const Icon(Icons.table_chart_rounded),
                label: const Text('Export CSV'),
              ),
              FilledButton.tonalIcon(
                onPressed: _isExportingReport
                    ? null
                    : () => _exportReport(sensor.predictionHistory, isPdf: true),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Export PDF'),
              ),
              if (_isExportingReport)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
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

  void _triggerPredictiveNotification(PredictiveMaintenanceResult? predictive) {
    if (predictive == null) {
      return;
    }

    final shouldNotify = predictive.isAnomaly ||
        predictive.faultPrediction.toUpperCase() == 'FAILURE_IMMINENT' ||
        predictive.riskLevel == 'CRITICAL';
    if (!shouldNotify) {
      return;
    }

    final key =
        '${predictive.riskLevel}-${predictive.faultPrediction}-${predictive.timestamp.millisecondsSinceEpoch ~/ 5000}';
    if (_lastAlertNotificationKey == key) {
      return;
    }
    _lastAlertNotificationKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF7F1D1D),
          content: Text(
            'Critical predictive alert: ${predictive.faultPrediction} | ${predictive.riskLevel} risk',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  Widget _devicesPage(DeviceProvider deviceProvider, SensorData? latest) {
    final selected = deviceProvider.selectedDevice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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

  Widget _analyticsPage(SensorProvider sensor) {
    final rows = sensor.predictionHistory;
    final riskCounts = {
      'LOW': rows.where((r) => r.riskLevel == 'LOW').length,
      'MEDIUM': rows.where((r) => r.riskLevel == 'MEDIUM').length,
      'HIGH': rows.where((r) => r.riskLevel == 'HIGH').length,
      'CRITICAL': rows.where((r) => r.riskLevel == 'CRITICAL').length,
    };
    final anomalyRate = rows.isEmpty
        ? 0.0
        : rows.where((r) => r.isAnomaly).length / rows.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _panel(
          title: 'Admin Analytics',
          subtitle: 'Failure and anomaly patterns over historical prediction logs',
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _valueTile('Total predictions', '${rows.length}'),
              _valueTile('Anomaly rate', '${(anomalyRate * 100).toStringAsFixed(1)}%'),
              _valueTile('Critical cases', '${riskCounts['CRITICAL']}'),
              _valueTile('High risk cases', '${riskCounts['HIGH']}'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _panel(
          title: 'Risk Distribution',
          subtitle: 'Current prediction risk profile for operations review',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: riskCounts.entries
                .map(
                  (entry) => Container(
                    width: 170,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _riskColor(entry.key).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            color: _riskColor(entry.key),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${entry.value}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _assistantPage() {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8FAFC)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fixed header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + status badge row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'App Chatbot Assistant',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Ask questions about ReVolve features and workflow. This assistant is restricted to app usage guidance.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _chatbotMode == ChatbotMode.ollamaActive
                            ? const Color(0xFFE8F7EE)
                            : const Color(0xFFFFF4DB),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _chatbotMode == ChatbotMode.ollamaActive
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFFCD34D),
                        ),
                      ),
                      child: Text(
                        _chatbotMode == ChatbotMode.ollamaActive
                            ? 'Ollama active'
                            : 'Fallback mode',
                        style: TextStyle(
                          color: _chatbotMode == ChatbotMode.ollamaActive
                              ? const Color(0xFF166534)
                              : const Color(0xFF92400E),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Hint banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Text(
                    'Try: How do I export reports? | What does the Alert Center show? | How do relay controls work?',
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),

          // ── Scrollable chat messages ─────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      final message = _chatMessages[index];
                      final isUser = message.role == _ChatRole.user;

                      return Align(
                        alignment:
                            isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 560),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? const Color(0xFF1D4ED8)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isUser
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            message.content,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isUser
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                 ],

              ),
            ),
          ),

          // ── Fixed bottom: suggestions + text input ───────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_chatSuggestions.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _chatSuggestions
                        .map(
                          (item) => ActionChip(
                            label: Text(item),
                            onPressed: () => _sendChatQuery(preset: item),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: const Color(0xFF1D4ED8),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendChatQuery(),
                        decoration: InputDecoration(
                          hintText: 'Ask about app usage...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: Color(0xFF1D4ED8), width: 1.4),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _isChatLoading ? null : _sendChatQuery,
                      icon: _isChatLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: const Text('Send'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendChatQuery({String? preset}) async {
    if (_isChatLoading) {
      return;
    }

    final text = (preset ?? _chatController.text).trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _chatMessages.add(_ChatMessage(role: _ChatRole.user, content: text));
      _isChatLoading = true;
      if (preset == null) {
        _chatController.clear();
      }
    });
    _scrollChatToBottom();

    try {
      final reply = await _chatbotService.ask(text);
      if (!mounted) {
        return;
      }

      setState(() {
        _chatMessages.add(
          _ChatMessage(role: _ChatRole.assistant, content: reply.answer),
        );
        _chatSuggestions = reply.suggestedQuestions;
        _chatbotMode = reply.mode;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _chatMessages.add(
          const _ChatMessage(
            role: _ChatRole.assistant,
            content:
                'I could not reach the chatbot service. Please make sure backend is running and try again.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isChatLoading = false;
        });
      }
      _scrollChatToBottom();
    }
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollController.hasClients) {
        return;
      }
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildPredictiveConsole(
    SensorProvider sensor,
    PredictiveMaintenanceResult? predictive,
  ) {
    if (predictive == null) {
      return const Text('Waiting for predictive response...');
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _valueTile('Fault', predictive.faultPrediction),
        _valueTile('Confidence', '${predictive.faultConfidence.toStringAsFixed(1)}%'),
        _valueTile('Anomaly', predictive.anomalyStatus),
        _valueTile('RUL', '${predictive.remainingUsefulLife} h'),
        _valueTile('Forecast T+', '${predictive.futureForecastTemp.toStringAsFixed(2)} C'),
        _riskTile(predictive),
        Container(
          width: 320,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _faultColor(predictive.faultPrediction).withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recommendation',
                style: TextStyle(
                  color: _faultColor(predictive.faultPrediction),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                predictive.maintenanceRecommendation,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Tooltip(
                message: 'Health score combines fault confidence, anomaly status, and RUL',
                child: Row(
                  children: [
                    const Text(
                      'Health score',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${predictive.healthScore}%',
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: predictive.healthScore / 100,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade300,
                  color: _healthColor(predictive.healthScore.toDouble()),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 320,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: predictive.isAnomaly
                ? const Color(0xFFFEE2E2)
                : const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: predictive.isAnomaly
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF16A34A),
              width: 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                predictive.isAnomaly
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                color: predictive.isAnomaly
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF16A34A),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  predictive.isAnomaly
                      ? 'Anomaly detected. Triggering high-visibility warning state.'
                      : 'No anomaly detected. System conditions look normal.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _futureRulChart(PredictiveMaintenanceResult? predictive) {
    final series = predictive?.lstmForecast ?? const <double>[];
    if (series.isEmpty) {
      return const Center(child: Text('No forecast data available'));
    }

    final minValue = series.reduce((a, b) => a < b ? a : b);
    final maxValue = series.reduce((a, b) => a > b ? a : b);
    final yPadding = ((maxValue - minValue).abs() * 0.2).clamp(1.0, 8.0);
    final spots = series
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList(growable: false);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (series.length - 1).toDouble(),
        minY: (minValue - yPadding).clamp(0, double.infinity),
        maxY: maxValue + yPadding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxValue - minValue) / 4).abs().clamp(1.0, 20.0),
          getDrawingHorizontalLine: (_) => FlLine(
            color: const Color(0xFFE2E8F0),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF0F172A),
            tooltipRoundedRadius: 10,
            getTooltipItems: (spots) => spots
                .map(
                  (spot) => LineTooltipItem(
                    'T+${spot.x.toInt() + 1}\n${spot.y.toStringAsFixed(1)} h RUL',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            axisNameSize: 26,
            axisNameWidget: const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'RUL (h)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 62,
              interval: ((maxValue - minValue) / 4).abs().clamp(1.0, 20.0),
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameSize: 28,
            axisNameWidget: const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Forecast Horizon',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= series.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  'T+${index + 1}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            gradient: const LinearGradient(
              colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
            ),
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 2.8,
                color: const Color(0xFF2563EB),
                strokeWidth: 1.6,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0EA5E9).withOpacity(0.26),
                  const Color(0xFF0EA5E9).withOpacity(0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _simulationPanel(SensorProvider sensor) {
    final values = sensor.manualSimulationValues;
    final items = [
      ('temperature', 'Temperature', 0.0, 120.0),
      ('vibration', 'Vibration', 0.0, 10.0),
      ('current', 'Current', 0.0, 15.0),
      ('gas', 'Gas', 0.0, 1000.0),
      ('dust', 'Dust', 0.0, 500.0),
      ('sound', 'Sound', 0.0, 120.0),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          value: sensor.manualSimulationEnabled,
          title: const Text('Enable manual simulation'),
          onChanged: sensor.setManualSimulationEnabled,
          contentPadding: EdgeInsets.zero,
        ),
        if (sensor.manualSimulationEnabled)
          ...items.map(
            (item) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.$2}: ${(values[item.$1] ?? 0).toStringAsFixed(1)}'),
                Slider(
                  value: values[item.$1] ?? item.$3,
                  min: item.$3,
                  max: item.$4,
                  divisions: 100,
                  label: (values[item.$1] ?? item.$3).toStringAsFixed(1),
                  onChanged: (value) =>
                      sensor.updateManualSimulationValue(item.$1, value),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _predictionHistoryTable(List<PredictiveMaintenanceResult> rows) {
    if (rows.isEmpty) {
      return const Text('No prediction history available yet.');
    }

    final visible = rows.reversed.take(8).toList(growable: false);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Time')),
          DataColumn(label: Text('Fault')),
          DataColumn(label: Text('Confidence')),
          DataColumn(label: Text('RUL')),
          DataColumn(label: Text('Anomaly')),
          DataColumn(label: Text('Health')),
          DataColumn(label: Text('Risk')),
        ],
        rows: visible
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(Text(DateFormat('HH:mm:ss').format(row.timestamp))),
                  DataCell(Text(row.faultPrediction)),
                  DataCell(Text('${row.faultConfidence.toStringAsFixed(1)}%')),
                  DataCell(Text('${row.remainingUsefulLife}h')),
                  DataCell(Text(row.anomalyStatus)),
                  DataCell(Text('${row.healthScore}%')),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _riskColor(row.riskLevel).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        row.riskLevel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _riskColor(row.riskLevel),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> _exportReport(
    List<PredictiveMaintenanceResult> rows, {
    required bool isPdf,
  }) async {
    if (rows.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No prediction history to export yet.')),
      );
      return;
    }

    setState(() => _isExportingReport = true);
    try {
      if (isPdf) {
        await _reportExportService.exportPdf(rows);
      } else {
        await _reportExportService.exportCsv(rows);
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPdf ? 'PDF download started.' : 'CSV download started.'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingReport = false);
      }
    }
  }

  Widget _panel({
    String? title,
    String? subtitle,
    required Widget child,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF8FAFC)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 20,
              offset: Offset(0, 10),
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
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
            Theme(
              data: Theme.of(context).copyWith(
                textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: const Color(0xFF68788E),
                  displayColor: const Color(0xFF68788E),
                ),
                iconTheme: const IconThemeData(color: Color(0xFF68788E)),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Color(0xFF68788E)),
                child: child,
              ),
            ),
          ],
        ),
      );

  Widget _heroMetric(String label, String value) => Container(
        width: 118,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
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
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C0F172A),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
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
          border: Border.all(color: const Color(0xFFE2E8F0)),
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

  Widget _riskTile(PredictiveMaintenanceResult predictive) => Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tooltip(
              message:
                  'Risk is derived from RUL, health score, anomaly state, fault confidence, and fault severity.',
              child: const Text(
                'Risk',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _riskColor(predictive.riskLevel).withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                predictive.riskLevel,
                style: TextStyle(
                  color: _riskColor(predictive.riskLevel),
                  fontWeight: FontWeight.w800,
                ),
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
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log.title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              log.message,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
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

    final double xStep = (history.length / 6).ceil().toDouble();

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _seriesLabel('Temperature', const Color(0xFFEF4444)),
            _seriesLabel('Vibration (x10)', const Color(0xFFF59E0B)),
            _seriesLabel('Current (x6)', const Color(0xFF2563EB)),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LineChart(
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
                bottomTitles: AxisTitles(
                  axisNameSize: 30,
                  axisNameWidget: const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Sample Index',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFA9B2BF),
                      ),
                    ),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: xStep,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFA9B2BF),
                      ),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameSize: 30,
                  axisNameWidget: const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Scaled Value',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFA9B2BF),
                      ),
                    ),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFA9B2BF),
                      ),
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
          ),
        ),
      ],
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
        spots: spots,
        isCurved: spots.length > 1,
        color: color,
        barWidth: 3,
        dotData: FlDotData(
          show: spots.length == 1,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: 3.2,
            color: color,
            strokeColor: Colors.white,
            strokeWidth: 1,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: color.withOpacity(0.08),
        ),
      );

  Widget _seriesLabel(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

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

  Color _riskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'LOW':
        return const Color(0xFF16A34A);
      case 'MEDIUM':
        return const Color(0xFFF59E0B);
      case 'HIGH':
        return const Color(0xFFEF4444);
      case 'CRITICAL':
        return const Color(0xFF7F1D1D);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _faultColor(String fault) {
    switch (fault.toUpperCase()) {
      case 'OVERHEAT':
        return const Color(0xFFEA580C);
      case 'OVERLOAD':
        return const Color(0xFFD97706);
      case 'FAILURE_IMMINENT':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF0F766E);
    }
  }

  Color _recommendationColor(String recommendation) {
    switch (recommendation.trim()) {
      case 'No Action Needed':
        return const Color(0xFF2563EB);
      case 'Monitor Closely':
        return const Color(0xFFEA580C);
      case 'Immediate Attention Required':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF334155);
    }
  }
}

enum _ChatRole { user, assistant }

class _ChatMessage {
  const _ChatMessage({required this.role, required this.content});

  final _ChatRole role;
  final String content;
}
