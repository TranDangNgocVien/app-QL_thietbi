import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/app_data_refresh.dart';
import '../../core/constants/user_session.dart';
import '../../data/dummy_data.dart' as dummy;
import '../../models/customer.dart';
import '../../models/device.dart';
import '../../models/rental_order.dart';
import '../../services/customer_storage_service.dart';
import '../../services/device_storage_service.dart';
import '../../services/order_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late Future<_StatisticsData> _statisticsFuture;

  String _period = 'Tháng này';
  String _category = 'Tất cả danh mục';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _statisticsFuture = _loadStatisticsData();
    AppDataRefresh.notifier.addListener(_handleDataRefresh);
  }

  void _handleDataRefresh() {
    if (!mounted) return;
    setState(() => _statisticsFuture = _loadStatisticsData());
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
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_StatisticsData>(
          future: _statisticsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Không tải được dữ liệu thống kê: ${snapshot.error}',
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            return Column(
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
                  child: _kpiGrid(data),
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
                      _revenueReport(data),
                      _deviceReport(data),
                      _customerReport(data),
                      _orderReport(data),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<_StatisticsData> _loadStatisticsData() async {
    final orderService = OrderService();
    await orderService.loadOrders(fallback: dummy.rentalOrders);
    final devices = await DeviceStorageService.instance.loadDevices(
      fallback: dummy.devices,
    );
    final customers = await CustomerStorageService.instance.loadCustomers();
    return _StatisticsData(
      orders: List<RentalOrder>.from(orderService.orders),
      devices: devices,
      customers: customers,
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
          initialValue: _period,
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
          initialValue: _category,
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

  Widget _kpiGrid(_StatisticsData data) {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            title: 'Doanh thu',
            value: _formatCurrency(data.totalRevenue),
            valueSize: 16,
            color: const Color(0xFF0D47A1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            title: 'Tổng đơn',
            value: '${data.totalOrders}',
            color: const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            title: 'Thiết bị',
            value: '${data.totalDeviceQuantity}',
            color: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpiCard(
            title: 'Khách hàng',
            value: '${data.totalCustomers}',
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
        color: color.withValues(alpha: 0.09),
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

  Widget _revenueReport(_StatisticsData data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'Báo cáo doanh thu',
          subtitle:
              'Tỷ lệ đơn đang thuê và đơn đã hoàn thành từ dữ liệu hiện có',
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
                        value: data.activeOrderPercentage.clamp(0, 100),
                        title:
                            '${data.activeOrderPercentage.toStringAsFixed(1)}%',
                        color: const Color(0xFF1976D2),
                        radius: 60,
                        titleStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      PieChartSectionData(
                        value: (100 - data.activeOrderPercentage).clamp(0, 100),
                        title:
                            '${(100 - data.activeOrderPercentage).toStringAsFixed(1)}%',
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
              _legendRow(
                const Color(0xFF1976D2),
                'Đang thuê',
                data.activeOrders,
              ),
              _legendRow(
                Colors.grey.shade500,
                'Đã hoàn thành/khác',
                data.totalOrders - data.activeOrders,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _bulletCard(
          title: 'Chỉ số trọng tâm',
          rows: [
            'Tổng doanh thu: ${_formatCurrency(data.totalRevenue)}',
            'Doanh thu trung bình/đơn: ${_formatCurrency(data.averageRevenue)}',
            'Doanh thu tháng này: ${_formatCurrency(data.monthRevenue)}',
            'Đơn quá hạn: ${data.overdueOrders}',
          ],
        ),
      ],
    );
  }

  Widget _deviceReport(_StatisticsData data) {
    final attentionDevices = data.devices
        .where(
          (device) =>
              device.quantityAvailable == 0 ||
              device.status == 'Bảo trì' ||
              device.status == 'Hỏng' ||
              device.status == 'Ngừng cho thuê',
        )
        .take(8)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bulletCard(
          title: 'Báo cáo thiết bị',
          rows: [
            'Tổng số lượng thiết bị: ${data.totalDeviceQuantity}',
            'Sẵn sàng cho thuê: ${data.availableDeviceQuantity}',
            'Đang được thuê: ${data.rentedDeviceQuantity}',
            'Cần chú ý: ${attentionDevices.length}',
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Danh sách cần chú ý',
          subtitle: 'Thiết bị hết khả dụng, bảo trì hoặc hỏng',
          child: attentionDevices.isEmpty
              ? const Text('Không có thiết bị cần chú ý.')
              : Column(
                  children: attentionDevices
                      .map(
                        (device) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.warning_amber),
                          title: Text('${device.id} | ${device.name}'),
                          subtitle: Text(
                            'Trạng thái: ${device.status} - khả dụng ${device.quantityAvailable}/${device.quantityTotal}',
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _customerReport(_StatisticsData data) {
    final topCustomers = data.topCustomers.take(8).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bulletCard(
          title: 'Báo cáo khách hàng',
          rows: [
            'Tổng khách hàng: ${data.totalCustomers}',
            'Khách đã phát sinh đơn thuê: ${data.rentedCustomerCount}',
            'Khách chưa có đơn thuê: ${data.totalCustomers - data.rentedCustomerCount}',
            'Giá trị thuê trung bình/khách: ${_formatCurrency(data.averageRevenuePerCustomer)}',
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Khách hàng theo giá trị thuê',
          subtitle: 'Sắp xếp theo tổng tiền các phiếu mượn hiện có',
          child: topCustomers.isEmpty
              ? const Text('Chưa có dữ liệu đơn thuê theo khách hàng.')
              : Column(
                  children: topCustomers
                      .map(
                        (item) => ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text('${topCustomers.indexOf(item) + 1}'),
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            '${item.orderCount} đơn - ${_formatCurrency(item.revenue)}',
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _orderReport(_StatisticsData data) {
    final recentOrders = data.orders.take(10).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bulletCard(
          title: 'Báo cáo đơn thuê',
          rows: [
            'Tổng đơn thuê: ${data.totalOrders}',
            'Đơn đang thuê: ${data.activeOrders}',
            'Đơn trả hôm nay: ${data.dueTodayOrders}',
            'Đơn quá hạn: ${data.overdueOrders}',
          ],
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Bảng trạng thái đơn',
          subtitle: '10 phiếu mượn mới nhất trong dữ liệu',
          child: recentOrders.isEmpty
              ? const Text('Chưa có phiếu mượn.')
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Mã đơn')),
                      DataColumn(label: Text('Khách hàng')),
                      DataColumn(label: Text('Trạng thái')),
                      DataColumn(label: Text('Ngày trả')),
                    ],
                    rows: recentOrders
                        .map(
                          (order) => DataRow(
                            cells: [
                              DataCell(Text(order.id)),
                              DataCell(Text(order.customerName)),
                              DataCell(Text(order.status)),
                              DataCell(Text(_formatDate(order.endDate))),
                            ],
                          ),
                        )
                        .toList(),
                  ),
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

  Widget _legendRow(Color color, String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      final positionFromEnd = rounded.length - i;
      buffer.write(rounded[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    return '${buffer.toString()} đ';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  void dispose() {
    AppDataRefresh.notifier.removeListener(_handleDataRefresh);
    _tabController.dispose();
    super.dispose();
  }
}

class _StatisticsData {
  final List<RentalOrder> orders;
  final List<Device> devices;
  final List<Customer> customers;
  final DateTime today;

  _StatisticsData({
    required List<RentalOrder> orders,
    required this.devices,
    required this.customers,
  }) : orders = List<RentalOrder>.from(orders)
         ..sort((a, b) => b.startDate.compareTo(a.startDate)),
       today = DateTime.now();

  int get totalOrders => orders.length;

  int get activeOrders => orders.where(_isActiveOrder).length;

  int get dueTodayOrders => orders
      .where(
        (order) =>
            _isActiveOrder(order) &&
            _dateOnly(order.endDate) == _dateOnly(today),
      )
      .length;

  int get overdueOrders => orders
      .where(
        (order) =>
            _isActiveOrder(order) &&
            _dateOnly(order.endDate).isBefore(_dateOnly(today)),
      )
      .length;

  double get totalRevenue =>
      orders.fold<double>(0, (sum, order) => sum + order.totalPrice);

  double get averageRevenue =>
      totalOrders == 0 ? 0 : totalRevenue / totalOrders;

  double get monthRevenue => orders
      .where(
        (order) =>
            order.startDate.year == today.year &&
            order.startDate.month == today.month,
      )
      .fold<double>(0, (sum, order) => sum + order.totalPrice);

  double get activeOrderPercentage =>
      totalOrders == 0 ? 0 : activeOrders / totalOrders * 100;

  int get totalCustomers => customers.length;

  int get rentedCustomerCount =>
      orders.map((order) => order.customerName).toSet().length;

  double get averageRevenuePerCustomer =>
      rentedCustomerCount == 0 ? 0 : totalRevenue / rentedCustomerCount;

  int get totalDeviceQuantity =>
      devices.fold<int>(0, (sum, device) => sum + device.quantityTotal);

  int get availableDeviceQuantity =>
      devices.fold<int>(0, (sum, device) => sum + device.quantityAvailable);

  int get rentedDeviceQuantity =>
      (totalDeviceQuantity - availableDeviceQuantity).clamp(
        0,
        totalDeviceQuantity,
      );

  List<_CustomerRevenue> get topCustomers {
    final summaries = <String, _CustomerRevenue>{};
    for (final order in orders) {
      final summary =
          summaries[order.customerName] ??
          _CustomerRevenue(name: order.customerName);
      summaries[order.customerName] = summary.add(order.totalPrice);
    }
    final result = summaries.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    return result;
  }

  static bool _isActiveOrder(RentalOrder order) {
    return order.status == 'Đang thuê' ||
        order.status == 'Đang mượn' ||
        order.status == 'Quá hạn';
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}

class _CustomerRevenue {
  final String name;
  final double revenue;
  final int orderCount;

  const _CustomerRevenue({
    required this.name,
    this.revenue = 0,
    this.orderCount = 0,
  });

  _CustomerRevenue add(double orderRevenue) {
    return _CustomerRevenue(
      name: name,
      revenue: revenue + orderRevenue,
      orderCount: orderCount + 1,
    );
  }
}
