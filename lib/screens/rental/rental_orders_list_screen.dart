import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../../models/rental_order.dart';
import '../../services/order_service.dart';

class RentalOrdersListScreen extends StatefulWidget {
  const RentalOrdersListScreen({super.key});

  @override
  State<RentalOrdersListScreen> createState() => _RentalOrdersListScreenState();
}

class _RentalOrdersListScreenState extends State<RentalOrdersListScreen> {
  final _service = OrderService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      await _service.loadOrders(fallback: const []);
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể tải đơn thuê: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get rental orders from service
    final rentalOrders = _service.orders;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Danh sách đơn thuê"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1565C0),
      ),
      extendBodyBehindAppBar: false,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF00897B)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.3),
              spreadRadius: 3,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.pushNamed(context, AppRoutes.createRental);
            await _loadOrders();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add),
          label: const Text("Tạo đơn mới"),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFE8F2FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "Danh sách đơn thuê thiết bị",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D47A1),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : rentalOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.list_alt,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Chưa có đơn thuê nào",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Nhấn nút + để tạo đơn thuê mới",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: rentalOrders.length,
                        itemBuilder: (context, index) {
                          final order = rentalOrders[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.white, Colors.grey.shade50],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(20),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1565C0),
                                      Color(0xFF00897B),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_long,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                "Đơn thuê #${order.id}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Khách hàng: ${order.customerName}",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    "Thiết bị: ${order.deviceName}",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    "Tổng tiền: ${order.totalPrice.toInt().toString()}đ",
                                    style: const TextStyle(
                                      color: Color(0xFF1565C0),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(order.status),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          order.status,
                                          style: TextStyle(
                                            color: _getStatusTextColor(
                                              order.status,
                                            ),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showEditOrderDialog(order);
                                            return;
                                          }
                                          if (value == 'delete') {
                                            _confirmDeleteOrder(order);
                                          }
                                        },
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Sửa đơn'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Xóa đơn'),
                                          ),
                                        ],
                                        icon: const Icon(Icons.more_vert),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  if (order.status == 'Đang thuê' ||
                                      order.status == 'Quá hạn')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            AppRoutes.returnDevice,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.assignment_return,
                                        ),
                                        label: const Text('Trả thiết bị'),
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () {
                                // TODO: Navigate to order detail
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "Xem chi tiết đơn #${order.id}",
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Đang thuê":
        return const Color(0xFFBBDEFB);
      case "Đã trả":
        return const Color(0xFFC8E6C9);
      case "Quá hạn":
        return const Color(0xFFFFCDD2);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case "Đang thuê":
        return const Color(0xFF1976D2);
      case "Đã trả":
        return const Color(0xFF388E3C);
      case "Quá hạn":
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF616161);
    }
  }

  Future<void> _confirmDeleteOrder(RentalOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa đơn thuê'),
          content: Text('Bạn có chắc muốn xóa đơn #${order.id}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    _service.deleteOrder(order.id);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã xóa đơn #${order.id}')));
  }

  Future<void> _showEditOrderDialog(RentalOrder order) async {
    final customerController = TextEditingController(text: order.customerName);
    final deviceController = TextEditingController(text: order.deviceName);
    final totalController = TextEditingController(
      text: order.totalPrice.toStringAsFixed(0),
    );
    var selectedStatus = order.status;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Sửa đơn #${order.id}'),
          content: StatefulBuilder(
            builder: (context, setLocalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: customerController,
                      decoration: const InputDecoration(
                        labelText: 'Khách hàng',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: deviceController,
                      decoration: const InputDecoration(labelText: 'Thiết bị'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: totalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Tổng tiền'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Đang thuê',
                          child: Text('Đang thuê'),
                        ),
                        DropdownMenuItem(
                          value: 'Quá hạn',
                          child: Text('Quá hạn'),
                        ),
                        DropdownMenuItem(
                          value: 'Đã trả',
                          child: Text('Đã trả'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => selectedStatus = value);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;

    final updatedPrice = double.tryParse(totalController.text.trim());
    if (updatedPrice == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tổng tiền không hợp lệ')));
      return;
    }

    final updatedOrder = order.copyWith(
      customerName: customerController.text.trim(),
      deviceName: deviceController.text.trim(),
      totalPrice: updatedPrice,
      status: selectedStatus,
    );
    _service.updateOrder(order.id, updatedOrder);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã cập nhật đơn #${order.id}')));
  }
}
