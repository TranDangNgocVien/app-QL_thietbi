import 'package:flutter/material.dart';

import '../../core/constants/user_session.dart';
import '../../core/routes/app_routes.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String get _role => UserSession.role;

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
            _kpiSection(isManager),
            const SizedBox(height: 18),
            Text('Chức năng nhanh', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _quickActions(isManager),
            const SizedBox(height: 18),
            _focusPanel(isManager),
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
            backgroundColor: Colors.white.withOpacity(0.2),
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
                      : 'Xử lý đơn thuê, giao nhận và cập nhật tình trạng thiết bị',
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

  Widget _kpiSection(bool isManager) {
    final managerCards = [
      _statCard(
        'Doanh thu tháng',
        '245 tr',
        const Color(0xFF1565C0),
        Icons.payments,
      ),
      _statCard(
        'Đơn quá hạn',
        '7',
        const Color(0xFFD84315),
        Icons.warning_amber,
      ),
      _statCard('Cần duyệt', '5', const Color(0xFF6A1B9A), Icons.fact_check),
    ];

    final staffCards = [
      _statCard('Đang thuê', '26', const Color(0xFF2E7D32), Icons.shopping_bag),
      _statCard(
        'Trả hôm nay',
        '11',
        const Color(0xFF00838F),
        Icons.assignment_return,
      ),
      _statCard('Sẵn sàng', '84', const Color(0xFF283593), Icons.inventory_2),
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
        'Tạo đơn thuê',
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
        'Danh sách đơn',
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
          onTap: () => Navigator.pushNamed(context, action.route),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: action.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: action.color.withOpacity(0.2)),
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

  Widget _focusPanel(bool isManager) {
    if (isManager) {
      return _panel(
        title: 'Việc cần xử lý trong ngày (Quản lý)',
        rows: const [
          'Phê duyệt 3 yêu cầu hủy đơn đang chờ',
          'Kiểm tra 2 thiết bị cần bảo trì định kỳ',
          'Xem báo cáo doanh thu cuối ngày lúc 20:00',
        ],
      );
    }

    return _panel(
      title: 'Công việc ca trực (Nhân viên)',
      rows: const [
        'Bàn giao 4 đơn đang chờ khách nhận',
        'Theo dõi 2 đơn sắp đến hạn trong 24h',
        'Ghi nhận biên bản trả thiết bị vào cuối ca',
      ],
    );
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
        color: color.withOpacity(0.1),
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
