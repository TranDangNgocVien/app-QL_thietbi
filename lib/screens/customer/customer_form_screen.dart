import 'package:flutter/material.dart';

import '../../core/app_data_refresh.dart';
import '../../models/customer.dart';
import '../../services/customer_storage_service.dart';

class CustomerFormScreen extends StatefulWidget {
  final Customer? customer;

  const CustomerFormScreen({super.key, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  List<Customer> _customers = const [];
  bool _isLoadingCustomers = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _nameController = TextEditingController(text: customer?.name ?? '');
    _phoneController = TextEditingController(text: customer?.phone ?? '');
    _emailController = TextEditingController(text: customer?.email ?? '');
    _addressController = TextEditingController(text: customer?.address ?? '');
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final loaded = await CustomerStorageService.instance.loadCustomers();
      if (!mounted) return;
      setState(() {
        _customers = loaded;
        _isLoadingCustomers = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingCustomers = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.customer != null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE3F2FD), Color(0xFFF3E5F5)],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        isEditMode
                            ? 'Chỉnh sửa khách hàng'
                            : 'Thêm khách hàng mới',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFormField(
                          label: 'Tên khách hàng',
                          hint: 'Nhập tên khách hàng',
                          icon: Icons.person,
                          controller: _nameController,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Vui lòng nhập tên khách hàng'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        _buildFormField(
                          label: 'Số điện thoại',
                          hint: 'Nhập số điện thoại',
                          icon: Icons.phone,
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            final phone = value?.trim() ?? '';
                            if (phone.isEmpty) {
                              return 'Vui lòng nhập số điện thoại';
                            }
                            final phoneRegex = RegExp(r'^[0-9]{10,11}$');
                            if (!phoneRegex.hasMatch(phone)) {
                              return 'Số điện thoại phải có 10-11 chữ số';
                            }
                            final duplicate = _customers.any(
                              (item) =>
                                  item.phone == phone &&
                                  item.id != widget.customer?.id,
                            );
                            if (duplicate) {
                              return 'Số điện thoại đã tồn tại';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildFormField(
                          label: 'Email',
                          hint: 'Nhập email',
                          icon: Icons.email,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isEmpty) return null;
                            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                            if (!emailRegex.hasMatch(email)) {
                              return 'Email không hợp lệ';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildFormField(
                          label: 'Địa chỉ',
                          hint: 'Nhập địa chỉ',
                          icon: Icons.location_on,
                          controller: _addressController,
                          maxLines: 2,
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Vui lòng nhập địa chỉ'
                              : null,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.blue, Color(0xFF9C27B0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoadingCustomers || _isSaving
                                  ? null
                                  : _saveCustomer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                isEditMode
                                    ? 'Cập nhật khách hàng'
                                    : 'Lưu khách hàng',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.05),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: Colors.blue, size: 22),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Colors.blue, width: 2),
            ),
            hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final customer = Customer(
      id: widget.customer?.id ?? _generateCustomerId(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
    );

    try {
      await CustomerStorageService.instance.saveCustomer(customer);
      AppDataRefresh.notifyChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.customer == null
              ? 'Khách hàng đã được lưu!'
              : 'Khách hàng đã được cập nhật!',
        ),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, customer);
  }

  String _generateCustomerId() {
    var maxNumber = 0;
    for (final customer in _customers) {
      final digits = RegExp(r'\d+').firstMatch(customer.id)?.group(0);
      final number = int.tryParse(digits ?? '0') ?? 0;
      if (number > maxNumber) {
        maxNumber = number;
      }
    }
    final nextNumber = maxNumber + 1;
    return 'KH-${nextNumber.toString().padLeft(3, '0')}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
