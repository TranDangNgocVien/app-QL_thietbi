import 'package:flutter/material.dart';

import '../../models/rental_order.dart';
import '../../services/order_service.dart';

class ReturnDeviceScreen extends StatefulWidget {
  const ReturnDeviceScreen({super.key});

  @override
  State<ReturnDeviceScreen> createState() => _ReturnDeviceScreenState();
}

class _ReturnDeviceScreenState extends State<ReturnDeviceScreen> {
  final _searchController = TextEditingController();
  final _damageController = TextEditingController(text: '0');
  final _lateFeeController = TextEditingController(text: '0');

  String _deviceCondition = 'Tốt';
  DateTime _actualReturnDate = DateTime.now();
  String? _selectedOrderId;

  @override
  Widget build(BuildContext context) {
    final lightBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFB0BEC5)),
    );

    final orders = OrderService().orders;
    final activeOrders = orders
        .where((item) => item.status == 'Đang thuê' || item.status == 'Quá hạn')
        .toList();

    final keyword = _searchController.text.trim().toLowerCase();
    final filteredOrders = activeOrders.where((item) {
      if (keyword.isEmpty) return true;
      return item.id.toLowerCase().contains(keyword) ||
          item.customerName.toLowerCase().contains(keyword) ||
          item.customerPhone.toLowerCase().contains(keyword);
    }).toList();

    final selectedOrder = _findSelectedOrder(filteredOrders);
    final basePrice = selectedOrder?.totalPrice ?? 0;
    final lateFee = double.tryParse(_lateFeeController.text) ?? 0;
    final damageFee = double.tryParse(_damageController.text) ?? 0;
    final deposit = basePrice * 0.3;
    final payable = basePrice + lateFee + damageFee - deposit;

    return Scaffold(
      appBar: AppBar(title: const Text('Trả thiết bị')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Tìm theo mã đơn, khách hàng, SĐT',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF00695C),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFE8F5F3),
                  border: lightBorder,
                  enabledBorder: lightBorder,
                  focusedBorder: lightBorder.copyWith(
                    borderSide: const BorderSide(color: Color(0xFF00897B)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Đơn thuê đang hoạt động',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (filteredOrders.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Không tìm thấy đơn phù hợp để xử lý trả.'),
                  ),
                )
              else
                ...filteredOrders
                    .take(4)
                    .map(
                      (order) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          selected: selectedOrder?.id == order.id,
                          onTap: () {
                            setState(() {
                              _selectedOrderId = order.id;
                            });
                          },
                          leading: const Icon(Icons.receipt_long),
                          title: Text('Đơn #${order.id}'),
                          subtitle: Text(
                            '${order.customerName} - ${order.deviceName}',
                          ),
                          trailing: Text(order.status),
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              Text(
                'Biên bản trả thiết bị (UI mô phỏng)',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedOrder == null
                            ? 'Chưa chọn đơn trả'
                            : 'Đơn #${selectedOrder.id} - ${selectedOrder.customerName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.schedule),
                        title: const Text('Ngày giờ trả thực tế'),
                        subtitle: Text(
                          '${_actualReturnDate.day}/${_actualReturnDate.month}/${_actualReturnDate.year} ${_actualReturnDate.hour.toString().padLeft(2, '0')}:${_actualReturnDate.minute.toString().padLeft(2, '0')}',
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2030),
                              initialDate: _actualReturnDate,
                            );

                            if (pickedDate == null || !mounted) return;

                            setState(() {
                              _actualReturnDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                _actualReturnDate.hour,
                                _actualReturnDate.minute,
                              );
                            });
                          },
                          child: const Text('Chọn'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _deviceCondition,
                        decoration: InputDecoration(
                          labelText: 'Tình trạng thiết bị',
                          filled: true,
                          fillColor: Colors.white,
                          border: lightBorder,
                          enabledBorder: lightBorder,
                          focusedBorder: lightBorder.copyWith(
                            borderSide: const BorderSide(
                              color: Color(0xFF00897B),
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Tốt', child: Text('Tốt')),
                          DropdownMenuItem(
                            value: 'Trầy xước',
                            child: Text('Trầy xước'),
                          ),
                          DropdownMenuItem(value: 'Hỏng', child: Text('Hỏng')),
                          DropdownMenuItem(
                            value: 'Thiếu/mất',
                            child: Text('Thiếu/mất'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _deviceCondition = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _lateFeeController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Phí trễ hạn (VND)',
                          filled: true,
                          fillColor: Colors.white,
                          border: lightBorder,
                          enabledBorder: lightBorder,
                          focusedBorder: lightBorder.copyWith(
                            borderSide: const BorderSide(
                              color: Color(0xFF00897B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _damageController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Chi phí bồi thường (VND)',
                          filled: true,
                          fillColor: Colors.white,
                          border: lightBorder,
                          enabledBorder: lightBorder,
                          focusedBorder: lightBorder.copyWith(
                            borderSide: const BorderSide(
                              color: Color(0xFF00897B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFFFDFEFE),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tổng hợp thanh toán',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      _line('Tiền thuê', basePrice),
                      _line('Phí trễ hạn', lateFee),
                      _line('Bồi thường', damageFee),
                      _line('Trừ tiền cọc (ước tính 30%)', -deposit),
                      const Divider(height: 24),
                      _line('Khách cần thanh toán', payable, isTotal: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  _completeReturn(selectedOrder, lateFee, damageFee, payable);
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Hoàn tất trả thiết bị'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, double value, {bool isTotal = false}) {
    final color = isTotal ? Colors.blue.shade800 : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '${value.toStringAsFixed(0)} đ',
            style: TextStyle(
              color: color,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _lateFeeController.dispose();
    _damageController.dispose();
    super.dispose();
  }

  RentalOrder? _findSelectedOrder(List<RentalOrder> filteredOrders) {
    if (filteredOrders.isEmpty) return null;
    if (_selectedOrderId == null) return filteredOrders.first;

    for (final order in filteredOrders) {
      if (order.id == _selectedOrderId) {
        return order;
      }
    }
    return filteredOrders.first;
  }

  void _completeReturn(
    RentalOrder? selectedOrder,
    double lateFee,
    double damageFee,
    double payable,
  ) {
    if (selectedOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn đơn thuê để trả thiết bị')),
      );
      return;
    }

    final updatedOrder = selectedOrder.copyWith(status: 'Đã trả');
    OrderService().updateOrder(selectedOrder.id, updatedOrder);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Hoàn tất trả đơn #${selectedOrder.id}. Phí trễ: ${lateFee.toStringAsFixed(0)}đ, bồi thường: ${damageFee.toStringAsFixed(0)}đ, phải thu: ${payable.toStringAsFixed(0)}đ',
        ),
      ),
    );

    Navigator.pop(context, true);
  }
}
