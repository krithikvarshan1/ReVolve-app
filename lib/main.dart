import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'config/firebase_bootstrap.dart';
import 'providers/auth_provider.dart';
import 'providers/sensor_provider.dart';
import 'providers/alert_provider.dart';
import 'providers/device_provider.dart';
import 'providers/log_provider.dart';
import 'routes/app_routes.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  String? _firebaseMessage;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final firebaseResult = await FirebaseBootstrap.initialize();
    if (!mounted) {
      return;
    }
    setState(() {
      _firebaseMessage = firebaseResult.message;
      _isReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.engineering_rounded, color: Colors.white, size: 56),
                  SizedBox(height: 16),
                  Text(
                    'ReVolve',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Preparing your workspace...',
                    style: TextStyle(color: Color(0xFFD1FAE5)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MyApp(firebaseMessage: _firebaseMessage);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.firebaseMessage});

  final String? firebaseMessage;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SensorProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => LogProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: AppConfig.appName,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        darkTheme: ThemeData.dark(
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        routes: {
          AppRoutes.login: (context) => LoginScreen(
                firebaseMessage: firebaseMessage,
              ),
          AppRoutes.dashboard: (context) => const DashboardScreen(),
        },
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            return auth.isAuthenticated
                ? const DashboardScreen()
                : LoginScreen(firebaseMessage: firebaseMessage);
          },
        ),
      ),
    );
  }
}
