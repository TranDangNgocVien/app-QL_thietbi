class MaintenanceDevice {
  final String detailId;
  final String deviceName;
  final String serialNumber;
  final String condition;

  const MaintenanceDevice({
    required this.detailId,
    required this.deviceName,
    required this.serialNumber,
    required this.condition,
  });
}

class MaintenanceRequest {
  final String id;
  final String requesterName;
  final String requesterEmail;
  final String requesterPhone;
  final String deviceName;
  final String serialNumber;
  final String status;
  final String priority;
  final String description;
  final String? rejectionReason;
  final String? technicianId;
  final String? technicianName;
  final DateTime createdAt;

  const MaintenanceRequest({
    required this.id,
    this.requesterName = '',
    this.requesterEmail = '',
    this.requesterPhone = '',
    required this.deviceName,
    required this.serialNumber,
    required this.status,
    required this.priority,
    required this.description,
    required this.createdAt,
    this.rejectionReason,
    this.technicianId,
    this.technicianName,
  });
}

class TechnicianAccount {
  final String id;
  final String employeeId;
  final String name;
  final String email;
  final String phone;

  const TechnicianAccount({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.phone,
  });
}

class TechnicianJob {
  final String requestId;
  final String deviceDetailId;
  final String deviceName;
  final String serialNumber;
  final String customerName;
  final String priority;
  final String description;
  final String status;
  final String? taskId;
  final String? result;
  final String? notes;
  final double cost;
  final int progress;

  const TechnicianJob({
    required this.requestId,
    required this.deviceDetailId,
    required this.deviceName,
    required this.serialNumber,
    required this.customerName,
    required this.priority,
    required this.description,
    required this.status,
    required this.cost,
    required this.progress,
    this.taskId,
    this.result,
    this.notes,
  });
}
