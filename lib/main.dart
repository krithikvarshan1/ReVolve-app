import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'config/firebase_bootstrap.dart';
import 'providers/auth_provider.dart';
import 'providers/sensor_provider.dart';
import 'providers/alert_provider.dart';
import 'providers/device_provider.dart';
import 'routes/app_routes.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseResult = await FirebaseBootstrap.initialize();
  runApp(MyApp(firebaseMessage: firebaseResult.message));
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
      ],
      child: MaterialApp(
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
