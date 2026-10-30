import 'package:flutter/material.dart';

import '../../core/constants/user_session.dart';
import '../../core/routes/app_routes.dart';
import '../customer/customer_list_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../database/business_data_screen.dart';
import '../device/device_list_screen.dart';
import '../rental/rental_orders_list_screen.dart';
import '../statistics/statistics_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int currentIndex = 0;

  final screens = const [
    DashboardScreen(),
    DeviceListScreen(),
    RentalOrdersListScreen(),
    CustomerListScreen(),
    StatisticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
      body: screens[currentIndex],
      bottomNavigationBar: UserSession.isCustomer
          ? _buildCustomerNavigation()
          : UserSession.isTechnician
          ? _buildTechnicianNavigation()
          : _buildStaffNavigation(),
    );
  }

  NavigationBar _buildTechnicianNavigation() {
    return NavigationBar(
      height: 74,
      selectedIndex: 0,
      onDestinationSelected: (navIndex) {
        if (navIndex == 1) {
          Navigator.pushNamed(context, AppRoutes.technicianJobs);
          return;
        }
        setState(() => currentIndex = 0);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Trang chủ'),
        NavigationDestination(
          icon: Icon(Icons.engineering_outlined),
          label: 'Công việc',
        ),
      ],
    );
  }

  NavigationBar _buildCustomerNavigation() {
    return NavigationBar(
      height: 74,
      selectedIndex: 0,
      onDestinationSelected: (navIndex) {
        if (navIndex == 1) {
          Navigator.pushNamed(context, AppRoutes.customerMaintenance);
          return;
        }
        setState(() => currentIndex = 0);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Trang chủ'),
        NavigationDestination(
          icon: Icon(Icons.build_circle_outlined),
          label: 'Bảo trì',
        ),
      ],
    );
  }

  NavigationBar _buildStaffNavigation() {
    final isManager = UserSession.isManager;
    return NavigationBar(
      height: 74,
      selectedIndex: currentIndex,
      onDestinationSelected: (navIndex) {
        if (navIndex == 4 && !isManager) {
          Navigator.pushNamed(context, AppRoutes.maintenanceReview);
          return;
        }

        setState(() => currentIndex = navIndex);
      },
      destinations: [
        const NavigationDestination(icon: Icon(Icons.home), label: 'Trang chủ'),
        const NavigationDestination(
          icon: Icon(Icons.devices),
          label: 'Thiết bị',
        ),
        const NavigationDestination(
          icon: Icon(Icons.receipt_long),
          label: 'Phiếu mượn',
        ),
        const NavigationDestination(
          icon: Icon(Icons.people),
          label: 'Khách hàng',
        ),
        NavigationDestination(
          icon: Icon(isManager ? Icons.bar_chart : Icons.fact_check_outlined),
          label: isManager ? 'Thống kê' : 'Duyệt bảo trì',
        ),
      ],
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(UserSession.displayName),
              accountEmail: Text(
                UserSession.email.isEmpty
                    ? 'Chưa cập nhật email'
                    : UserSession.email,
              ),
              currentAccountPicture: CircleAvatar(
                child: Text(
                  UserSession.displayName.isNotEmpty
                      ? UserSession.displayName[0].toUpperCase()
                      : 'U',
                ),
              ),
            ),
            ..._roleMenuItems(context),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _roleMenuItems(BuildContext context) {
    final homeItem = ListTile(
      leading: const Icon(Icons.dashboard),
      title: Text(UserSession.isCustomer ? 'Trang chủ' : 'Dashboard'),
      onTap: () {
        Navigator.pop(context);
        setState(() => currentIndex = 0);
      },
    );

    if (UserSession.isCustomer) {
      return [
        homeItem,
        ListTile(
          leading: const Icon(Icons.build_circle_outlined),
          title: const Text('Yêu cầu bảo trì'),
          subtitle: const Text('Tạo và theo dõi yêu cầu của bạn'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.customerMaintenance);
          },
        ),
      ];
    }

    if (UserSession.isTechnician) {
      return [
        homeItem,
        ListTile(
          leading: const Icon(Icons.engineering_outlined),
          title: const Text('Công việc sửa chữa'),
          subtitle: const Text('Xem và cập nhật thiết bị được phân công'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.technicianJobs);
          },
        ),
      ];
    }

    return [
      homeItem,
      ListTile(
        leading: const Icon(Icons.devices),
        title: const Text('Thiết bị'),
        onTap: () {
          Navigator.pop(context);
          setState(() => currentIndex = 1);
        },
      ),
      ListTile(
        leading: const Icon(Icons.people),
        title: const Text('Khách hàng'),
        onTap: () {
          Navigator.pop(context);
          setState(() => currentIndex = 3);
        },
      ),
      ListTile(
        leading: const Icon(Icons.list_alt),
        title: const Text('Phiếu mượn'),
        onTap: () {
          Navigator.pop(context);
          setState(() => currentIndex = 2);
        },
      ),
      ListTile(
        leading: const Icon(Icons.fact_check_outlined),
        title: const Text('Duyệt yêu cầu bảo trì'),
        subtitle: const Text('Xác nhận hoặc từ chối yêu cầu'),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, AppRoutes.maintenanceReview);
        },
      ),
      if (UserSession.isManager)
        ListTile(
          leading: const Icon(Icons.storage_outlined),
          title: const Text('Dữ liệu nghiệp vụ'),
          subtitle: const Text('Thanh toán, bảo trì, báo cáo...'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BusinessDataScreen()),
            );
          },
        ),
    ];
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có muốn đăng xuất khỏi hệ thống?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await UserSession.logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }
}
