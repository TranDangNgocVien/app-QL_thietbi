import 'package:flutter/material.dart';

import '../../core/constants/user_session.dart';
import '../../models/maintenance_request.dart';
import '../../services/maintenance_request_service.dart';

class TechnicianJobsScreen extends StatefulWidget {
  const TechnicianJobsScreen({super.key});

  @override
  State<TechnicianJobsScreen> createState() => _TechnicianJobsScreenState();
}

class _TechnicianJobsScreenState extends State<TechnicianJobsScreen> {
  late Future<List<TechnicianJob>> _jobsFuture;
  String _filter = 'active';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _jobsFuture = MaintenanceRequestService.instance.loadMyTechnicianJobs();
  }

  @override
  Widget build(BuildContext context) {
    if (!UserSession.isTechnician) {
      return const Scaffold(
        body: Center(child: Text('Chỉ kỹ thuật viên được xem công việc này.')),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        title: const Text(
          'Công việc sửa chữa',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<List<TechnicianJob>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Không thể tải công việc: ${snapshot.error}'),
            );
          }
          final allJobs = snapshot.data ?? const [];
          final jobs = _filter == 'completed'
              ? allJobs.where((job) => job.status == 'completed').toList()
              : allJobs.where((job) => job.status != 'completed').toList();
          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _jobsFuture;
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'active',
                          icon: Icon(Icons.build_outlined),
                          label: Text('Đang thực hiện'),
                        ),
                        ButtonSegment(
                          value: 'completed',
                          icon: Icon(Icons.check_circle_outline),
                          label: Text('Hoàn thành'),
                        ),
                      ],
                      selected: {_filter},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) {
                        setState(() => _filter = value.first);
                      },
                    ),
                  ),
                ),
                if (jobs.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Chưa có công việc phù hợp')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    sliver: SliverList.separated(
                      itemCount: jobs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _TechnicianJobCard(
                        job: jobs[index],
                        onStart: _startJob,
                        onComplete: _completeJob,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _startJob(TechnicianJob job) async {
    try {
      await MaintenanceRequestService.instance.startTechnicianJob(
        job.requestId,
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã bắt đầu sửa chữa thiết bị')),
      );
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    }
  }

  Future<void> _completeJob(TechnicianJob job) async {
    final result = await showDialog<TechnicianCompletionData>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TechnicianCompletionDialog(job: job),
    );
    if (result == null || !mounted) return;

    try {
      await MaintenanceRequestService.instance.completeTechnicianJob(
        requestId: job.requestId,
        result: result.result,
        notes: result.notes,
        cost: result.cost,
        deviceCondition: result.deviceCondition,
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xác nhận hoàn tất sửa chữa')),
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

class TechnicianCompletionData {
  final String result;
  final String notes;
  final double cost;
  final String deviceCondition;

  const TechnicianCompletionData({
    required this.result,
    required this.notes,
    required this.cost,
    required this.deviceCondition,
  });
}

class TechnicianCompletionDialog extends StatefulWidget {
  final TechnicianJob job;

  const TechnicianCompletionDialog({super.key, required this.job});

  @override
  State<TechnicianCompletionDialog> createState() =>
      _TechnicianCompletionDialogState();
}

class _TechnicianCompletionDialogState
    extends State<TechnicianCompletionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _resultController = TextEditingController();
  final _notesController = TextEditingController();
  final _costController = TextEditingController(text: '0');
  String _condition = 'Tốt';

  @override
  void dispose() {
    _resultController.dispose();
    _notesController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      title: const Text(
        'Xác nhận kết quả sửa chữa',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.job.deviceName} - ${widget.job.serialNumber}',
                  style: const TextStyle(
                    color: Color(0xFF183B56),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _condition,
                  decoration: _inputDecoration('Tình trạng sau sửa'),
                  items: const [
                    DropdownMenuItem(value: 'Tốt', child: Text('Tốt')),
                    DropdownMenuItem(
                      value: 'Bình thường',
                      child: Text('Bình thường'),
                    ),
                    DropdownMenuItem(value: 'Cũ', child: Text('Cũ')),
                    DropdownMenuItem(
                      value: 'Hỏng nặng',
                      child: Text('Hỏng nặng'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) _condition = value;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _resultController,
                  minLines: 3,
                  maxLines: 5,
                  style: const TextStyle(color: Color(0xFF183B56)),
                  decoration: _inputDecoration(
                    'Kết quả xử lý',
                    hint: 'Ví dụ: Đã thay nguồn, thiết bị hoạt động ổn định...',
                  ),
                  validator: (value) => (value ?? '').trim().length < 5
                      ? 'Vui lòng nhập ít nhất 5 ký tự'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(color: Color(0xFF183B56)),
                  decoration: _inputDecoration(
                    'Ghi chú',
                    hint: 'Phụ tùng đã thay, lưu ý khi sử dụng...',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _costController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Color(0xFF183B56)),
                  decoration: _inputDecoration('Chi phí sửa chữa'),
                  validator: (value) {
                    final cost = double.tryParse((value ?? '').trim());
                    if (cost == null || cost < 0) {
                      return 'Chi phí không hợp lệ';
                    }
                    return null;
                  },
                ),
              ],
            ),
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
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final data = TechnicianCompletionData(
              result: _resultController.text.trim(),
              notes: _notesController.text.trim(),
              cost: double.parse(_costController.text.trim()),
              deviceCondition: _condition,
            );
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.pop(context, data);
          },
          icon: const Icon(Icons.check),
          label: const Text('Hoàn tất'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: hint != null,
      labelStyle: const TextStyle(
        color: Color(0xFF385A70),
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: Color(0xFF78909C)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _TechnicianJobCard extends StatelessWidget {
  final TechnicianJob job;
  final ValueChanged<TechnicianJob> onStart;
  final ValueChanged<TechnicianJob> onComplete;

  const _TechnicianJobCard({
    required this.job,
    required this.onStart,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final completed = job.status == 'completed';
    final inProgress = job.status == 'in_progress';
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.engineering, color: Color(0xFF1976D2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.deviceName,
                        style: const TextStyle(
                          color: Color(0xFF183B56),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Seri: ${job.serialNumber}',
                        style: const TextStyle(color: Color(0xFF526D82)),
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(_statusLabel(job.status))),
              ],
            ),
            const SizedBox(height: 12),
            Text('Khách hàng: ${job.customerName}'),
            Text('Mức ưu tiên: ${_priorityLabel(job.priority)}'),
            const Divider(height: 24),
            Text(
              job.description,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            if (completed && job.result?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                'Kết quả: ${job.result}',
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text('Chi phí: ${job.cost.toStringAsFixed(0)}đ'),
            ],
            if (!completed) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => inProgress ? onComplete(job) : onStart(job),
                  icon: Icon(inProgress ? Icons.task_alt : Icons.play_arrow),
                  label: Text(
                    inProgress ? 'Xác nhận sửa xong' : 'Bắt đầu sửa chữa',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Đã phân công';
      case 'in_progress':
        return 'Đang sửa';
      case 'completed':
        return 'Hoàn thành';
      default:
        return status;
    }
  }

  String _priorityLabel(String priority) {
    const labels = {
      'low': 'Thấp',
      'medium': 'Trung bình',
      'high': 'Cao',
      'critical': 'Khẩn cấp',
    };
    return labels[priority] ?? priority;
  }
}
