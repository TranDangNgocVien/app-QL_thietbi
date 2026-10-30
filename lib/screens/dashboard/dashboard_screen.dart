import 'package:flutter/material.dart';

import '../../core/app_data_refresh.dart';
import '../../core/constants/user_session.dart';
import '../../core/routes/app_routes.dart';
import '../../data/dummy_data.dart' as dummy;
import '../../models/device.dart';
import '../../models/rental_order.dart';
import '../../services/device_storage_service.dart';
import '../../services/maintenance_request_service.dart';
import '../../services/order_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _dashboardDataFuture;

  String get _role => UserSession.role;

  @override
  void initState() {
    super.initState();
    _dashboardDataFuture = _loadDashboardData();
    AppDataRefresh.notifier.addListener(_handleDataRefresh);
  }

  void _handleDataRefresh() {
    if (!mounted) return;
    setState(() => _dashboardDataFuture = _loadDashboardData());
  }

  @override
  void dispose() {
    AppDataRefresh.notifier.removeListener(_handleDataRefresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (UserSession.isCustomer) {
      return _customerDashboard(context);
    }
    if (UserSession.isTechnician) {
      return _technicianDashboard(context);
    }
    final theme = Theme.of(context);
    final isManager = UserSession.isManager;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                return IconButton(
                  tooltip: 'Mở menu',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu),
                );
              },
            ),
            _header(theme),
            const SizedBox(height: 16),
            Text(
              isManager ? 'Tổng quan Quản lý' : 'Tổng quan Nhân viên',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<_DashboardData>(
              future: _dashboardDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 96,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _infoCard('Không tải được dữ liệu tổng quan');
                }
                return _kpiSection(isManager, snapshot.data!);
              },
            ),
            const SizedBox(height: 18),
            Text('Chức năng nhanh', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _quickActions(isManager),
            if (isManager) ...[
              const SizedBox(height: 18),
              FutureBuilder<_DashboardData>(
                future: _dashboardDataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done ||
                      snapshot.hasError) {
                    return const SizedBox.shrink();
                  }
                  return _focusPanel(snapshot.data!);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    final isManager = UserSession.isManager;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isManager
              ? [const Color(0xFF0D47A1), const Color(0xFF1976D2)]
              : [const Color(0xFF00695C), const Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(
              isManager ? Icons.admin_panel_settings : Icons.badge,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào, ${UserSession.displayName} ($_role)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isManager
                      ? 'Kiểm soát báo cáo, chỉ số và duyệt quy trình quan trọng'
                      : 'Xử lý phiếu mượn, giao nhận và cập nhật tình trạng thiết bị',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerDashboard(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Builder(
            builder: (context) => Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Mở menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu),
              ),
            ),
          ),
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào, ${UserSession.displayName}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bạn có thể gửi yêu cầu bảo trì cho những thiết bị '
                    'đã từng thuê.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.customerMaintenance);
            },
            icon: const Icon(Icons.build_circle_outlined),
            label: const Text('Yêu cầu bảo trì của tôi'),
          ),
        ],
      ),
    );
  }

  Widget _technicianDashboard(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Builder(
            builder: (context) => Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Mở menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu),
              ),
            ),
          ),
          Card(
            color: const Color(0xFFE3F2FD),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xin chào, ${UserSession.displayName}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF183B56),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kiểm tra công việc được phân công, cập nhật quá trình '
                    'sửa chữa và xác nhận tình trạng thiết bị sau sửa.',
                    style: TextStyle(color: Color(0xFF385A70), height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.technicianJobs);
            },
            icon: const Icon(Icons.engineering_outlined),
            label: const Text('Công việc sửa chữa của tôi'),
          ),
        ],
      ),
    );
  }

  Future<_DashboardData> _loadDashboardData() async {
    final orderService = OrderService();
    await orderService.loadOrders(fallback: dummy.rentalOrders);
    final devices = await DeviceStorageService.instance.loadDevices(
      fallback: dummy.devices,
    );
    final now = DateTime.now();
    var pendingMaintenance = 0;
    try {
      final requests = await MaintenanceRequestService.instance
          .loadRequestsForReview();
      pendingMaintenance = requests
          .where((request) => request.status == 'pending')
          .length;
    } catch (_) {
      pendingMaintenance = 0;
    }

    return _DashboardData(
      orders: List<RentalOrder>.from(orderService.orders),
      devices: devices,
      pendingMaintenance: pendingMaintenance,
      today: DateTime(now.year, now.month, now.day),
    );
  }

  Widget _kpiSection(bool isManager, _DashboardData data) {
    final managerCards = [
      _statCard(
        'Doanh thu tháng',
        _formatCompactCurrency(data.monthRevenue),
        const Color(0xFF1565C0),
        Icons.payments,
      ),
      _statCard(
        'Đơn quá hạn',
        '${data.overdueOrders}',
        const Color(0xFFD84315),
        Icons.warning_amber,
      ),
      _statCard(
        'Cần duyệt',
        '${data.pendingMaintenance}',
        const Color(0xFF6A1B9A),
        Icons.fact_check,
      ),
    ];

    final staffCards = [
      _statCard(
        'Đang thuê',
        '${data.activeOrders}',
        const Color(0xFF2E7D32),
        Icons.shopping_bag,
      ),
      _statCard(
        'Trả hôm nay',
        '${data.dueTodayOrders}',
        const Color(0xFF00838F),
        Icons.assignment_return,
      ),
      _statCard(
        'Sẵn sàng',
        '${data.availableDevices}',
        const Color(0xFF283593),
        Icons.inventory_2,
      ),
    ];

    final cards = isManager ? managerCards : staffCards;

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 8),
        Expanded(child: cards[1]),
        const SizedBox(width: 8),
        Expanded(child: cards[2]),
      ],
    );
  }

  Widget _quickActions(bool isManager) {
    final managerActions = [
      _ActionItem(
        Icons.fact_check_outlined,
        'Duyệt bảo trì',
        const Color(0xFF00897B),
        AppRoutes.maintenanceReview,
      ),
      _ActionItem(
        Icons.devices,
        'Quản lý thiết bị',
        const Color(0xFF3949AB),
        AppRoutes.deviceList,
      ),
      _ActionItem(
        Icons.groups,
        'Quản lý khách hàng',
        const Color(0xFF1E88E5),
        AppRoutes.customerList,
      ),
      _ActionItem(
        Icons.bar_chart,
        'Thống kê báo cáo',
        const Color(0xFF6A1B9A),
        AppRoutes.statistics,
      ),
    ];

    final staffActions = [
      _ActionItem(
        Icons.fact_check_outlined,
        'Duyệt bảo trì',
        const Color(0xFF00897B),
        AppRoutes.maintenanceReview,
      ),
      _ActionItem(
        Icons.add_shopping_cart,
        'Tạo phiếu mượn',
        const Color(0xFFF57C00),
        AppRoutes.createRental,
      ),
      _ActionItem(
        Icons.assignment_return,
        'Trả thiết bị',
        const Color(0xFF00897B),
        AppRoutes.returnDevice,
      ),
      _ActionItem(
        Icons.list_alt,
        'Danh sách phiếu',
        const Color(0xFF5E35B1),
        AppRoutes.rentalOrders,
      ),
    ];

    final actions = isManager ? managerActions : staffActions;

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return InkWell(
          onTap: () async {
            final changed = await Navigator.pushNamed(context, action.route);
            if (changed == true && context.mounted) {
              setState(() => _dashboardDataFuture = _loadDashboardData());
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: action.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: action.color.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, size: 30, color: action.color),
                const SizedBox(height: 8),
                Text(
                  action.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _focusPanel(_DashboardData data) {
    return _panel(
      title: 'Việc cần xử lý trong ngày (Quản lý)',
      rows: [
        'Duyệt ${data.pendingMaintenance} yêu cầu bảo trì đang chờ',
        'Theo dõi ${data.overdueOrders} đơn quá hạn',
        'Kiểm tra ${data.maintenanceDevices} thiết bị đang bảo trì hoặc ngừng cho thuê',
      ],
    );
  }

  Widget _infoCard(String message) {
    return Card(
      child: Padding(padding: const EdgeInsets.all(14), child: Text(message)),
    );
  }

  String _formatCompactCurrency(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)} tỷ';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(0)} tr';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)} nghìn';
    }
    return value.toStringAsFixed(0);
  }

  Widget _panel({required String title, required List<String> rows}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ...rows.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 3),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String title;
  final Color color;
  final String route;

  const _ActionItem(this.icon, this.title, this.color, this.route);
}

class _DashboardData {
  final List<RentalOrder> orders;
  final List<Device> devices;
  final int pendingMaintenance;
  final DateTime today;

  const _DashboardData({
    required this.orders,
    required this.devices,
    required this.pendingMaintenance,
    required this.today,
  });

  int get activeOrders => orders.where(_isActiveOrder).length;

  int get overdueOrders => orders
      .where(
        (order) =>
            _isActiveOrder(order) && _dateOnly(order.endDate).isBefore(today),
      )
      .length;

  int get dueTodayOrders => orders
      .where(
        (order) => _isActiveOrder(order) && _dateOnly(order.endDate) == today,
      )
      .length;

  int get availableDevices =>
      devices.fold<int>(0, (sum, device) => sum + device.quantityAvailable);

  int get maintenanceDevices => devices
      .where(
        (device) =>
            device.status == 'Bảo trì' ||
            device.status == 'Hỏng' ||
            device.status == 'Ngừng cho thuê',
      )
      .length;

  double get monthRevenue => orders
      .where(
        (order) =>
            order.startDate.year == today.year &&
            order.startDate.month == today.month,
      )
      .fold<double>(0, (sum, order) => sum + order.totalPrice);

  static bool _isActiveOrder(RentalOrder order) {
    return order.status == 'Đang thuê' ||
        order.status == 'Đang mượn' ||
        order.status == 'Quá hạn';
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
