import 'package:flutter/material.dart';

import '../../data/dummy_data.dart';
import '../../models/customer.dart';
import '../../models/device.dart';
import '../../models/rental_order.dart';
import '../../services/order_service.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderService = OrderService();

  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _customerAddressController = TextEditingController();

  List<Customer> _customers = const [];
  List<Device> _availableDevices = const [];
  Customer? _selectedCustomer;
  Device? _selectedDevice;
  DateTimeRange? _selectedDate;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  @override
  void dispose() {
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _customerAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() => _isLoading = true);
    setState(() {
      _customers = List<Customer>.from(customers);
      _availableDevices = devices
          .where((device) => device.quantityAvailable > 0)
          .toList();
      _isLoading = false;
    });
  }

  int get _rentalDays {
    if (_selectedDate == null) return 0;
    final days = _selectedDate!.end.difference(_selectedDate!.start).inDays;
    return days <= 0 ? 1 : days;
  }

  double get _totalPrice {
    if (_selectedDevice == null || _selectedDate == null) return 0;
    return _rentalDays * _selectedDevice!.pricePerDay;
  }

  void _selectCustomer(Customer? customer) {
    setState(() {
      _selectedCustomer = customer;
      _customerPhoneController.text = customer?.phone ?? '';
      _customerEmailController.text = customer?.email ?? '';
      _customerAddressController.text = customer?.address ?? '';
    });
  }

  Future<void> _createOrder() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ngày thuê')));
      return;
    }

    final customer = _selectedCustomer;
    final device = _selectedDevice;
    if (customer == null || device == null) return;

    setState(() => _isSaving = true);
    try {
      final order = RentalOrder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        customerName: customer.name,
        customerPhone: customer.phone,
        customerEmail: customer.email,
        customerAddress: customer.address,
        deviceName: device.name,
        startDate: _selectedDate!.start,
        endDate: _selectedDate!.end,
        totalPrice: _totalPrice,
        status: 'Đang thuê',
      );
      _orderService.addOrder(order);

      final deviceIndex = devices.indexWhere((item) => item.id == device.id);
      if (deviceIndex != -1) {
        final current = devices[deviceIndex];
        final nextAvailable = current.quantityAvailable - 1;
        devices[deviceIndex] = current.copyWith(
          quantityAvailable: nextAvailable < 0 ? 0 : nextAvailable,
          status: nextAvailable <= 0 ? 'Bảo trì' : 'Đang cho thuê',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tạo đơn thuê thành công')));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tạo được đơn thuê: $error')),
      );
      await _loadFormData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFCFD8DC)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo đơn thuê')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đơn vị/khách hàng thuê',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Customer>(
                      initialValue: _selectedCustomer,
                      isExpanded: true,
                      decoration: _decoration(
                        baseInputBorder,
                        'Chọn đơn vị thuê',
                      ),
                      items: _customers
                          .map(
                            (customer) => DropdownMenuItem(
                              value: customer,
                              child: Text(
                                '${customer.id} - ${customer.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      validator: (value) =>
                          value == null ? 'Vui lòng chọn khách hàng' : null,
                      onChanged: _isSaving ? null : _selectCustomer,
                    ),
                    const SizedBox(height: 16),
                    _readonlyField(
                      controller: _customerPhoneController,
                      label: 'Số điện thoại',
                      icon: Icons.phone,
                      border: baseInputBorder,
                    ),
                    const SizedBox(height: 16),
                    _readonlyField(
                      controller: _customerEmailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      border: baseInputBorder,
                    ),
                    const SizedBox(height: 16),
                    _readonlyField(
                      controller: _customerAddressController,
                      label: 'Địa chỉ',
                      icon: Icons.location_on_outlined,
                      border: baseInputBorder,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Thiết bị khả dụng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Device>(
                      initialValue: _selectedDevice,
                      isExpanded: true,
                      decoration: _decoration(baseInputBorder, 'Chọn thiết bị'),
                      items: _availableDevices
                          .map(
                            (device) => DropdownMenuItem(
                              value: device,
                              child: Text(
                                '${device.name} (${device.quantityAvailable} khả dụng)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      validator: (value) =>
                          value == null ? 'Vui lòng chọn thiết bị' : null,
                      onChanged: _isSaving
                          ? null
                          : (value) => setState(() => _selectedDevice = value),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _selectedDate == null
                            ? 'Chọn ngày thuê'
                            : '${_selectedDate!.start.day}/${_selectedDate!.start.month}/${_selectedDate!.start.year} - ${_selectedDate!.end.day}/${_selectedDate!.end.month}/${_selectedDate!.end.year}',
                      ),
                      onPressed: _isSaving ? null : _pickDateRange,
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const Text('Thanh toán dự kiến'),
                    const SizedBox(height: 10),
                    Text(
                      '${_totalPrice.toStringAsFixed(0)} VNĐ',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _createOrder,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.assignment_turned_in_outlined),
                      label: Text(_isSaving ? 'Đang lưu...' : 'Tạo đơn'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDate,
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  InputDecoration _decoration(OutlineInputBorder border, String label) {
    return InputDecoration(
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: Colors.blue),
      ),
      filled: true,
      fillColor: Colors.white,
      labelText: label,
    );
  }

  Widget _readonlyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required OutlineInputBorder border,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(color: Colors.black87),
      decoration: _decoration(border, label).copyWith(prefixIcon: Icon(icon)),
    );
  }
}
