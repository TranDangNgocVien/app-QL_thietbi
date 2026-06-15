import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../../models/device.dart';
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
                          final canEdit = !_isClosedOrder(order);
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
                                          if (value == 'view') {
                                            _showOrderDetails(order);
                                            return;
                                          }
                                          if (value == 'edit') {
                                            _showEditOrderDialog(order);
                                            return;
                                          }
                                          if (value == 'delete') {
                                            _confirmDeleteOrder(order);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'view',
                                            child: Text('Xem chi tiết'),
                                          ),
                                          if (canEdit)
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Sửa đơn'),
                                            ),
                                          const PopupMenuItem(
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
                                        onPressed: () async {
                                          await Navigator.pushNamed(
                                            context,
                                            AppRoutes.returnDevice,
                                          );
                                          await _loadOrders();
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
                                _showOrderDetails(order);
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
      case "Hoàn thành":
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
      case "Hoàn thành":
        return const Color(0xFF388E3C);
      case "Quá hạn":
        return const Color(0xFFD32F2F);
      default:
        return const Color(0xFF616161);
    }
  }

  bool _isClosedOrder(RentalOrder order) {
    return order.status == 'Hoàn thành' || order.status == 'Đã trả';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatMoney(double value) {
    return '${value.toInt().toString()}đ';
  }

  InputDecoration _editInputDecoration({
    required String labelText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(
        color: Color(0xFF0D47A1),
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF0D47A1),
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
      filled: true,
      fillColor: Colors.white,
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFB0BEC5)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
      ),
    );
  }

  Future<List<Device>> _editableDevicesFor(RentalOrder order) async {
    final devices = await _service.loadDevices();
    final editableDevices = devices
        .where(
          (device) =>
              device.quantityAvailable > 0 || device.name == order.deviceName,
        )
        .toList();
    return editableDevices.isEmpty ? devices : editableDevices;
  }

  int _maxEditableQuantity(RentalOrder order, Device device) {
    final borrowedQuantity = device.name == order.deviceName
        ? order.quantity
        : 0;
    final maxQuantity = device.quantityAvailable + borrowedQuantity;
    return maxQuantity <= 0 ? 1 : maxQuantity;
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

  Future<void> _showOrderDetails(RentalOrder order) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Chi tiết đơn #${order.id}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailRow(label: 'Khách hàng', value: order.customerName),
                _DetailRow(label: 'Số điện thoại', value: order.customerPhone),
                _DetailRow(label: 'Email', value: order.customerEmail),
                _DetailRow(label: 'Địa chỉ', value: order.customerAddress),
                _DetailRow(label: 'Thiết bị', value: order.deviceName),
                _DetailRow(label: 'Số lượng', value: order.quantity.toString()),
                _DetailRow(
                  label: 'Ngày thuê',
                  value: _formatDate(order.startDate),
                ),
                _DetailRow(
                  label: 'Ngày trả',
                  value: _formatDate(order.endDate),
                ),
                _DetailRow(
                  label: 'Tổng tiền',
                  value: _formatMoney(order.totalPrice),
                ),
                _DetailRow(label: 'Trạng thái', value: order.status),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
            if (!_isClosedOrder(order))
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditOrderDialog(order);
                },
                icon: const Icon(Icons.edit),
                label: const Text('Sửa'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showEditOrderDialog(RentalOrder order) async {
    if (_isClosedOrder(order)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đơn #${order.id} đã hoàn thành, không thể sửa'),
        ),
      );
      return;
    }

    final customerController = TextEditingController(text: order.customerName);
    final quantityController = TextEditingController(
      text: order.quantity.toString(),
    );
    final totalController = TextEditingController(
      text: order.totalPrice.toStringAsFixed(0),
    );
    final availableDevices = await _editableDevicesFor(order);
    if (!mounted) return;
    if (availableDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có thiết bị khả dụng để chọn')),
      );
      return;
    }
    Device selectedDevice = availableDevices.firstWhere(
      (device) => device.name == order.deviceName,
      orElse: () => availableDevices.first,
    );
    var selectedQuantity = order.quantity <= 0 ? 1 : order.quantity;
    final initialMaxQuantity = _maxEditableQuantity(order, selectedDevice);
    if (selectedQuantity > initialMaxQuantity) {
      selectedQuantity = initialMaxQuantity;
      quantityController.text = selectedQuantity.toString();
    }
    final statusItems = <String>{
      'Đang thuê',
      'Quá hạn',
      'Đã trả',
      if (order.status.isNotEmpty) order.status,
    }.toList();
    var selectedStatus = order.status;

    void syncTotal() {
      final days = order.endDate.difference(order.startDate).inDays;
      final chargedDays = days <= 0 ? 1 : days;
      totalController.text =
          (chargedDays * selectedDevice.pricePerDay * selectedQuantity)
              .toStringAsFixed(0);
    }

    syncTotal();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Sửa đơn #${order.id}'),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          content: StatefulBuilder(
            builder: (context, setLocalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EditSectionHeader(
                      title: 'Thông tin thuê',
                      subtitle: 'Chỉnh các thông tin cần cập nhật cho đơn này',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: customerController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: _editInputDecoration(
                        labelText: 'Khách hàng',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<Device>(
                      initialValue: selectedDevice,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black87),
                      decoration: _editInputDecoration(
                        labelText: 'Thiết bị',
                        icon: Icons.devices_outlined,
                      ),
                      items: availableDevices
                          .map(
                            (device) => DropdownMenuItem<Device>(
                              value: device,
                              child: Text(
                                '${device.name} - còn ${device.quantityAvailable}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() {
                          selectedDevice = value;
                          final maxQuantity = _maxEditableQuantity(
                            order,
                            selectedDevice,
                          );
                          if (selectedQuantity > maxQuantity) {
                            selectedQuantity = maxQuantity;
                            quantityController.text = selectedQuantity
                                .toString();
                          }
                          syncTotal();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.black87),
                      decoration:
                          _editInputDecoration(
                            labelText: 'Số lượng cho mượn',
                            icon: Icons.format_list_numbered,
                          ).copyWith(
                            helperText:
                                'Tối đa ${_maxEditableQuantity(order, selectedDevice)} thiết bị',
                            helperStyle: const TextStyle(
                              color: Color(0xFF546E7A),
                            ),
                          ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value.trim()) ?? 1;
                        final maxQuantity = _maxEditableQuantity(
                          order,
                          selectedDevice,
                        );
                        setLocalState(() {
                          selectedQuantity = parsed.clamp(1, maxQuantity);
                          if (parsed != selectedQuantity) {
                            quantityController.text = selectedQuantity
                                .toString();
                            quantityController.selection =
                                TextSelection.fromPosition(
                                  TextPosition(
                                    offset: quantityController.text.length,
                                  ),
                                );
                          }
                          syncTotal();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: totalController,
                      readOnly: true,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration:
                          _editInputDecoration(
                            labelText: 'Tổng tiền',
                            icon: Icons.payments_outlined,
                          ).copyWith(
                            suffixText: 'đ',
                            suffixStyle: const TextStyle(color: Colors.black87),
                          ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black87),
                      decoration: _editInputDecoration(
                        labelText: 'Trạng thái',
                        icon: Icons.flag_outlined,
                      ),
                      items: statusItems
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
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
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Lưu'),
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
      deviceName: selectedDevice.name,
      quantity: selectedQuantity,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Chưa có' : value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditSectionHeader extends StatelessWidget {
  const _EditSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F2FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
