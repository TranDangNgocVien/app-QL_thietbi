import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ung_dung_quan_ly_thiet_bi/models/customer.dart';
import 'package:ung_dung_quan_ly_thiet_bi/services/app_database.dart';
import 'package:ung_dung_quan_ly_thiet_bi/services/auth_service.dart';
import 'package:ung_dung_quan_ly_thiet_bi/services/customer_storage_service.dart';
import 'package:ung_dung_quan_ly_thiet_bi/services/order_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.close();
    final path = p.join(await getDatabasesPath(), 'equipment_rental.db');
    await deleteDatabase(path);
  });

  test('SQLite database seeds realistic data and enforces integrity', () async {
    final db = await AppDatabase.instance.database;

    final foreignKeys = await db.rawQuery('PRAGMA foreign_keys');
    expect(foreignKeys.first.values.first, 1);

    final appUserCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM AppUsers'),
    );
    final customerCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM KhachHang'),
    );
    final addedCustomers = await db.query(
      'KhachHang',
      columns: ['HoTen', 'TrangThai'],
      where: 'MaKH = ?',
      whereArgs: ['KH011'],
      limit: 1,
    );
    final requestCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM AppMaintenanceRequests'),
    );
    final taskCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM AppMaintenanceTasks'),
    );
    final importedDeviceCount = Sqflite.firstIntValue(
      await db.rawQuery("SELECT COUNT(*) FROM ThietBi WHERE MaTB LIKE 'EXT-%'"),
    );
    final importedDeviceDetailCount = Sqflite.firstIntValue(
      await db.rawQuery(
        "SELECT COUNT(*) FROM ThietBiChiTiet WHERE MaTBCT LIKE 'EXT-%'",
      ),
    );
    final importedCustomer = await db.query(
      'KhachHang',
      columns: ['HoTen', 'Email', 'CongNoHienTai'],
      where: 'MaKH = ?',
      whereArgs: ['EXT-KH001'],
      limit: 1,
    );

    expect(customerCount, greaterThanOrEqualTo(21));
    expect(appUserCount, greaterThanOrEqualTo(29));
    expect(addedCustomers.single['HoTen'], 'Trường Đại học Công Thương TP.HCM');
    expect(addedCustomers.single['TrangThai'], 'Hoạt động');
    expect(importedDeviceCount, 3);
    expect(importedDeviceDetailCount, 19);
    expect(importedCustomer.single['HoTen'], 'Lê Văn Khách');
    expect(importedCustomer.single['Email'], 'khach1@example.com');
    expect(requestCount, greaterThanOrEqualTo(5));
    expect(taskCount, greaterThanOrEqualTo(3));

    await expectLater(
      db.insert('ThietBi', {
        'MaTB': 'TB-BAD',
        'TenTB': 'Thiết bị lỗi',
        'DonGiaThue': -1,
        'SoLuongTong': 1,
        'SoLuongKhaDung': 1,
        'MaLoai': 'LTB001',
        'MaNCC': 'NCC001',
        'TrangThai': 'Đang kinh doanh',
      }),
      throwsA(isA<DatabaseException>()),
    );

    await expectLater(
      db.insert('AppMaintenanceRequests', {
        'Id': 'MR-BAD',
        'DeviceId': 'TBCT001',
        'RequesterId': 'USR-CUSTOMER',
        'Status': 'unknown',
        'Priority': 'high',
        'Description': 'Mô tả bảo trì hợp lệ nhưng trạng thái sai',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('employee can create a rental order for a SQLite customer', () async {
    final db = await AppDatabase.instance.database;
    final service = OrderService();

    final availableDevice = (await service.loadAvailableDevices()).first;

    final order = await service.createRentalOrder(
      customer: Customer(
        id: 'KH011',
        name: 'Trường Đại học Công Thương TP.HCM',
        phone: '0920000011',
        email: 'dhct@khachhang.vn',
        address: '140 Lê Trọng Tấn, Tân Phú, TP.HCM',
      ),
      device: availableDevice,
      quantity: 1,
      startDate: DateTime(2026, 6, 16),
      endDate: DateTime(2026, 6, 18),
    );

    final orders = await db.query(
      'PhieuMuon',
      where: 'MaPM = ? AND MaKH = ?',
      whereArgs: [order.id, 'KH011'],
    );
    final details = await db.query(
      'ChiTietPM',
      where: 'MaPM = ?',
      whereArgs: [order.id],
    );

    expect(orders, hasLength(1));
    expect(details, hasLength(1));
    expect(orders.single['TrangThai'], 'Đang mượn');
  });

  test('seeded staff AppUser can login as employee', () async {
    final user = await AuthService.instance.login(
      emailOrUsername: 'staff@thietbi.vn',
      password: '123456',
    );

    expect(user, isNotNull);
    expect(user!.id, 'NV002');
    expect(user.email, 'staff@thietbi.vn');
    expect(user.role, 'Nhân viên');
  });

  test('customer storage loads and persists SQLite customers', () async {
    final service = CustomerStorageService.instance;
    final seededCustomers = await service.loadCustomers();

    expect(seededCustomers, isNotEmpty);
    expect(seededCustomers.any((customer) => customer.id == 'KH011'), isTrue);

    await service.saveCustomer(
      Customer(
        id: 'KH-TEST',
        name: 'Khách hàng kiểm thử',
        phone: '0900000099',
        email: 'customer-test@example.com',
        address: 'TP.HCM',
      ),
    );

    final updatedCustomers = await service.loadCustomers();
    expect(
      updatedCustomers.any(
        (customer) =>
            customer.id == 'KH-TEST' &&
            customer.email == 'customer-test@example.com',
      ),
      isTrue,
    );
  });
}
