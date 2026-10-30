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
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      await OrderService().loadOrders(fallback: const []);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải phiếu mượn: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFB0BEC5)),
    );

    final keyword = _searchController.text.trim().toLowerCase();
    final activeOrders = OrderService().orders
        .where((item) => item.status == 'Đang thuê' || item.status == 'Quá hạn')
        .where((item) {
          if (keyword.isEmpty) return true;
          return item.id.toLowerCase().contains(keyword) ||
              item.customerName.toLowerCase().contains(keyword) ||
              item.customerPhone.toLowerCase().contains(keyword);
        })
        .toList();

    final selectedOrder = _findSelectedOrder(activeOrders);
    final basePrice = selectedOrder?.totalPrice ?? 0;
    final lateFee = double.tryParse(_lateFeeController.text) ?? 0;
    final damageFee = double.tryParse(_damageController.text) ?? 0;
    final deposit = basePrice * 0.3;
    final payable = basePrice + lateFee + damageFee - deposit;

    return Scaffold(
      appBar: AppBar(title: const Text('Trả thiết bị')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Tìm theo mã phiếu, khách hàng, SĐT',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF00695C),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFE8F5F3),
                        border: lightBorder,
                        enabledBorder: lightBorder,
                        focusedBorder: lightBorder.copyWith(
                          borderSide: const BorderSide(
                            color: Color(0xFF00897B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Phiếu mượn đang hoạt động',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (activeOrders.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Không tìm thấy phiếu phù hợp để xử lý trả.',
                          ),
                        ),
                      )
                    else
                      ...activeOrders.take(4).map(_orderTile),
                    const SizedBox(height: 20),
                    _returnForm(lightBorder, selectedOrder),
                    const SizedBox(height: 12),
                    _paymentSummary(
                      basePrice,
                      lateFee,
                      damageFee,
                      deposit,
                      payable,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () => _completeReturn(
                              selectedOrder,
                              lateFee,
                              damageFee,
                              payable,
                            ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isSaving
                            ? 'Đang cập nhật...'
                            : 'Hoàn tất trả thiết bị',
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _orderTile(RentalOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        selected: _selectedOrderId == order.id,
        onTap: () => setState(() => _selectedOrderId = order.id),
        leading: const Icon(Icons.receipt_long),
        title: Text('Phiếu #${order.id}'),
        subtitle: Text('${order.customerName} - ${order.deviceName}'),
        trailing: Text(order.status),
      ),
    );
  }

  Widget _returnForm(
    OutlineInputBorder lightBorder,
    RentalOrder? selectedOrder,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Biên bản trả thiết bị',
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
                      ? 'Chưa chọn phiếu trả'
                      : 'Phiếu #${selectedOrder.id} - ${selectedOrder.customerName}',
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
                    '${_actualReturnDate.day}/${_actualReturnDate.month}/${_actualReturnDate.year} '
                    '${_actualReturnDate.hour.toString().padLeft(2, '0')}:'
                    '${_actualReturnDate.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: TextButton(
                    onPressed: _pickReturnDate,
                    child: const Text('Chọn'),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _deviceCondition,
                  decoration: _fieldDecoration(
                    lightBorder,
                    'Tình trạng thiết bị',
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
                  decoration: _fieldDecoration(
                    lightBorder,
                    'Phí trễ hạn (VND)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _damageController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: Colors.black87),
                  decoration: _fieldDecoration(
                    lightBorder,
                    'Chi phí bồi thường (VND)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(OutlineInputBorder border, String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFF00897B)),
      ),
    );
  }

  Widget _paymentSummary(
    double basePrice,
    double lateFee,
    double damageFee,
    double deposit,
    double payable,
  ) {
    return Card(
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
    );
  }

  Future<void> _pickReturnDate() async {
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

  RentalOrder? _findSelectedOrder(List<RentalOrder> filteredOrders) {
    if (filteredOrders.isEmpty) return null;
    if (_selectedOrderId == null) return filteredOrders.first;

    for (final order in filteredOrders) {
      if (order.id == _selectedOrderId) return order;
    }
    return filteredOrders.first;
  }

  Future<void> _completeReturn(
    RentalOrder? selectedOrder,
    double lateFee,
    double damageFee,
    double payable,
  ) async {
    if (selectedOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn phiếu mượn để trả thiết bị'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await OrderService().completeReturn(
        order: selectedOrder,
        actualReturnDate: _actualReturnDate,
        deviceCondition: _deviceCondition,
        lateFee: lateFee,
        damageFee: damageFee,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể trả thiết bị: $error')));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Hoàn tất trả phiếu #${selectedOrder.id}. Phí trễ: ${lateFee.toStringAsFixed(0)}đ, '
          'bồi thường: ${damageFee.toStringAsFixed(0)}đ, phải thu: ${payable.toStringAsFixed(0)}đ',
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _lateFeeController.dispose();
    _damageController.dispose();
    super.dispose();
  }
}
