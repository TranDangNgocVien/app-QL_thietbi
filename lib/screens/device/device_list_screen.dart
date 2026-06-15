import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/app_messenger.dart';
import '../../core/constants/user_session.dart';
import '../../data/dummy_data.dart';
import '../../models/device.dart';
import 'device_action_result.dart';
import 'device_detail_screen.dart';
import 'device_form_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listController = ScrollController();
  String _selectedCategory = 'Tất cả';
  String _selectedStatus = 'Tất cả';

  List<Device> get _filteredDevices {
    final keyword = _searchController.text.trim().toLowerCase();
    return devices.where((device) {
      final matchesKeyword =
          keyword.isEmpty ||
          device.name.toLowerCase().contains(keyword) ||
          device.id.toLowerCase().contains(keyword);
      final matchesCategory =
          _selectedCategory == 'Tất cả' || device.type == _selectedCategory;
      final matchesStatus =
          _selectedStatus == 'Tất cả' || device.status == _selectedStatus;
      return matchesKeyword && matchesCategory && matchesStatus;
    }).toList();
  }

  List<String> get _categories {
    final values = devices.map((item) => item.type).toSet().toList()..sort();
    return ['Tất cả', ...values];
  }

  List<String> get _statuses {
    final values = devices.map((item) => item.status).toSet().toList()..sort();
    return ['Tất cả', ...values];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: UserSession.isCustomer
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeviceFormScreen()),
                );
                await _handleActionResult(result);
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm thiết bị'),
            ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xE8F5E9FF)],
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
                          'Thiết bị',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.devices, color: Colors.green),
                      ],
                    ),
                    if (!UserSession.isCustomer)
                      IconButton(
                        tooltip: 'Xuất backup JSON',
                        onPressed: _exportDevicesBackup,
                        icon: const Icon(Icons.backup_outlined),
                      ),
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
                    hintText: 'Tìm theo tên hoặc mã thiết bị...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown(
                        value: _selectedCategory,
                        items: _categories,
                        label: 'Danh mục',
                        onChanged: (value) {
                          setState(() => _selectedCategory = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        value: _selectedStatus,
                        items: _statuses,
                        label: 'Trạng thái',
                        onChanged: (value) {
                          setState(() => _selectedStatus = value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _filteredDevices.isEmpty
                    ? const Center(child: Text('Không có thiết bị phù hợp'))
                    : ListView.builder(
                        controller: _listController,
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                        itemCount: _filteredDevices.length,
                        itemBuilder: (context, index) {
                          final device = _filteredDevices[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _buildDeviceImage(
                                  device.images.first,
                                  width: 55,
                                  height: 55,
                                ),
                              ),
                              title: Text(
                                device.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                '${device.id} • ${device.type} • ${device.quantityAvailable}/${device.quantityTotal} khả dụng\n${device.pricePerDay.toInt()}đ / ngày',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              isThreeLine: true,
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(device.status),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  device.status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusTextColor(device.status),
                                  ),
                                ),
                              ),
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DeviceDetailScreen(device: device),
                                  ),
                                );
                                await _handleActionResult(result);
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

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        onChanged(value);
      },
    );
  }

  Future<void> _handleActionResult(Object? result) async {
    if (result is! DeviceActionResult || !mounted) return;
    setState(() {
      _searchController.clear();
      _selectedCategory = 'Tất cả';
      _selectedStatus = 'Tất cả';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_listController.hasClients) _listController.jumpTo(0);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showAppMessage(result.successMessage);
    });
  }

  Future<void> _exportDevicesBackup() async {
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(devices.map((device) => device.toJson()).toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backup JSON có ${jsonString.length} ký tự')),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Sẵn sàng':
        return const Color(0xFFC8E6C9);
      case 'Đang cho thuê':
        return Colors.orange.shade100;
      case 'Bảo trì':
        return Colors.red.shade100;
      case 'Hỏng':
        return Colors.grey.shade300;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'Sẵn sàng':
        return const Color(0xFF2E7D32);
      case 'Đang cho thuê':
        return Colors.orange.shade800;
      case 'Bảo trì':
        return Colors.red.shade800;
      case 'Hỏng':
        return Colors.grey.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  Widget _buildDeviceImage(
    String imageRef, {
    required double width,
    required double height,
  }) {
    if (imageRef.startsWith('base64:')) {
      return Image.memory(
        base64Decode(imageRef.substring(7)),
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }
    return Image.asset(
      imageRef,
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }
}
