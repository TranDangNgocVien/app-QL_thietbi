import 'package:flutter/material.dart';

import '../../core/app_data_refresh.dart';
import '../../models/customer.dart';
import '../../services/customer_storage_service.dart';
import 'customer_form_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Customer> _customers = const [];
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    AppDataRefresh.notifier.addListener(_loadCustomers);
  }

  Future<void> _loadCustomers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final loaded = await CustomerStorageService.instance.loadCustomers();
      if (!mounted) return;
      setState(() {
        _customers = loaded;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  List<Customer> get _filteredCustomers {
    final keyword = _searchController.text.trim().toLowerCase();
    return _customers.where((customer) {
      if (keyword.isEmpty) return true;
      return customer.id.toLowerCase().contains(keyword) ||
          customer.name.toLowerCase().contains(keyword) ||
          customer.phone.toLowerCase().contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
          );
          await _loadCustomers();
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm khách hàng'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xF3E5F5FF)],
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (Navigator.canPop(context))
                          IconButton(
                            tooltip: 'Quay lại',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new),
                          ),
                        Text(
                          'Khách hàng',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.people, color: Colors.blue),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm khách hàng...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                    ? _errorState()
                    : _filteredCustomers.isEmpty
                    ? _emptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  customer.name.isEmpty
                                      ? '?'
                                      : customer.name[0],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              title: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Mã: ${customer.id}'),
                                  Text('SĐT: ${customer.phone}'),
                                  Text(
                                    customer.address,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CustomerFormScreen(customer: customer),
                                  ),
                                );
                                await _loadCustomers();
                              },
                              onLongPress: () =>
                                  _confirmDeleteCustomer(customer),
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

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Chưa có khách hàng',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Không tải được dữ liệu khách hàng: $_loadError',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadCustomers,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCustomer(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa khách hàng'),
          content: Text('Bạn có chắc muốn xóa khách ${customer.name}?'),
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

    try {
      await CustomerStorageService.instance.deleteCustomer(customer.id);
      AppDataRefresh.notifyChanged();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa khách hàng ${customer.name}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    AppDataRefresh.notifier.removeListener(_loadCustomers);
    _searchController.dispose();
    super.dispose();
  }
}
