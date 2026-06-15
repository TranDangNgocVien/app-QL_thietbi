import 'package:flutter/material.dart';

import '../../models/maintenance_request.dart';
import '../../services/maintenance_request_service.dart';

class CustomerMaintenanceScreen extends StatefulWidget {
  const CustomerMaintenanceScreen({super.key});

  @override
  State<CustomerMaintenanceScreen> createState() =>
      _CustomerMaintenanceScreenState();
}

class _CustomerMaintenanceScreenState extends State<CustomerMaintenanceScreen> {
  late Future<List<MaintenanceRequest>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _requestsFuture = MaintenanceRequestService.instance.loadMyRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yêu cầu bảo trì của tôi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateScreen,
        icon: const Icon(Icons.add),
        label: const Text('Tạo yêu cầu'),
      ),
      body: FutureBuilder<List<MaintenanceRequest>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Không thể tải dữ liệu: ${snapshot.error}'),
            );
          }
          final requests = snapshot.data ?? const [];
          if (requests.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Bạn chưa có yêu cầu bảo trì.\n'
                  'Nhấn “Tạo yêu cầu” để báo sự cố cho thiết bị đã thuê.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _requestsFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _MaintenanceRequestCard(request: requests[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCreateScreen() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateMaintenanceRequestScreen()),
    );
    if (created == true && mounted) {
      setState(_reload);
    }
  }
}

class CreateMaintenanceRequestScreen extends StatefulWidget {
  const CreateMaintenanceRequestScreen({super.key});

  @override
  State<CreateMaintenanceRequestScreen> createState() =>
      _CreateMaintenanceRequestScreenState();
}

class _CreateMaintenanceRequestScreenState
    extends State<CreateMaintenanceRequestScreen> {
  static const _pageBackground = Color(0xFFF4F8FC);
  static const _fieldBackground = Colors.white;
  static const _primaryBlue = Color(0xFF1976D2);

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  late Future<List<MaintenanceDevice>> _devicesFuture;
  MaintenanceDevice? _selectedDevice;
  String _priority = 'medium';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _devicesFuture = MaintenanceRequestService.instance.loadEligibleDevices();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const Text(
          'Tạo yêu cầu bảo trì',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<MaintenanceDevice>>(
        future: _devicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Không thể tải thiết bị: ${snapshot.error}'),
            );
          }
          final devices = snapshot.data ?? const [];
          if (devices.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Chưa có thiết bị hợp lệ.\n'
                  'Yêu cầu bảo trì chỉ áp dụng cho thiết bị bạn đã từng thuê.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Text(
                  'Thông tin yêu cầu',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF183B56),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Chọn thiết bị đã thuê và mô tả rõ tình trạng gặp phải.',
                  style: TextStyle(
                    color: Color(0xFF526D82),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<MaintenanceDevice>(
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Thiết bị cần bảo trì',
                    icon: Icons.devices_other,
                  ),
                  items: devices
                      .map(
                        (device) => DropdownMenuItem(
                          value: device,
                          child: Text(
                            '${device.deviceName} - ${device.serialNumber}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF183B56),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => _selectedDevice = value,
                  validator: (value) =>
                      value == null ? 'Vui lòng chọn thiết bị' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: _inputDecoration(
                    label: 'Mức ưu tiên',
                    icon: Icons.priority_high,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Thấp')),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('Trung bình'),
                    ),
                    DropdownMenuItem(value: 'high', child: Text('Cao')),
                    DropdownMenuItem(
                      value: 'critical',
                      child: Text('Khẩn cấp'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) _priority = value;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 5,
                  maxLines: 8,
                  style: const TextStyle(
                    color: Color(0xFF183B56),
                    fontSize: 16,
                    height: 1.4,
                  ),
                  decoration: _inputDecoration(
                    label: 'Mô tả sự cố',
                    icon: Icons.description_outlined,
                    hintText:
                        'Mô tả dấu hiệu hư hỏng, thời điểm xảy ra và tình trạng hiện tại...',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().length < 10) {
                      return 'Mô tả phải có ít nhất 10 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.send),
                  label: Text(
                    _submitting ? 'Đang gửi yêu cầu...' : 'Gửi yêu cầu',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hintText,
  }) {
    const borderColor = Color(0xFFB7C9D6);
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      alignLabelWithHint: hintText != null,
      labelStyle: const TextStyle(
        color: Color(0xFF385A70),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF78909C),
        fontSize: 15,
        height: 1.4,
      ),
      prefixIcon: Icon(icon, color: _primaryBlue),
      filled: true,
      fillColor: _fieldBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primaryBlue, width: 2),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await MaintenanceRequestService.instance.createRequest(
        deviceDetailId: _selectedDevice!.detailId,
        priority: _priority,
        description: _descriptionController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu bảo trì')));
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _MaintenanceRequestCard extends StatelessWidget {
  final MaintenanceRequest request;

  const _MaintenanceRequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    request.deviceName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(label: Text(_statusLabel(request.status))),
              ],
            ),
            Text('Số seri: ${request.serialNumber}'),
            Text('Mức ưu tiên: ${_priorityLabel(request.priority)}'),
            const SizedBox(height: 8),
            Text(request.description),
            if (request.rejectionReason?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'Lý do từ chối: ${request.rejectionReason}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String value) {
    const labels = {
      'pending': 'Chờ duyệt',
      'approved': 'Đã duyệt',
      'in_progress': 'Đang xử lý',
      'completed': 'Hoàn thành',
      'rejected': 'Từ chối',
      'suspended': 'Tạm dừng',
    };
    return labels[value] ?? value;
  }

  String _priorityLabel(String value) {
    const labels = {
      'low': 'Thấp',
      'medium': 'Trung bình',
      'high': 'Cao',
      'critical': 'Khẩn cấp',
    };
    return labels[value] ?? value;
  }
}
