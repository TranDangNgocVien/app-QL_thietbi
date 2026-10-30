import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/app_messenger.dart';
import 'core/constants/user_session.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'screens/customer/customer_list_screen.dart';
import 'screens/device/device_list_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/rental/create_rental_screen.dart';
import 'screens/rental/rental_orders_list_screen.dart';
import 'screens/rental/return_device_screen.dart';
import 'screens/layout/main_layout.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/statistics/statistics_screen.dart';
import 'screens/maintenance/customer_maintenance_screen.dart';
import 'screens/maintenance/maintenance_review_screen.dart';
import 'screens/maintenance/technician_jobs_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await UserSession.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appMessengerKey,

      title: 'Quản lý thiết bị',
      theme: AppTheme.lightTheme,

      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.dashboard: (context) => const MainLayout(),
        AppRoutes.mainLayout: (context) => const MainLayout(),
        AppRoutes.deviceList: (context) => const DeviceListScreen(),
        AppRoutes.customerList: (context) => const CustomerListScreen(),
        AppRoutes.rentalOrders: (context) => const RentalOrdersListScreen(),
        AppRoutes.createRental: (context) => const CreateOrderScreen(),
        AppRoutes.returnDevice: (context) => const ReturnDeviceScreen(),
        AppRoutes.statistics: (context) => const StatisticsScreen(),
        AppRoutes.customerMaintenance: (context) =>
            const CustomerMaintenanceScreen(),
        AppRoutes.maintenanceReview: (context) =>
            const MaintenanceReviewScreen(),
        AppRoutes.technicianJobs: (context) => const TechnicianJobsScreen(),
      },
    );
  }
}
