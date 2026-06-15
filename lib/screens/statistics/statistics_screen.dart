import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/user_session.dart';
import '../../services/order_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  String _period = 'Tháng này';
  String _category = 'Tất cả danh mục';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    if (!UserSession.isManager) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Chỉ tài khoản Quản lý mới được xem báo cáo thống kê.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      );
    }
    final orderService = OrderService();
    final totalRevenue = orderService.orders.fold<double>(
      0,
      (sum, order) => sum + order.totalPrice,
    );
    final totalOrders = orderService.getTotalOrders();
    final totalDevices = orderService.getTotalDevices();
    final totalCustomers = orderService.getTotalCustomers();
    final rentingPercentage = orderService.getRentingPercentage();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _header(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _filters(),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _kpiGrid(
                totalRevenue: totalRevenue,
                totalOrders: totalOrders,
                totalDevices: totalDevices,
                totalCustomers: totalCustomers,
              ),
            ),
            const SizedBox(height: 10),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Doanh thu'),
                Tab(text: 'Thiết bị'),
                Tab(text: 'Khách hàng'),
                Tab(text: 'Đơn thuê'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _revenueReport(rentingPercentage),
                  _deviceReport(),
                  _customerReport(),
                  _orderReport(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Wrap(
      runSpacing: 10,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Navigator.canPop(context))
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new),
                ),
              Text(
                'Thống kê & Báo cáo',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sẽ bổ sung xuất PDF/Excel ở bước xử lý sau.'),
              ),
            );
          },
          icon: const Icon(Icons.download),
          label: const Text('Xuất báo cáo'),
        ),
      ],
    );
  }

  Widget _filters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 540;

        final filterBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFB0BEC5)),
        );

        final periodField = DropdownButtonFormField<String>(
          value: _period,
          style: const TextStyle(color: Colors.black87),
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            labelText: 'Thời gian',
            labelStyle: const TextStyle(color: Color(0xFF455A64)),
            filled: true,
            fillColor: const Color(0xFFEAF4FF),
            border: filterBorder,
            enabledBorder: filterBorder,
            focusedBorder: filterBorder.copyWith(
              borderSide: const BorderSide(
                color: Color(0xFF1E88E5),
                width: 1.4,
              ),
            ),
          ),
          items: const [
            DropdownMenuItem(value: 'Hôm nay', child: Text('Hôm nay')),
            DropdownMenuItem(value: 'Tuần này', child: Text('Tuần này')),
            DropdownMenuItem(value: 'Tháng này', child: Text('Tháng này')),
            DropdownMenuItem(value: 'Quý này', child: Text('Quý này')),
            DropdownMenuItem(value: 'Tuỳ chọn', child: Text('Tuỳ chọn')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _period = value);
          },
        );

        final categoryField = DropdownButtonFormField<String>(
          value: _category,
          style: const TextStyle(color: Colors.black87),
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            labelText: 'Danh mục thiết bị',
            labelStyle: const TextStyle(color: Color(0xFF455A64)),
            filled: true,
            fillColor: const Color(0xFFE8F5E9),
            border: filterBorder,
            enabledBorder: filterBorder,
            focusedBorder: filterBorder.copyWith(
              borderSide: const BorderSide(
                color: Color(0xFF2E7D32),
                width: 1.4,
              ),
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: 'Tất cả danh mục',
              child: Text('Tất cả danh mục'),
            ),
            DropdownMenuItem(value: 'Âm thanh', child: Text('Âm thanh')),
            DropdownMenuItem(value: 'Ánh sáng', child: Text('Ánh sáng')),
            DropdownMenuItem(value: 'Video', child: Text('Video')),
            DropdownMenuItem(value: 'Sân khấu', child: Text('Sân khấu')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _category = value);
          },
        );

        if (isNarrow) {
          return Column(
            children: [periodField, const SizedBox(height: 10), categoryField],
          );
        }

        return Row(
          children: [
            Expanded(child: periodField),
            const SizedBox(width: 10),
            Expanded(child: categoryField),
          ],
        );
      },
    );
  }

  Widget _kpiGrid({
    required double totalRevenue,
    required int totalOrders,
    required int totalDevices,
    required int totalCustomers,
  }) {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            title: 'Doanh thu đơn thuê',
            value: '${totalRevenue.toStringAsFixed(0)} đ',
            valueSize: 16,
            color: const Color(0xFF0D47A1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            title: 'Tổng đơn thuê',
            value: '$totalOrders',
            color: const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            title: 'Thiết bị có thuê',
            value: '$totalDevices',
            color: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            title: 'Khách đã thuê',
            value: '$totalCustomers',
            color: const Color(0xFF6A1B9A),
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required Color color,
    double valueSize = 20,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: valueSize,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _revenueReport(double rentingPercentage) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Báo cáo doanh thu',
          subtitle:
              'Xu hướng doanh thu theo thời gian và doanh thu trung bình/đơn',
          child: Column(
            children: [
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 50,
                    sections: [
                      PieChartSectionData(
                        value: rentingPercentage.clamp(0, 100),
                        title: '${rentingPercentage.toStringAsFixed(1)}%',
                        color: const Color(0xFF1976D2),
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        value: (100 - rentingPercentage).clamp(0, 100),
                        title:
                            '${(100 - rentingPercentage).toStringAsFixed(1)}%',
                        color: Colors.grey.shade400,
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Biểu đồ đang dùng dữ liệu mô phỏng, sẽ nối dữ liệu thật sau.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _bulletCard(
          title: 'Chỉ số trọng tâm',
          rows: const [
            'Tổng doanh thu trong kỳ',
            'Doanh thu trung bình trên mỗi đơn thuê',
            'Doanh thu từ phí phạt và bồi thường',
            'So sánh cùng kỳ năm trước',
          ],
        ),
      ],
    );
  }

  Widget _deviceReport() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bulletCard(
          title: 'Báo cáo thiết bị',
          rows: const [
            'Top thiết bị được thuê nhiều nhất',
            'Tỷ lệ lấp đầy theo từng thiết bị',
            'Thiết bị đang bảo trì hoặc cần kiểm tra',
            'Chi phí bảo trì theo tháng',
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Danh sách cần chú ý',
          subtitle: 'UI mẫu theo UC-05.2.2',
          child: Column(
            children: const [
              ListTile(
                dense: true,
                leading: Icon(Icons.warning_amber),
                title: Text('TB-008 | Loa JBL PRX815'),
                subtitle: Text(
                  'Trạng thái: Bảo trì - kiểm tra trước lần thuê tiếp theo',
                ),
              ),
              Divider(height: 1),
              ListTile(
                dense: true,
                leading: Icon(Icons.build_circle_outlined),
                title: Text('TB-011 | Máy chiếu Epson'),
                subtitle: Text('Trạng thái: Hỏng nhẹ - chờ linh kiện thay thế'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _customerReport() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bulletCard(
          title: 'Báo cáo khách hàng',
          rows: const [
            'Khách hàng VIP theo giá trị giao dịch',
            'Khách hàng mới trong kỳ',
            'Khách hàng có công nợ cần theo dõi',
            'Khách hàng có lịch sử vi phạm',
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Nhóm khách hàng',
          subtitle: 'Phân nhóm để phục vụ chiến dịch chăm sóc',
          child: Column(
            children: const [
              ListTile(
                dense: true,
                leading: CircleAvatar(radius: 12, child: Text('A')),
                title: Text('Nhóm A - VIP (5 khách hàng)'),
              ),
              Divider(height: 1),
              ListTile(
                dense: true,
                leading: CircleAvatar(radius: 12, child: Text('B')),
                title: Text('Nhóm B - Thường xuyên (18 khách hàng)'),
              ),
              Divider(height: 1),
              ListTile(
                dense: true,
                leading: CircleAvatar(radius: 12, child: Text('C')),
                title: Text('Nhóm C - Cần nhắc nợ (3 khách hàng)'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _orderReport() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bulletCard(
          title: 'Báo cáo đơn thuê',
          rows: const [
            'Đơn đang hoạt động',
            'Đơn sắp đến hạn trả (24h/48h)',
            'Đơn quá hạn chưa xử lý',
            'Tỷ lệ hoàn thành đúng hạn',
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Bảng trạng thái đơn',
          subtitle: 'UI khung dữ liệu để nối xử lý sau',
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Mã đơn')),
              DataColumn(label: Text('Trạng thái')),
              DataColumn(label: Text('Nhắc hạn')),
            ],
            rows: const [
              DataRow(
                cells: [
                  DataCell(Text('DT-20260403-001')),
                  DataCell(Text('Đang thuê')),
                  DataCell(Text('Còn 12 giờ')),
                ],
              ),
              DataRow(
                cells: [
                  DataCell(Text('DT-20260401-014')),
                  DataCell(Text('Quá hạn')),
                  DataCell(Text('Đã gửi cảnh báo')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _bulletCard({required String title, required List<String> rows}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...rows.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
