import 'package:sqflite/sqflite.dart';

import '../core/constants/user_session.dart';
import '../models/maintenance_request.dart';
import 'app_database.dart';

class MaintenanceRequestService {
  MaintenanceRequestService._();

  static final MaintenanceRequestService instance =
      MaintenanceRequestService._();

  Future<List<MaintenanceDevice>> loadEligibleDevices() async {
    final account = await _requireCustomerAccount();
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT DISTINCT ct.MaTBCT, tb.TenTB, ct.SoSeri, ct.TinhTrang
      FROM PhieuMuon pm
      JOIN ChiTietPM detail ON detail.MaPM = pm.MaPM
      JOIN ThietBiChiTiet ct ON ct.MaTBCT = detail.MaTBCT
      JOIN ThietBi tb ON tb.MaTB = ct.MaTB
      WHERE pm.MaKH = ?
      ORDER BY tb.TenTB, ct.SoSeri
      ''',
      [account.customerId],
    );
    return rows
        .map(
          (row) => MaintenanceDevice(
            detailId: row['MaTBCT'] as String,
            deviceName: row['TenTB'] as String,
            serialNumber: row['SoSeri'] as String,
            condition: row['TinhTrang'] as String,
          ),
        )
        .toList();
  }

  Future<List<MaintenanceRequest>> loadMyRequests() async {
    final account = await _requireCustomerAccount();
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT request.Id, request.Status, request.Priority,
             request.Description, request.RejectionReason, request.CreatedAt,
             tb.TenTB, ct.SoSeri
      FROM AppMaintenanceRequests request
      JOIN ThietBiChiTiet ct ON ct.MaTBCT = request.DeviceId
      JOIN ThietBi tb ON tb.MaTB = ct.MaTB
      WHERE request.RequesterId = ?
      ORDER BY request.CreatedAt DESC, request.Id DESC
      ''',
      [account.userId],
    );
    return rows
        .map(
          (row) => MaintenanceRequest(
            id: row['Id'] as String,
            deviceName: row['TenTB'] as String,
            serialNumber: row['SoSeri'] as String,
            status: row['Status'] as String,
            priority: row['Priority'] as String,
            description: row['Description'] as String,
            rejectionReason: row['RejectionReason'] as String?,
            createdAt: DateTime.parse(row['CreatedAt'] as String),
          ),
        )
        .toList();
  }

  Future<List<MaintenanceRequest>> loadRequestsForReview() async {
    await _requireReviewer();
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT request.Id, request.Status, request.Priority,
             request.Description, request.RejectionReason, request.CreatedAt,
             tb.TenTB, ct.SoSeri, customer.FullName, customer.Email,
             customer.Phone, request.TechnicianId,
             technician.FullName AS TechnicianName
      FROM AppMaintenanceRequests request
      JOIN AppUsers customer ON customer.Id = request.RequesterId
      JOIN ThietBiChiTiet ct ON ct.MaTBCT = request.DeviceId
      JOIN ThietBi tb ON tb.MaTB = ct.MaTB
      LEFT JOIN AppUsers technician ON technician.Id = request.TechnicianId
      ORDER BY
        CASE request.Status WHEN 'pending' THEN 0 ELSE 1 END,
        request.CreatedAt DESC
      ''');
    return rows
        .map(
          (row) => MaintenanceRequest(
            id: row['Id'] as String,
            requesterName: row['FullName'] as String,
            requesterEmail: row['Email'] as String? ?? '',
            requesterPhone: row['Phone'] as String? ?? '',
            deviceName: row['TenTB'] as String,
            serialNumber: row['SoSeri'] as String,
            status: row['Status'] as String,
            priority: row['Priority'] as String,
            description: row['Description'] as String,
            rejectionReason: row['RejectionReason'] as String?,
            technicianId: row['TechnicianId'] as String?,
            technicianName: row['TechnicianName'] as String?,
            createdAt: DateTime.parse(row['CreatedAt'] as String),
          ),
        )
        .toList();
  }

  Future<List<TechnicianAccount>> loadTechnicians() async {
    await _requireReviewer();
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT app.Id, employee.MaNV,
             employee.TenNV AS TechnicianName,
             COALESCE(app.Email, employee.Email) AS Email,
             COALESCE(app.Phone, employee.SDT) AS Phone
      FROM AppUsers app
      JOIN NhanVien employee ON employee.MaNV = app.MaNV
      WHERE app.RoleId = 'technician'
        AND app.IsActive = 1
        AND employee.TrangThai = 'Đang làm việc'
      ORDER BY employee.TenNV
      ''');
    return rows
        .map(
          (row) => TechnicianAccount(
            id: row['Id'] as String,
            employeeId: row['MaNV'] as String,
            name: row['TechnicianName'] as String,
            email: row['Email'] as String? ?? '',
            phone: row['Phone'] as String? ?? '',
          ),
        )
        .toList();
  }

  Future<void> assignTechnician({
    required String requestId,
    required String technicianId,
  }) async {
    final reviewer = await _requireReviewer();
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    await db.transaction((transaction) async {
      final technicianRows = await transaction.rawQuery(
        '''
        SELECT app.Id, employee.TenNV
        FROM AppUsers app
        JOIN NhanVien employee ON employee.MaNV = app.MaNV
        WHERE app.Id = ?
          AND app.RoleId = 'technician'
          AND app.IsActive = 1
          AND employee.TrangThai = 'Đang làm việc'
        LIMIT 1
        ''',
        [technicianId],
      );
      if (technicianRows.isEmpty) {
        throw StateError('Kỹ thuật viên không hợp lệ hoặc đã ngừng hoạt động');
      }

      final requestRows = await transaction.query(
        'AppMaintenanceRequests',
        columns: ['Status', 'Description'],
        where: 'Id = ?',
        whereArgs: [requestId],
        limit: 1,
      );
      if (requestRows.isEmpty) {
        throw StateError('Không tìm thấy yêu cầu bảo trì');
      }
      final status = requestRows.first['Status'] as String;
      if (status != 'approved') {
        throw StateError('Chỉ yêu cầu đã duyệt mới được phân công');
      }

      await transaction.update(
        'AppMaintenanceRequests',
        {'TechnicianId': technicianId, 'UpdatedAt': now.toIso8601String()},
        where: 'Id = ? AND Status = ?',
        whereArgs: [requestId, 'approved'],
      );

      final existingTasks = await transaction.query(
        'AppMaintenanceTasks',
        columns: ['Id'],
        where: 'RequestId = ?',
        whereArgs: [requestId],
        limit: 1,
      );
      if (existingTasks.isEmpty) {
        await transaction.insert('AppMaintenanceTasks', {
          'Id': 'TASK-${now.microsecondsSinceEpoch}',
          'RequestId': requestId,
          'Status': 'pending',
          'Description': requestRows.first['Description'],
          'TechnicianId': technicianId,
          'Progress': 0,
          'CreatedAt': now.toIso8601String(),
          'UpdatedAt': now.toIso8601String(),
        });
      } else {
        await transaction.update(
          'AppMaintenanceTasks',
          {
            'TechnicianId': technicianId,
            'Status': 'pending',
            'Progress': 0,
            'UpdatedAt': now.toIso8601String(),
          },
          where: 'RequestId = ?',
          whereArgs: [requestId],
        );
      }

      await transaction.insert('AppStatusHistory', {
        'Id': 'HIS-${now.microsecondsSinceEpoch}',
        'RequestId': requestId,
        'PreviousStatus': 'approved',
        'NewStatus': 'approved',
        'ChangedBy': reviewer.appUserId,
        'Reason': 'Phân công cho ${technicianRows.first['TenNV'] as String}',
        'CreatedAt': now.toIso8601String(),
      });
      await transaction.insert('AppNotifications', {
        'Id': 'NOT-${now.microsecondsSinceEpoch}',
        'UserId': technicianId,
        'Title': 'Bạn được phân công sửa chữa thiết bị',
        'Message': 'Vui lòng kiểm tra công việc bảo trì mới được giao.',
        'RequestId': requestId,
        'Type': 'maintenance_assignment',
        'IsRead': 0,
        'CreatedAt': now.toIso8601String(),
      });
    });
  }

  Future<List<TechnicianJob>> loadMyTechnicianJobs() async {
    final technician = await _requireTechnician();
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT request.Id, request.DeviceId, request.Status, request.Priority,
             request.Description, tb.TenTB, ct.SoSeri, customer.FullName,
             task.Id AS TaskId, task.Result, task.Notes,
             COALESCE(task.Cost, 0) AS Cost,
             COALESCE(task.Progress, 0) AS Progress
      FROM AppMaintenanceRequests request
      JOIN AppUsers customer ON customer.Id = request.RequesterId
      JOIN ThietBiChiTiet ct ON ct.MaTBCT = request.DeviceId
      JOIN ThietBi tb ON tb.MaTB = ct.MaTB
      LEFT JOIN AppMaintenanceTasks task
        ON task.RequestId = request.Id
       AND task.TechnicianId = request.TechnicianId
      WHERE request.TechnicianId = ?
        AND request.Status IN ('approved', 'in_progress', 'completed')
      ORDER BY
        CASE request.Status
          WHEN 'in_progress' THEN 0
          WHEN 'approved' THEN 1
          ELSE 2
        END,
        request.UpdatedAt DESC
      ''',
      [technician.appUserId],
    );
    return rows
        .map(
          (row) => TechnicianJob(
            requestId: row['Id'] as String,
            deviceDetailId: row['DeviceId'] as String,
            deviceName: row['TenTB'] as String,
            serialNumber: row['SoSeri'] as String,
            customerName: row['FullName'] as String,
            priority: row['Priority'] as String,
            description: row['Description'] as String,
            status: row['Status'] as String,
            taskId: row['TaskId'] as String?,
            result: row['Result'] as String?,
            notes: row['Notes'] as String?,
            cost: (row['Cost'] as num).toDouble(),
            progress: (row['Progress'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<void> startTechnicianJob(String requestId) async {
    final technician = await _requireTechnician();
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    await db.transaction((transaction) async {
      final updated = await transaction.update(
        'AppMaintenanceRequests',
        {'Status': 'in_progress', 'UpdatedAt': now.toIso8601String()},
        where: "Id = ? AND TechnicianId = ? AND Status = 'approved'",
        whereArgs: [requestId, technician.appUserId],
      );
      if (updated != 1) {
        throw StateError('Công việc không hợp lệ hoặc đã được bắt đầu');
      }
      await transaction.update(
        'AppMaintenanceTasks',
        {
          'Status': 'in_progress',
          'Progress': 20,
          'UpdatedAt': now.toIso8601String(),
        },
        where: 'RequestId = ? AND TechnicianId = ?',
        whereArgs: [requestId, technician.appUserId],
      );
      await transaction.rawUpdate(
        '''
        UPDATE ThietBiChiTiet
        SET TrangThai = 'Đang bảo trì'
        WHERE MaTBCT = (
          SELECT DeviceId FROM AppMaintenanceRequests WHERE Id = ?
        )
        ''',
        [requestId],
      );
      await _insertHistory(
        transaction,
        requestId: requestId,
        previousStatus: 'approved',
        newStatus: 'in_progress',
        changedBy: technician.appUserId,
        reason: 'Kỹ thuật viên bắt đầu sửa chữa',
        now: now,
      );
    });
  }

  Future<void> completeTechnicianJob({
    required String requestId,
    required String result,
    required String notes,
    required double cost,
    required String deviceCondition,
  }) async {
    final technician = await _requireTechnician();
    final cleanResult = result.trim();
    if (cleanResult.length < 5) {
      throw ArgumentError('Kết quả sửa chữa phải có ít nhất 5 ký tự');
    }
    if (cost < 0) throw ArgumentError('Chi phí không được âm');
    const conditions = {'Tốt', 'Bình thường', 'Cũ', 'Hỏng nặng'};
    if (!conditions.contains(deviceCondition)) {
      throw ArgumentError('Tình trạng thiết bị không hợp lệ');
    }

    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    await db.transaction((transaction) async {
      final requestRows = await transaction.query(
        'AppMaintenanceRequests',
        columns: ['DeviceId', 'RequesterId'],
        where: "Id = ? AND TechnicianId = ? AND Status = 'in_progress'",
        whereArgs: [requestId, technician.appUserId],
        limit: 1,
      );
      if (requestRows.isEmpty) {
        throw StateError(
          'Công việc chưa bắt đầu hoặc không thuộc kỹ thuật viên',
        );
      }
      final deviceId = requestRows.first['DeviceId'] as String;
      final requesterId = requestRows.first['RequesterId'] as String;

      await transaction.update(
        'AppMaintenanceRequests',
        {
          'Status': 'completed',
          'CompletionDate': now.toIso8601String(),
          'UpdatedAt': now.toIso8601String(),
        },
        where: 'Id = ?',
        whereArgs: [requestId],
      );
      await transaction.update(
        'AppMaintenanceTasks',
        {
          'Status': 'completed',
          'Result': cleanResult,
          'Notes': notes.trim().isEmpty ? null : notes.trim(),
          'Cost': cost,
          'CompletionDate': now.toIso8601String(),
          'Progress': 100,
          'UpdatedAt': now.toIso8601String(),
        },
        where: 'RequestId = ? AND TechnicianId = ?',
        whereArgs: [requestId, technician.appUserId],
      );
      await transaction.update(
        'ThietBiChiTiet',
        {
          'TinhTrang': deviceCondition,
          'TrangThai': deviceCondition == 'Hỏng nặng' ? 'Hỏng' : 'Có sẵn',
          'GhiChu': cleanResult,
        },
        where: 'MaTBCT = ?',
        whereArgs: [deviceId],
      );

      final technicianUser = await transaction.query(
        'AppUsers',
        columns: ['MaNV'],
        where: 'Id = ?',
        whereArgs: [technician.appUserId],
        limit: 1,
      );
      final customerUser = await transaction.query(
        'AppUsers',
        columns: ['MaKH'],
        where: 'Id = ?',
        whereArgs: [requesterId],
        limit: 1,
      );
      await transaction.insert('BaoTri', {
        'MaBT': 'BT-${now.microsecondsSinceEpoch}',
        'NgayYeuCau': now.toIso8601String(),
        'MoTaSuCo': notes.trim().isEmpty ? cleanResult : notes.trim(),
        'MucDoHuHong': _conditionToDamageLevel(deviceCondition),
        'TrangThai': 'Hoàn thành',
        'KetQuaXuLy': cleanResult,
        'MaTBCT': deviceId,
        'MaKH': customerUser.first['MaKH'],
        'MaNV': technicianUser.first['MaNV'],
        'NgayHoanThanh': now.toIso8601String(),
        'ChiPhi': cost,
      });
      await _insertHistory(
        transaction,
        requestId: requestId,
        previousStatus: 'in_progress',
        newStatus: 'completed',
        changedBy: technician.appUserId,
        reason: cleanResult,
        now: now,
      );
      await transaction.insert('AppNotifications', {
        'Id': 'NOT-${now.microsecondsSinceEpoch}',
        'UserId': requesterId,
        'Title': 'Thiết bị đã sửa chữa xong',
        'Message': cleanResult,
        'RequestId': requestId,
        'Type': 'maintenance_completed',
        'IsRead': 0,
        'CreatedAt': now.toIso8601String(),
      });
    });
  }

  String _conditionToDamageLevel(String condition) {
    switch (condition) {
      case 'Hỏng nặng':
        return 'Rất nặng';
      case 'Cũ':
        return 'Nặng';
      case 'Bình thường':
        return 'Trung bình';
      default:
        return 'Nhẹ';
    }
  }

  Future<void> _insertHistory(
    DatabaseExecutor transaction, {
    required String requestId,
    required String previousStatus,
    required String newStatus,
    required String changedBy,
    required String reason,
    required DateTime now,
  }) async {
    await transaction.insert('AppStatusHistory', {
      'Id': 'HIS-${now.microsecondsSinceEpoch}',
      'RequestId': requestId,
      'PreviousStatus': previousStatus,
      'NewStatus': newStatus,
      'ChangedBy': changedBy,
      'Reason': reason,
      'CreatedAt': now.toIso8601String(),
    });
  }

  Future<void> approveRequest(String requestId) async {
    await _reviewRequest(
      requestId: requestId,
      newStatus: 'approved',
      reason: 'Yêu cầu bảo trì đã được xác nhận',
    );
  }

  Future<void> rejectRequest({
    required String requestId,
    required String reason,
  }) async {
    final cleanReason = reason.trim();
    if (cleanReason.length < 5) {
      throw ArgumentError('Lý do từ chối phải có ít nhất 5 ký tự');
    }
    await _reviewRequest(
      requestId: requestId,
      newStatus: 'rejected',
      reason: cleanReason,
    );
  }

  Future<void> _reviewRequest({
    required String requestId,
    required String newStatus,
    required String reason,
  }) async {
    final reviewer = await _requireReviewer();
    final db = await AppDatabase.instance.database;
    final now = DateTime.now();
    await db.transaction((transaction) async {
      final currentRows = await transaction.query(
        'AppMaintenanceRequests',
        columns: ['Status', 'RequesterId'],
        where: 'Id = ?',
        whereArgs: [requestId],
        limit: 1,
      );
      if (currentRows.isEmpty) {
        throw StateError('Không tìm thấy yêu cầu bảo trì');
      }
      final currentStatus = currentRows.first['Status'] as String;
      final requesterId = currentRows.first['RequesterId'] as String;
      if (currentStatus != 'pending') {
        throw StateError('Yêu cầu này đã được xử lý trước đó');
      }

      final updated = await transaction.update(
        'AppMaintenanceRequests',
        {
          'Status': newStatus,
          'ApproverId': reviewer.appUserId,
          'RejectionReason': newStatus == 'rejected' ? reason : null,
          'UpdatedAt': now.toIso8601String(),
        },
        where: 'Id = ? AND Status = ?',
        whereArgs: [requestId, 'pending'],
      );
      if (updated != 1) {
        throw StateError('Yêu cầu vừa được người khác xử lý');
      }
      await transaction.insert('AppStatusHistory', {
        'Id': 'HIS-${now.microsecondsSinceEpoch}',
        'RequestId': requestId,
        'PreviousStatus': currentStatus,
        'NewStatus': newStatus,
        'ChangedBy': reviewer.appUserId,
        'Reason': reason,
        'CreatedAt': now.toIso8601String(),
      });
      await transaction.insert('AppNotifications', {
        'Id': 'NOT-${now.microsecondsSinceEpoch}',
        'UserId': requesterId,
        'Title': newStatus == 'approved'
            ? 'Yêu cầu bảo trì đã được xác nhận'
            : 'Yêu cầu bảo trì bị từ chối',
        'Message': reason,
        'RequestId': requestId,
        'Type': 'maintenance_review',
        'IsRead': 0,
        'CreatedAt': now.toIso8601String(),
      });
    });
  }

  Future<void> createRequest({
    required String deviceDetailId,
    required String priority,
    required String description,
  }) async {
    final account = await _requireCustomerAccount();
    final db = await AppDatabase.instance.database;
    final allowedDevice = await db.rawQuery(
      '''
      SELECT 1
      FROM PhieuMuon pm
      JOIN ChiTietPM detail ON detail.MaPM = pm.MaPM
      WHERE pm.MaKH = ? AND detail.MaTBCT = ?
      LIMIT 1
      ''',
      [account.customerId, deviceDetailId],
    );
    if (allowedDevice.isEmpty) {
      throw StateError(
        'Khách hàng chỉ được yêu cầu bảo trì thiết bị đã từng thuê',
      );
    }

    const priorities = {'low', 'medium', 'high', 'critical'};
    if (!priorities.contains(priority)) {
      throw ArgumentError.value(
        priority,
        'priority',
        'Mức ưu tiên không hợp lệ',
      );
    }
    final cleanDescription = description.trim();
    if (cleanDescription.length < 10) {
      throw ArgumentError('Mô tả sự cố phải có ít nhất 10 ký tự');
    }

    final now = DateTime.now();
    final id = 'MR-${now.microsecondsSinceEpoch}';
    await db.transaction((transaction) async {
      final requester = await transaction.rawQuery(
        '''
        SELECT 1 FROM AppUsers
        WHERE Id = ? AND RoleId = 'requester' AND IsActive = 1 AND MaKH = ?
        LIMIT 1
        ''',
        [account.userId, account.customerId],
      );
      if (requester.isEmpty) {
        throw StateError('Tài khoản không có quyền tạo yêu cầu bảo trì');
      }

      await transaction.insert('AppMaintenanceRequests', {
        'Id': id,
        'DeviceId': deviceDetailId,
        'RequesterId': account.userId,
        'Status': 'pending',
        'Priority': priority,
        'Description': cleanDescription,
        'CreatedAt': now.toIso8601String(),
        'UpdatedAt': now.toIso8601String(),
      });
      await transaction.insert('AppStatusHistory', {
        'Id': 'HIS-${now.microsecondsSinceEpoch}',
        'RequestId': id,
        'PreviousStatus': 'new',
        'NewStatus': 'pending',
        'ChangedBy': account.userId,
        'Reason': 'Khách hàng tạo yêu cầu bảo trì',
        'CreatedAt': now.toIso8601String(),
      });
    });
  }

  Future<_CustomerAccount> _requireCustomerAccount() async {
    if (!UserSession.isLoggedIn ||
        !UserSession.isCustomer ||
        UserSession.userId.isEmpty ||
        UserSession.customerId.isEmpty) {
      throw StateError('Chỉ khách hàng mới được sử dụng chức năng này');
    }
    return _CustomerAccount(
      userId: UserSession.userId,
      customerId: UserSession.customerId,
    );
  }

  Future<_ReviewerAccount> _requireReviewer() async {
    if (!UserSession.isLoggedIn ||
        UserSession.isCustomer ||
        (!UserSession.isManager && UserSession.role != 'Nhân viên') ||
        UserSession.userId.isEmpty) {
      throw StateError('Chỉ nhân viên hoặc quản lý mới được xử lý yêu cầu');
    }

    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'AppUsers',
      columns: ['Id'],
      where: 'MaNV = ? AND IsActive = 1',
      whereArgs: [UserSession.userId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return _ReviewerAccount(appUserId: rows.first['Id'] as String);
    }

    final appUserId = 'USR-EMP-${UserSession.userId}';
    await db.insert('AppUsers', {
      'Id': appUserId,
      'FullName': UserSession.displayName,
      'RoleId': UserSession.isManager ? 'unit_manager' : 'company_staff',
      'UnitId': 'UNIT01',
      'PasswordSalt': appUserId,
      'PasswordHash': 'SESSION_ONLY',
      'IsActive': 1,
      'MaNV': UserSession.userId,
    });
    return _ReviewerAccount(appUserId: appUserId);
  }

  Future<_ReviewerAccount> _requireTechnician() async {
    if (!UserSession.isLoggedIn ||
        !UserSession.isTechnician ||
        UserSession.userId.isEmpty) {
      throw StateError('Chỉ kỹ thuật viên mới được cập nhật sửa chữa');
    }
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'AppUsers',
      columns: ['Id'],
      where: "MaNV = ? AND RoleId = 'technician' AND IsActive = 1",
      whereArgs: [UserSession.userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Không tìm thấy tài khoản kỹ thuật viên');
    }
    return _ReviewerAccount(appUserId: rows.first['Id'] as String);
  }
}

class _CustomerAccount {
  final String userId;
  final String customerId;

  const _CustomerAccount({required this.userId, required this.customerId});
}

class _ReviewerAccount {
  final String appUserId;

  const _ReviewerAccount({required this.appUserId});
}
