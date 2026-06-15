import 'package:flutter/material.dart';

import '../../core/constants/user_session.dart';
import '../../models/maintenance_request.dart';
import '../../services/maintenance_request_service.dart';

class MaintenanceReviewScreen extends StatefulWidget {
  const MaintenanceReviewScreen({super.key});

  @override
  State<MaintenanceReviewScreen> createState() =>
      _MaintenanceReviewScreenState();
}

class _MaintenanceReviewScreenState extends State<MaintenanceReviewScreen> {
  static const _primary = Color(0xFF1976D2);
  static const _textPrimary = Color(0xFF183B56);
  static const _textSecondary = Color(0xFF526D82);

  late Future<List<MaintenanceRequest>> _requestsFuture;
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _requestsFuture = MaintenanceRequestService.instance
        .loadRequestsForReview();
  }

  @override
  Widget build(BuildContext context) {
    if (UserSession.isCustomer) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Text('Khách hàng không có quyền duyệt yêu cầu bảo trì.'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        title: const Text(
          'Duyệt yêu cầu bảo trì',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<MaintenanceRequest>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: 'Không thể tải yêu cầu',
              onRetry: () => setState(_reload),
            );
          }

          final allRequests = snapshot.data ?? const [];
          final requests = _filter == 'all'
              ? allRequests
              : allRequests
                    .where((request) => request.status == _filter)
                    .toList();

          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _requestsFuture;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildOverview(allRequests)),
                SliverToBoxAdapter(child: _buildFilters()),
                if (requests.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyView(filter: _filter),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    sliver: SliverList.separated(
                      itemCount: requests.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _ReviewCard(
                          request: requests[index],
                          onApproved: _approve,
                          onRejected: _reject,
                          onAssigned: _assign,
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverview(List<MaintenanceRequest> requests) {
    final pending = requests
        .where((request) => request.status == 'pending')
        .length;
    final processed = requests.length - pending;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332196F3),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(Icons.fact_check_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yêu cầu bảo trì',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pending chờ duyệt  •  $processed đã xử lý',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const filters = [
      ('pending', 'Chờ duyệt', Icons.schedule),
      ('approved', 'Đã duyệt', Icons.check_circle_outline),
      ('rejected', 'Từ chối', Icons.cancel_outlined),
      ('all', 'Tất cả', Icons.list_alt),
    ];

    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _filter == filter.$1;
          return FilterChip(
            selected: selected,
            showCheckmark: false,
            avatar: Icon(
              filter.$3,
              size: 19,
              color: selected ? Colors.white : _textSecondary,
            ),
            label: Text(filter.$2),
            labelStyle: TextStyle(
              color: selected ? Colors.white : _textPrimary,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: _primary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? _primary : const Color(0xFFD4E1EA),
            ),
            onSelected: (_) => setState(() => _filter = filter.$1),
          );
        },
      ),
    );
  }

  Future<void> _approve(MaintenanceRequest request) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận yêu cầu'),
        content: Text(
          'Xác nhận bảo trì ${request.deviceName} '
          '(${request.serialNumber}) cho ${request.requesterName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await MaintenanceRequestService.instance.approveRequest(request.id);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xác nhận yêu cầu bảo trì')),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<void> _reject(MaintenanceRequest request) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RejectReasonDialog(deviceName: request.deviceName),
    );
    if (reason == null || !mounted) return;

    try {
      await MaintenanceRequestService.instance.rejectRequest(
        requestId: request.id,
        reason: reason,
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã từ chối yêu cầu bảo trì')),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<void> _assign(MaintenanceRequest request) async {
    final technician = await showDialog<TechnicianAccount>(
      context: context,
      builder: (_) => const AssignTechnicianDialog(),
    );
    if (technician == null || !mounted) return;

    try {
      await MaintenanceRequestService.instance.assignTechnician(
        requestId: request.id,
        technicianId: technician.id,
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã phân công cho ${technician.name}')),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  void _showError(Object error) {
    final message = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }
}

class AssignTechnicianDialog extends StatefulWidget {
  const AssignTechnicianDialog({super.key});

  @override
  State<AssignTechnicianDialog> createState() => _AssignTechnicianDialogState();
}

class _AssignTechnicianDialogState extends State<AssignTechnicianDialog> {
  late Future<List<TechnicianAccount>> _techniciansFuture;
  TechnicianAccount? _selected;

  @override
  void initState() {
    super.initState();
    _techniciansFuture = MaintenanceRequestService.instance.loadTechnicians();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Phân công kỹ thuật viên',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<TechnicianAccount>>(
          future: _techniciansFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const Text('Không thể tải danh sách kỹ thuật viên');
            }
            final technicians = snapshot.data ?? const [];
            if (technicians.isEmpty) {
              return const Text('Chưa có tài khoản kỹ thuật viên hoạt động');
            }
            return DropdownButtonFormField<TechnicianAccount>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Kỹ thuật viên',
                prefixIcon: Icon(Icons.engineering_outlined),
                filled: true,
                fillColor: Colors.white,
              ),
              items: technicians
                  .map(
                    (technician) => DropdownMenuItem(
                      value: technician,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            technician.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF183B56),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${technician.employeeId} • ${technician.email}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF526D82),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (context) => technicians
                  .map(
                    (technician) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${technician.name} (${technician.employeeId})',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF183B56),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selected = value),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Phân công'),
        ),
      ],
    );
  }
}

class RejectReasonDialog extends StatefulWidget {
  final String deviceName;

  const RejectReasonDialog({super.key, required this.deviceName});

  @override
  State<RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<RejectReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: const Text(
        'Từ chối yêu cầu',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.deviceName,
                style: const TextStyle(
                  color: Color(0xFF526D82),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _controller,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  color: Color(0xFF183B56),
                  fontSize: 16,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  labelText: 'Lý do từ chối',
                  hintText: 'Nhập lý do cụ thể để khách hàng biết...',
                  alignLabelWithHint: true,
                  labelStyle: const TextStyle(
                    color: Color(0xFF385A70),
                    fontWeight: FontWeight.w600,
                  ),
                  hintStyle: const TextStyle(
                    color: Color(0xFF78909C),
                    height: 1.4,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').trim().length < 5) {
                    return 'Vui lòng nhập ít nhất 5 ký tự';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.pop(context);
          },
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final reason = _controller.text.trim();
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.pop(context, reason);
          },
          icon: const Icon(Icons.close),
          label: const Text('Từ chối'),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final MaintenanceRequest request;
  final ValueChanged<MaintenanceRequest> onApproved;
  final ValueChanged<MaintenanceRequest> onRejected;
  final ValueChanged<MaintenanceRequest> onAssigned;

  const _ReviewCard({
    required this.request,
    required this.onApproved,
    required this.onRejected,
    required this.onAssigned,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = request.status == 'pending';
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.build_circle_outlined,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.deviceName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: const Color(0xFF183B56),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Số seri: ${request.serialNumber}',
                        style: const TextStyle(color: Color(0xFF526D82)),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: request.status),
              ],
            ),
            const SizedBox(height: 14),
            _InfoRow(icon: Icons.person_outline, label: request.requesterName),
            if (request.requesterPhone.isNotEmpty)
              _InfoRow(
                icon: Icons.phone_outlined,
                label: request.requesterPhone,
              ),
            _InfoRow(
              icon: Icons.priority_high,
              label: 'Mức ưu tiên: ${_priorityLabel(request.priority)}',
            ),
            const Divider(height: 24),
            const Text(
              'Mô tả sự cố',
              style: TextStyle(
                color: Color(0xFF183B56),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              request.description,
              style: const TextStyle(
                color: Color(0xFF385A70),
                fontSize: 15,
                height: 1.45,
              ),
            ),
            if (request.rejectionReason?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Lý do từ chối: ${request.rejectionReason}',
                  style: const TextStyle(color: Color(0xFFC62828)),
                ),
              ),
            ],
            if (request.technicianName?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.engineering_outlined,
                label: 'Kỹ thuật viên: ${request.technicianName}',
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => onRejected(request),
                      icon: const Icon(Icons.close),
                      label: const Text('Từ chối'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => onApproved(request),
                      icon: const Icon(Icons.check),
                      label: const Text('Xác nhận'),
                    ),
                  ),
                ],
              ),
            ] else if (request.status == 'approved') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => onAssigned(request),
                  icon: Icon(
                    request.technicianId == null
                        ? Icons.person_add_alt_1
                        : Icons.swap_horiz,
                  ),
                  label: Text(
                    request.technicianId == null
                        ? 'Phân công kỹ thuật viên'
                        : 'Đổi kỹ thuật viên',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF607D8B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF385A70)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, background, foreground) = switch (status) {
      'approved' => (
        'Đã duyệt',
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
      ),
      'rejected' => (
        'Từ chối',
        const Color(0xFFFFEBEE),
        const Color(0xFFC62828),
      ),
      'pending' => (
        'Chờ duyệt',
        const Color(0xFFFFF3E0),
        const Color(0xFFEF6C00),
      ),
      _ => (status, const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String filter;

  const _EmptyView({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 58,
              color: Color(0xFF90A4AE),
            ),
            const SizedBox(height: 12),
            Text(
              filter == 'pending'
                  ? 'Không có yêu cầu đang chờ duyệt'
                  : 'Không có dữ liệu phù hợp',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF526D82),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
