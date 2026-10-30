import 'package:sqflite/sqflite.dart';

import '../data/dummy_data.dart' as dummy;
import '../core/app_data_refresh.dart';
import '../core/constants/user_session.dart';
import '../models/customer.dart';
import '../models/device.dart';
import '../models/rental_order.dart';
import 'app_database.dart';
import 'customer_storage_service.dart';
import 'device_storage_service.dart';

class OrderService {
  static final OrderService _instance = OrderService._internal();
  final List<RentalOrder> _orders = [];

  factory OrderService() => _instance;

  OrderService._internal();

  List<RentalOrder> get orders => _orders;

  Future<void> loadOrders({required List<RentalOrder> fallback}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT pm.MaPM, pm.NgayMuon, pm.NgayTraDuKien, pm.TongTien,
             pm.TrangThai, kh.HoTen, kh.SDT, kh.Email, kh.DiaChi,
             COUNT(detail.MaCTPM) AS SoLuong,
             COALESCE(MIN(tb.TenTB), 'Thiết bị') AS TenTB
      FROM PhieuMuon pm
      JOIN KhachHang kh ON kh.MaKH = pm.MaKH
      LEFT JOIN ChiTietPM detail ON detail.MaPM = pm.MaPM
      LEFT JOIN ThietBiChiTiet ct ON ct.MaTBCT = detail.MaTBCT
      LEFT JOIN ThietBi tb ON tb.MaTB = ct.MaTB
      GROUP BY pm.MaPM, pm.NgayMuon, pm.NgayTraDuKien, pm.TongTien,
               pm.TrangThai, kh.HoTen, kh.SDT, kh.Email, kh.DiaChi
      ORDER BY pm.NgayMuon DESC, pm.MaPM DESC
    ''');
    if (rows.isNotEmpty) {
      _orders
        ..clear()
        ..addAll(rows.map(_orderFromRow));
      return;
    }

    _orders
      ..clear()
      ..addAll(fallback.isNotEmpty ? fallback : dummy.rentalOrders);
  }

  Future<List<Customer>> loadRentalCustomers() async {
    return CustomerStorageService.instance.loadCustomers();
  }

  Future<List<Device>> loadAvailableDevices() async {
    final db = await AppDatabase.instance.database;
    final devices = await DeviceStorageService.instance.loadDevices(
      fallback: dummy.devices,
    );
    final rows = await db.rawQuery('''
      SELECT MaTB, COUNT(*) AS AvailableDetails
      FROM ThietBiChiTiet
      WHERE TrangThai = 'Có sẵn'
      GROUP BY MaTB
      ''');
    if (rows.isEmpty) {
      return devices.where((device) => device.quantityAvailable > 0).toList();
    }

    final availableByDevice = {
      for (final row in rows)
        row['MaTB'] as String: (row['AvailableDetails'] as num).toInt(),
    };
    return devices
        .where((device) => (availableByDevice[device.id] ?? 0) > 0)
        .map(
          (device) =>
              device.copyWith(quantityAvailable: availableByDevice[device.id]),
        )
        .toList();
  }

  Future<List<Device>> loadDevices() async {
    return DeviceStorageService.instance.loadDevices(fallback: dummy.devices);
  }

  String generateNextBorrowTicketId() {
    final ids = <String>[
      ..._orders.map((order) => order.id),
      ...dummy.rentalOrders.map((order) => order.id),
    ];
    final maxNumber = ids.fold<int>(0, (maxValue, id) {
      final match = RegExp(r'^PM(\d+)$').firstMatch(id);
      if (match == null) return maxValue;
      final number = int.tryParse(match.group(1) ?? '') ?? 0;
      return number > maxValue ? number : maxValue;
    });
    return 'PM${(maxNumber + 1).toString().padLeft(3, '0')}';
  }

  Future<RentalOrder> createRentalOrder({
    required Customer customer,
    required Device device,
    required int quantity,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await AppDatabase.instance.database;
    final days = _rentalDayCount(startDate, endDate);
    final orderId = await _generateNextBorrowTicketIdFromDatabase();
    final totalPrice = days * device.pricePerDay * quantity;
    final employeeId = await _resolveEmployeeId();

    await db.transaction((transaction) async {
      final availableDetails = await transaction.query(
        'ThietBiChiTiet',
        columns: ['MaTBCT'],
        where: "MaTB = ? AND TrangThai = 'Có sẵn'",
        whereArgs: [device.id],
        orderBy: 'MaTBCT',
        limit: quantity,
      );
      if (availableDetails.length < quantity) {
        throw StateError('Thiết bị đã chọn không còn đủ số lượng khả dụng');
      }

      await transaction.insert('PhieuMuon', {
        'MaPM': orderId,
        'NgayMuon': _dateOnly(startDate),
        'NgayTraDuKien': _dateOnly(endDate),
        'TongTien': totalPrice,
        'TrangThai': 'Đang mượn',
        'MaKH': customer.id,
        'MaNV': employeeId,
        'GhiChu': 'Tạo từ màn nhân viên',
      });

      for (var index = 0; index < availableDetails.length; index++) {
        final detailId = availableDetails[index]['MaTBCT'] as String;
        await transaction.insert('ChiTietPM', {
          'MaCTPM': '$orderId-${(index + 1).toString().padLeft(2, '0')}',
          'MaPM': orderId,
          'MaTBCT': detailId,
          'SoLuong': 1,
          'DonGiaTaiThoiDiem': device.pricePerDay,
          'TinhTrangKhiGiao': 'Tốt, bàn giao từ kho',
          'PhiBoiThuong': 0,
        });
        await transaction.update(
          'ThietBiChiTiet',
          {'TrangThai': 'Đang mượn'},
          where: 'MaTBCT = ?',
          whereArgs: [detailId],
        );
      }

      await transaction.rawUpdate(
        '''
        UPDATE ThietBi
        SET SoLuongKhaDung = MAX(SoLuongKhaDung - ?, 0),
            TrangThai = CASE
              WHEN MAX(SoLuongKhaDung - ?, 0) = 0 THEN 'Ngừng cho thuê'
              ELSE 'Đang kinh doanh'
            END
        WHERE MaTB = ?
        ''',
        [quantity, quantity, device.id],
      );
    });

    final order = RentalOrder(
      id: orderId,
      customerName: customer.name,
      customerPhone: customer.phone,
      customerEmail: customer.email,
      customerAddress: customer.address,
      deviceName: device.name,
      quantity: quantity,
      startDate: startDate,
      endDate: endDate,
      totalPrice: totalPrice,
      status: 'Đang thuê',
    );
    _orders.add(order);
    AppDataRefresh.notifyChanged();
    return order;
  }

  Future<RentalOrder> createOrderForCustomer({
    required String customerId,
    required String deviceId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final customers = await CustomerStorageService.instance.loadCustomers();
    final customer = customers.firstWhere(
      (item) => item.id == customerId,
      orElse: () => throw StateError('Không tìm thấy khách hàng đã chọn'),
    );
    final device = dummy.devices.firstWhere(
      (item) => item.id == deviceId && item.quantityAvailable > 0,
      orElse: () => throw StateError('Thiết bị đã chọn không còn khả dụng'),
    );
    final days = _rentalDayCount(startDate, endDate);
    final order = RentalOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerName: customer.name,
      customerPhone: customer.phone,
      customerEmail: customer.email,
      customerAddress: customer.address,
      deviceName: device.name,
      quantity: 1,
      startDate: startDate,
      endDate: endDate,
      totalPrice: days * device.pricePerDay,
      status: 'Đang thuê',
    );
    addOrder(order);
    _decreaseDeviceAvailability(device.id, 1);
    return order;
  }

  void addOrder(RentalOrder order) {
    _orders.add(order);
    if (!dummy.rentalOrders.any((item) => item.id == order.id)) {
      dummy.rentalOrders.add(order);
    }
    AppDataRefresh.notifyChanged();
  }

  Future<void> updateOrder(String id, RentalOrder updatedOrder) async {
    final db = await AppDatabase.instance.database;
    final updated = await db.transaction((transaction) async {
      final currentRows = await transaction.query(
        'PhieuMuon',
        columns: ['MaKH'],
        where: 'MaPM = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (currentRows.isEmpty) return 0;

      final updatedCount = await transaction.update(
        'PhieuMuon',
        {
          'TongTien': updatedOrder.totalPrice,
          'TrangThai': _toDatabaseStatus(updatedOrder.status),
        },
        where: 'MaPM = ?',
        whereArgs: [id],
      );
      await transaction.update(
        'KhachHang',
        {'HoTen': updatedOrder.customerName},
        where: 'MaKH = ?',
        whereArgs: [currentRows.first['MaKH']],
      );
      await _syncOrderDetails(transaction, updatedOrder);
      return updatedCount;
    });
    if (updated == 0 && dummy.rentalOrders.any((item) => item.id == id)) {
      // Keep the in-memory fallback useful when the database has no matching row.
    }

    final index = _orders.indexWhere((item) => item.id == id);
    if (index != -1) _orders[index] = updatedOrder;

    final dummyIndex = dummy.rentalOrders.indexWhere((item) => item.id == id);
    if (dummyIndex != -1) dummy.rentalOrders[dummyIndex] = updatedOrder;
    AppDataRefresh.notifyChanged();
  }

  Future<RentalOrder> completeReturn({
    required RentalOrder order,
    required DateTime actualReturnDate,
    required String deviceCondition,
    required double lateFee,
    required double damageFee,
  }) async {
    final db = await AppDatabase.instance.database;
    final detailStatus = _returnDetailStatus(deviceCondition);
    final newTotal = order.totalPrice + lateFee + damageFee;

    await db.transaction((transaction) async {
      final orderRows = await transaction.query(
        'PhieuMuon',
        columns: ['MaPM'],
        where: 'MaPM = ?',
        whereArgs: [order.id],
        limit: 1,
      );
      if (orderRows.isEmpty) {
        throw StateError('Không tìm thấy phiếu mượn #${order.id}');
      }

      final detailRows = await transaction.rawQuery(
        '''
        SELECT detail.MaCTPM, detail.MaTBCT, ct.MaTB
        FROM ChiTietPM detail
        JOIN ThietBiChiTiet ct ON ct.MaTBCT = detail.MaTBCT
        WHERE detail.MaPM = ?
        ''',
        [order.id],
      );

      await transaction.update(
        'PhieuMuon',
        {
          'NgayTraThucTe': actualReturnDate.toIso8601String(),
          'TongTien': newTotal,
          'TrangThai': 'Đã trả',
          'GhiChu':
              'Đã trả thiết bị. Phí trễ: ${lateFee.toStringAsFixed(0)}; bồi thường: ${damageFee.toStringAsFixed(0)}',
        },
        where: 'MaPM = ?',
        whereArgs: [order.id],
      );

      final availableByDevice = <String, int>{};
      for (final detail in detailRows) {
        final detailId = detail['MaCTPM'] as String;
        final deviceDetailId = detail['MaTBCT'] as String;
        final deviceId = detail['MaTB'] as String;

        await transaction.update(
          'ChiTietPM',
          {'TinhTrangKhiTra': deviceCondition, 'PhiBoiThuong': damageFee},
          where: 'MaCTPM = ?',
          whereArgs: [detailId],
        );
        await transaction.update(
          'ThietBiChiTiet',
          {'TinhTrang': deviceCondition, 'TrangThai': detailStatus},
          where: 'MaTBCT = ?',
          whereArgs: [deviceDetailId],
        );

        if (detailStatus == 'Có sẵn') {
          availableByDevice[deviceId] = (availableByDevice[deviceId] ?? 0) + 1;
        }
      }

      for (final entry in availableByDevice.entries) {
        await transaction.rawUpdate(
          '''
          UPDATE ThietBi
          SET SoLuongKhaDung = MIN(SoLuongKhaDung + ?, SoLuongTong),
              TrangThai = 'Đang kinh doanh'
          WHERE MaTB = ?
          ''',
          [entry.value, entry.key],
        );
      }
    });

    final updatedOrder = order.copyWith(
      totalPrice: newTotal,
      status: 'Hoàn thành',
    );
    final index = _orders.indexWhere((item) => item.id == order.id);
    if (index != -1) _orders[index] = updatedOrder;

    final dummyIndex = dummy.rentalOrders.indexWhere(
      (item) => item.id == order.id,
    );
    if (dummyIndex != -1) dummy.rentalOrders[dummyIndex] = updatedOrder;
    AppDataRefresh.notifyChanged();
    return updatedOrder;
  }

  void deleteOrder(String id) {
    _orders.removeWhere((item) => item.id == id);
    dummy.rentalOrders.removeWhere((item) => item.id == id);
    AppDataRefresh.notifyChanged();
  }

  int getTotalOrders() => _orders.length;
  int getTotalDevices() => _orders.map((o) => o.deviceName).toSet().length;
  int getTotalCustomers() => _orders.map((o) => o.customerName).toSet().length;
  int getActiveRentals() =>
      _orders.where((o) => o.status == 'Đang thuê').length;
  int getCompletedRentals() => _orders
      .where((o) => o.status == 'Hoàn thành' || o.status == 'Đã trả')
      .length;

  double getRentingPercentage() {
    if (_orders.isEmpty || getTotalDevices() == 0) return 0;
    return getActiveRentals() / getTotalDevices() * 100;
  }

  void _decreaseDeviceAvailability(String deviceId, int quantity) {
    final index = dummy.devices.indexWhere((item) => item.id == deviceId);
    if (index == -1) return;
    final device = dummy.devices[index];
    final available = device.quantityAvailable - quantity;
    dummy.devices[index] = device.copyWith(
      quantityAvailable: available < 0 ? 0 : available,
      status: available <= 0 ? 'Bảo trì' : 'Đang cho thuê',
    );
  }

  int _rentalDayCount(DateTime startDate, DateTime endDate) {
    final days = endDate.difference(startDate).inDays;
    return days <= 0 ? 1 : days;
  }

  RentalOrder _orderFromRow(Map<String, Object?> row) {
    return RentalOrder(
      id: row['MaPM'] as String,
      customerName: row['HoTen'] as String,
      customerPhone: row['SDT'] as String? ?? '',
      customerEmail: row['Email'] as String? ?? '',
      customerAddress: row['DiaChi'] as String? ?? '',
      deviceName: row['TenTB'] as String,
      quantity: (row['SoLuong'] as num?)?.toInt() ?? 1,
      startDate: DateTime.parse(row['NgayMuon'] as String),
      endDate: DateTime.parse(row['NgayTraDuKien'] as String),
      totalPrice: (row['TongTien'] as num).toDouble(),
      status: _toAppStatus(row['TrangThai'] as String),
    );
  }

  String _toAppStatus(String status) {
    switch (status) {
      case 'Đang mượn':
        return 'Đang thuê';
      case 'Đã trả':
        return 'Hoàn thành';
      default:
        return status;
    }
  }

  String _toDatabaseStatus(String status) {
    switch (status) {
      case 'Đang thuê':
        return 'Đang mượn';
      case 'Hoàn thành':
        return 'Đã trả';
      default:
        return status;
    }
  }

  String _returnDetailStatus(String condition) {
    switch (condition) {
      case 'Hỏng':
        return 'Hỏng';
      case 'Thiếu/mất':
        return 'Mất';
      default:
        return 'Có sẵn';
    }
  }

  Future<void> _syncOrderDetails(
    DatabaseExecutor transaction,
    RentalOrder order,
  ) async {
    final isClosed = order.status == 'Hoàn thành' || order.status == 'Đã trả';
    final currentDetails = await transaction.rawQuery(
      '''
      SELECT detail.MaCTPM, detail.MaTBCT, ct.MaTB, tb.TenTB
      FROM ChiTietPM detail
      JOIN ThietBiChiTiet ct ON ct.MaTBCT = detail.MaTBCT
      JOIN ThietBi tb ON tb.MaTB = ct.MaTB
      WHERE detail.MaPM = ?
      ''',
      [order.id],
    );

    if (isClosed) {
      await _releaseOrderDetails(transaction, currentDetails);
      await transaction.update(
        'ChiTietPM',
        {'TinhTrangKhiTra': 'Tốt'},
        where: 'MaPM = ? AND TinhTrangKhiTra IS NULL',
        whereArgs: [order.id],
      );
      return;
    }

    final targetDevice = await transaction.query(
      'ThietBi',
      columns: ['MaTB'],
      where: 'lower(TenTB) = lower(?)',
      whereArgs: [order.deviceName],
      limit: 1,
    );
    if (targetDevice.isEmpty) return;

    final targetDeviceId = targetDevice.first['MaTB'] as String;
    final hasSameDevice =
        currentDetails.isNotEmpty &&
        currentDetails.every((detail) => detail['MaTB'] == targetDeviceId);
    if (hasSameDevice && currentDetails.length == order.quantity) return;

    await _releaseOrderDetails(transaction, currentDetails);
    await transaction.delete(
      'ChiTietPM',
      where: 'MaPM = ?',
      whereArgs: [order.id],
    );

    final availableDetails = await transaction.query(
      'ThietBiChiTiet',
      columns: ['MaTBCT'],
      where: "MaTB = ? AND TrangThai = 'Có sẵn'",
      whereArgs: [targetDeviceId],
      orderBy: 'MaTBCT',
      limit: order.quantity,
    );
    if (availableDetails.length < order.quantity) {
      throw StateError(
        'Thiết bị ${order.deviceName} không còn đủ số lượng khả dụng',
      );
    }

    for (var index = 0; index < availableDetails.length; index++) {
      final detailId = availableDetails[index]['MaTBCT'] as String;
      await transaction.insert('ChiTietPM', {
        'MaCTPM': '${order.id}-${(index + 1).toString().padLeft(2, '0')}',
        'MaPM': order.id,
        'MaTBCT': detailId,
        'SoLuong': 1,
        'DonGiaTaiThoiDiem': order.totalPrice / order.quantity,
        'TinhTrangKhiGiao': 'Tốt',
        'PhiBoiThuong': 0,
      });
      await transaction.update(
        'ThietBiChiTiet',
        {'TrangThai': 'Đang mượn'},
        where: 'MaTBCT = ?',
        whereArgs: [detailId],
      );
    }
    await transaction.rawUpdate(
      '''
      UPDATE ThietBi
      SET SoLuongKhaDung = MAX(SoLuongKhaDung - ?, 0),
          TrangThai = CASE
            WHEN MAX(SoLuongKhaDung - ?, 0) = 0 THEN 'Ngừng cho thuê'
            ELSE 'Đang kinh doanh'
          END
      WHERE MaTB = ?
      ''',
      [order.quantity, order.quantity, targetDeviceId],
    );
  }

  Future<void> _releaseOrderDetails(
    DatabaseExecutor transaction,
    List<Map<String, Object?>> details,
  ) async {
    final releasedByDevice = <String, int>{};
    for (final detail in details) {
      final deviceDetailId = detail['MaTBCT'] as String;
      final deviceId = detail['MaTB'] as String;
      await transaction.update(
        'ThietBiChiTiet',
        {'TrangThai': 'Có sẵn'},
        where: 'MaTBCT = ?',
        whereArgs: [deviceDetailId],
      );
      releasedByDevice[deviceId] = (releasedByDevice[deviceId] ?? 0) + 1;
    }

    for (final entry in releasedByDevice.entries) {
      await transaction.rawUpdate(
        '''
        UPDATE ThietBi
        SET SoLuongKhaDung = MIN(SoLuongKhaDung + ?, SoLuongTong),
            TrangThai = 'Đang kinh doanh'
        WHERE MaTB = ?
        ''',
        [entry.value, entry.key],
      );
    }
  }

  Future<String> _generateNextBorrowTicketIdFromDatabase() async {
    final db = await AppDatabase.instance.database;
    final maxNumber =
        Sqflite.firstIntValue(
          await db.rawQuery('''
            SELECT COALESCE(MAX(CAST(substr(MaPM, 3) AS INTEGER)), 0)
            FROM PhieuMuon
            WHERE MaPM GLOB 'PM[0-9]*'
          '''),
        ) ??
        0;
    return 'PM${(maxNumber + 1).toString().padLeft(3, '0')}';
  }

  Future<String> _resolveEmployeeId() async {
    final db = await AppDatabase.instance.database;
    if (UserSession.userId.isNotEmpty) {
      final current = await db.query(
        'NhanVien',
        columns: ['MaNV'],
        where: 'MaNV = ?',
        whereArgs: [UserSession.userId],
        limit: 1,
      );
      if (current.isNotEmpty) return UserSession.userId;
    }

    final fallback = await db.query(
      'NhanVien',
      columns: ['MaNV'],
      where: "QuyenHan IN ('Nhân viên', 'Quản lý', 'Admin')",
      orderBy: 'MaNV',
      limit: 1,
    );
    if (fallback.isEmpty) {
      throw StateError('Chưa có nhân viên hợp lệ để lập phiếu mượn');
    }
    return fallback.first['MaNV'] as String;
  }

  String _dateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
