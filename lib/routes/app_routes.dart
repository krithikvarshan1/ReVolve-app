import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String alerts = '/alerts';
  static const String deviceControl = '/device-control';
  static const String map = '/map';

  static Map<String, WidgetBuilder> get routes => {
        login: (context) => const LoginScreen(),
        dashboard: (context) => const DashboardScreen(),
        // Add more routes as screens are created
        // alerts: (context) => const AlertsScreen(),
        // deviceControl: (context) => const DeviceControlScreen(),
        // map: (context) => const MapScreen(),
      };
}