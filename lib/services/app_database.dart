import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const String _databaseName = 'equipment_rental.db';
  static const int _databaseVersion = 9;
  static const String _externalDatabaseAsset =
      'assets/database/quan_ly_muon_tra_thiet_bi.sqlite';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onOpen: (db) async {
        await _synchronizeReferenceData(db);
      },
      onCreate: (db, version) async {
        await _createLegacyTables(db);
        await _createBusinessSchema(db);
        await _seedBusinessData(db);
        await _seedRealisticAppData(db);
        await _importBundledExternalData(db);
        await _createIntegrityTriggers(db);
        await _synchronizeReferenceData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createBusinessSchema(db);
          await _seedBusinessData(db);
          await _migrateLegacyData(db);
        }
        if (oldVersion < 3) {
          await _synchronizeReferenceData(db);
        }
        if (oldVersion < 4) {
          await _ensureVienManagerAccount(db);
        }
        if (oldVersion < 5) {
          await _synchronizeReferenceData(db);
        }
        if (oldVersion < 6) {
          await _synchronizeReferenceData(db);
        }
        if (oldVersion < 7) {
          await _seedRealisticAppData(db);
          await _createIntegrityTriggers(db);
          await _synchronizeReferenceData(db);
        }
        if (oldVersion < 8) {
          await _seedRealisticAppData(db);
          await _synchronizeReferenceData(db);
        }
        if (oldVersion < 9) {
          await _importBundledExternalData(db);
          await _synchronizeReferenceData(db);
        }
      },
    );
  }

  Future<void> _synchronizeReferenceData(Database db) async {
    await _seedMissingBusinessData(db);
    await _normalizeVietnameseStatusText(db);
    await _ensureLinhTechnicianAccount(db);
    await _ensureTechnicianAccount(db);
    await _ensureVienManagerAccount(db);
    await _ensureStaffAccount(db);
  }

  Future<void> _seedMissingBusinessData(Database db) async {
    await db.transaction((transaction) async {
      for (final sql in _seedStatements) {
        await transaction.execute(
          sql.replaceFirst('INSERT INTO', 'INSERT OR IGNORE INTO'),
        );
      }
    });
  }

  Future<void> _normalizeVietnameseStatusText(Database db) async {
    const statuses = <String>[
      'C\u00f3 s\u1eb5n',
      '\u0110ang m\u01b0\u1ee3n',
      '\u0110ang cho thu\u00ea',
      'S\u1eb5n s\u00e0ng',
      '\u0110\u00e3 tr\u1ea3',
      '\u0110\u00e3 x\u00f3a',
      '\u0110ang l\u00e0m vi\u1ec7c',
      '\u0110ang kinh doanh',
      'B\u1ea3o tr\u00ec',
      'H\u1ecfng',
    ];

    await db.transaction((transaction) async {
      for (final status in statuses) {
        final brokenValues = {_mojibake(status), _mojibake(_mojibake(status))};
        for (final brokenValue in brokenValues) {
          await transaction.update(
            'ThietBi',
            {'TrangThai': status},
            where: 'TrangThai = ?',
            whereArgs: [brokenValue],
          );
          await transaction.update(
            'ThietBiChiTiet',
            {'TrangThai': status},
            where: 'TrangThai = ?',
            whereArgs: [brokenValue],
          );
          await transaction.update(
            'PhieuMuon',
            {'TrangThai': status},
            where: 'TrangThai = ?',
            whereArgs: [brokenValue],
          );
          await transaction.update(
            'NhanVien',
            {'TrangThai': status},
            where: 'TrangThai = ?',
            whereArgs: [brokenValue],
          );
        }
      }
    });
  }

  String _mojibake(String value) {
    return latin1.decode(utf8.encode(value), allowInvalid: true);
  }

  Future<void> _ensureVienManagerAccount(Database db) async {
    await db.insert('NhanVien', {
      'MaNV': 'NV008',
      'TenNV': 'Trần Viên',
      'ChucVu': 'Quản lý thiết bị',
      'QuyenHan': 'Quản lý',
      'SDT': '0901000016',
      'Email': 'vien@thietbi.vn',
      'MatKhau': '123456',
      'TrangThai': 'Đang làm việc',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final existingUsers = await db.query(
      'AppUsers',
      columns: ['Id'],
      where: 'MaNV = ? OR lower(Email) = lower(?)',
      whereArgs: ['NV008', 'vien@thietbi.vn'],
      limit: 1,
    );
    final values = {
      'Email': 'vien@thietbi.vn',
      'Phone': '0901000016',
      'FullName': 'Trần Viên',
      'RoleId': 'unit_manager',
      'UnitId': 'UNIT01',
      'PasswordSalt': 'APP-USR-MANAGER-NV008',
      'PasswordHash': '123456',
      'IsActive': 1,
      'MaNV': 'NV008',
    };
    if (existingUsers.isEmpty) {
      await db.insert('AppUsers', {'Id': 'USR-MANAGER-NV008', ...values});
    } else {
      await db.update(
        'AppUsers',
        values,
        where: 'Id = ?',
        whereArgs: [existingUsers.first['Id']],
      );
    }
  }

  Future<void> _ensureStaffAccount(Database db) async {
    await db.insert('NhanVien', {
      'MaNV': 'NV002',
      'TenNV': 'Phan Gia Bảo',
      'ChucVu': 'Nhân viên lập phiếu',
      'QuyenHan': 'Nhân viên',
      'SDT': '0901000010',
      'Email': 'bao@thietbi.vn',
      'MatKhau': '123456',
      'TrangThai': 'Đang làm việc',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final existingUsers = await db.query(
      'AppUsers',
      columns: ['Id'],
      where: 'MaNV = ? OR lower(Email) = lower(?)',
      whereArgs: ['NV002', 'staff@thietbi.vn'],
      limit: 1,
    );
    final values = {
      'Email': 'staff@thietbi.vn',
      'Phone': '0909000002',
      'FullName': 'Nhân viên công ty',
      'RoleId': 'company_staff',
      'UnitId': 'UNIT01',
      'PasswordSalt': 'APP-USR-STAFF',
      'PasswordHash': '123456',
      'IsActive': 1,
      'MaNV': 'NV002',
      'MaKH': null,
    };
    if (existingUsers.isEmpty) {
      await db.insert('AppUsers', {'Id': 'USR-STAFF', ...values});
    } else {
      await db.update(
        'AppUsers',
        values,
        where: 'Id = ?',
        whereArgs: [existingUsers.first['Id']],
      );
    }
  }

  Future<void> _ensureLinhTechnicianAccount(Database db) async {
    await db.insert('NhanVien', {
      'MaNV': 'NV007',
      'TenNV': 'Trần Thị Linh',
      'ChucVu': 'Kỹ thuật viên',
      'QuyenHan': 'Kỹ thuật',
      'SDT': '0901000015',
      'Email': 'linh@thietbi.vn',
      'MatKhau': '123456',
      'TrangThai': 'Đang làm việc',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.delete(
      'AppUsers',
      where: 'Id <> ? AND (MaNV = ? OR lower(Email) = lower(?) OR Phone = ?)',
      whereArgs: ['USR-TECH-NV007', 'NV007', 'linh@thietbi.vn', '0901000015'],
    );

    await db.rawInsert('''
      INSERT INTO AppUsers (
        Id, Email, Phone, FullName, RoleId, UnitId, PasswordSalt,
        PasswordHash, IsActive, MaNV
      ) VALUES (
        'USR-TECH-NV007', 'linh@thietbi.vn', '0901000015',
        'Trần Thị Linh', 'technician', 'UNIT01',
        'APP-USR-TECH-NV007', '123456', 1, 'NV007'
      )
      ON CONFLICT(Id) DO UPDATE SET
        Email = excluded.Email,
        Phone = excluded.Phone,
        FullName = excluded.FullName,
        RoleId = excluded.RoleId,
        UnitId = excluded.UnitId,
        PasswordSalt = excluded.PasswordSalt,
        PasswordHash = excluded.PasswordHash,
        IsActive = excluded.IsActive,
        MaNV = excluded.MaNV
    ''');
  }

  Future<void> _ensureTechnicianAccount(Database db) async {
    await db.rawUpdate('''
      UPDATE AppUsers
      SET FullName = (
        SELECT employee.TenNV
        FROM NhanVien employee
        WHERE employee.MaNV = AppUsers.MaNV
      )
      WHERE RoleId = 'technician'
        AND EXISTS (
          SELECT 1 FROM NhanVien employee
          WHERE employee.MaNV = AppUsers.MaNV
        )
    ''');

    final technicians = await db.rawQuery('''
      SELECT MaNV, TenNV, Email, SDT, MatKhau
      FROM NhanVien
      WHERE QuyenHan = 'Kỹ thuật' AND TrangThai = 'Đang làm việc'
    ''');
    for (final technician in technicians) {
      final employeeId = technician['MaNV'] as String;
      await db.rawInsert(
        '''
        INSERT INTO AppUsers (
          Id, Email, Phone, FullName, RoleId, UnitId, PasswordSalt,
          PasswordHash, IsActive, MaNV
        )
        SELECT ?, ?, ?, ?, 'technician', 'UNIT01', ?, ?, 1, ?
        WHERE NOT EXISTS (
          SELECT 1 FROM AppUsers
          WHERE RoleId = 'technician' AND MaNV = ?
        )
        ''',
        [
          'USR-TECH-$employeeId',
          technician['Email'],
          technician['SDT'],
          technician['TenNV'],
          'APP-USR-TECH-$employeeId',
          technician['MatKhau'],
          employeeId,
          employeeId,
        ],
      );
    }
  }

  Future<void> _createLegacyTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS devices (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL,
        status TEXT NOT NULL, pricePerDay REAL NOT NULL,
        quantityTotal INTEGER NOT NULL, quantityAvailable INTEGER NOT NULL,
        description TEXT NOT NULL, imagesJson TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, phone TEXT NOT NULL,
        email TEXT NOT NULL, address TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rental_orders (
        id TEXT PRIMARY KEY, customerName TEXT NOT NULL,
        customerPhone TEXT NOT NULL, customerEmail TEXT NOT NULL,
        customerAddress TEXT NOT NULL, deviceName TEXT NOT NULL,
        startDate TEXT NOT NULL, endDate TEXT NOT NULL,
        totalPrice REAL NOT NULL, status TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createBusinessSchema(DatabaseExecutor db) async {
    for (final sql in _schemaStatements) {
      await db.execute(sql);
    }
  }

  Future<void> _createIntegrityTriggers(Database db) async {
    for (final sql in _integrityTriggerStatements) {
      await db.execute(sql);
    }
  }

  Future<void> _seedBusinessData(Database db) async {
    final count =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM LoaiThietBi'),
        ) ??
        0;
    if (count > 0) return;

    await db.transaction((transaction) async {
      for (final sql in _seedStatements) {
        await transaction.execute(sql);
      }
    });
  }

  Future<void> _seedRealisticAppData(Database db) async {
    await db.transaction((transaction) async {
      for (final sql in _realisticSeedStatements) {
        await transaction.execute(sql);
      }
    });
  }

  Future<void> _importBundledExternalData(Database db) async {
    final externalPath = await _copyExternalDatabaseAsset();
    final escapedPath = externalPath.replaceAll("'", "''");
    await db.execute("ATTACH DATABASE '$escapedPath' AS external_source");
    await db.transaction((transaction) async {
      for (final sql in _externalImportStatements) {
        await transaction.execute(sql);
      }
    });
  }

  Future<String> _copyExternalDatabaseAsset() async {
    final data = await rootBundle.load(_externalDatabaseAsset);
    final databasesPath = await getDatabasesPath();
    final importPath = p.join(
      databasesPath,
      'external_quan_ly_muon_tra.sqlite',
    );
    final file = File(importPath);
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return importPath;
  }

  Future<void> _migrateLegacyData(Database db) async {
    final deviceCount =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM devices'),
        ) ??
        0;
    if (deviceCount > 0) {
      await db.execute('''
        INSERT OR IGNORE INTO LoaiThietBi (MaLoai, TenLoai, MoTa)
        SELECT 'LEGACY-' || type, type, 'Dữ liệu được chuyển từ SQLite cũ'
        FROM devices
      ''');
      await db.execute('''
        INSERT OR IGNORE INTO NhaCungCap (MaNCC, TenNCC)
        VALUES ('NCC-APP', 'Nhà cung cấp mặc định')
      ''');
      await db.execute('''
        INSERT OR IGNORE INTO ThietBi
          (MaTB, TenTB, DonGiaThue, SoLuongTong, SoLuongKhaDung,
           MoTaKyThuat, HinhAnh, MaLoai, MaNCC, TrangThai)
        SELECT id, name, pricePerDay, quantityTotal, quantityAvailable,
               description, NULL,
               COALESCE(
                 (SELECT MaLoai FROM LoaiThietBi l WHERE l.TenLoai = devices.type),
                 'LEGACY-' || type
               ),
               'NCC-APP',
               CASE
                 WHEN status IN ('Thanh lý', 'Ngừng cho thuê') THEN status
                 ELSE 'Đang kinh doanh'
               END
        FROM devices
      ''');
    }

    await db.execute('''
      INSERT OR IGNORE INTO KhachHang
        (MaKH, HoTen, SDT, Email, DiaChi)
      SELECT id, name, NULLIF(phone, ''), NULLIF(email, ''), NULLIF(address, '')
      FROM customers
    ''');
  }
}

const List<String> _integrityTriggerStatements = [
  '''
  CREATE TRIGGER IF NOT EXISTS trg_NhaCungCap_validate_insert
  BEFORE INSERT ON NhaCungCap
  BEGIN
    SELECT CASE
      WHEN NEW.Email IS NOT NULL AND NEW.Email NOT LIKE '%_@_%._%'
        THEN RAISE(ABORT, 'Email nhà cung cấp không hợp lệ')
      WHEN NEW.SDT IS NOT NULL AND NEW.SDT GLOB '*[^0-9+]*'
        THEN RAISE(ABORT, 'Số điện thoại nhà cung cấp không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_NhaCungCap_validate_update
  BEFORE UPDATE ON NhaCungCap
  BEGIN
    SELECT CASE
      WHEN NEW.Email IS NOT NULL AND NEW.Email NOT LIKE '%_@_%._%'
        THEN RAISE(ABORT, 'Email nhà cung cấp không hợp lệ')
      WHEN NEW.SDT IS NOT NULL AND NEW.SDT GLOB '*[^0-9+]*'
        THEN RAISE(ABORT, 'Số điện thoại nhà cung cấp không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_NhanVien_validate_insert
  BEFORE INSERT ON NhanVien
  BEGIN
    SELECT CASE
      WHEN NEW.Email IS NOT NULL AND NEW.Email NOT LIKE '%_@_%._%'
        THEN RAISE(ABORT, 'Email nhân viên không hợp lệ')
      WHEN NEW.QuyenHan NOT IN ('Admin','Quản lý','Nhân viên','Kỹ thuật','Kế toán')
        THEN RAISE(ABORT, 'Quyền hạn nhân viên không hợp lệ')
      WHEN NEW.TrangThai NOT IN ('Đang làm việc','Tạm nghỉ','Nghỉ việc')
        THEN RAISE(ABORT, 'Trạng thái nhân viên không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_NhanVien_validate_update
  BEFORE UPDATE ON NhanVien
  BEGIN
    SELECT CASE
      WHEN NEW.Email IS NOT NULL AND NEW.Email NOT LIKE '%_@_%._%'
        THEN RAISE(ABORT, 'Email nhân viên không hợp lệ')
      WHEN NEW.QuyenHan NOT IN ('Admin','Quản lý','Nhân viên','Kỹ thuật','Kế toán')
        THEN RAISE(ABORT, 'Quyền hạn nhân viên không hợp lệ')
      WHEN NEW.TrangThai NOT IN ('Đang làm việc','Tạm nghỉ','Nghỉ việc')
        THEN RAISE(ABORT, 'Trạng thái nhân viên không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_KhachHang_validate_insert
  BEFORE INSERT ON KhachHang
  BEGIN
    SELECT CASE
      WHEN NEW.Email IS NOT NULL AND NEW.Email NOT LIKE '%_@_%._%'
        THEN RAISE(ABORT, 'Email khách hàng không hợp lệ')
      WHEN NEW.CongNoHienTai < 0
        THEN RAISE(ABORT, 'Công nợ khách hàng không được âm')
      WHEN NEW.TrangThai NOT IN ('Hoạt động','Tạm khóa','Ngừng hợp tác')
        THEN RAISE(ABORT, 'Trạng thái khách hàng không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_KhachHang_validate_update
  BEFORE UPDATE ON KhachHang
  BEGIN
    SELECT CASE
      WHEN NEW.Email IS NOT NULL AND NEW.Email NOT LIKE '%_@_%._%'
        THEN RAISE(ABORT, 'Email khách hàng không hợp lệ')
      WHEN NEW.CongNoHienTai < 0
        THEN RAISE(ABORT, 'Công nợ khách hàng không được âm')
      WHEN NEW.TrangThai NOT IN ('Hoạt động','Tạm khóa','Ngừng hợp tác')
        THEN RAISE(ABORT, 'Trạng thái khách hàng không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_ThietBi_validate_insert
  BEFORE INSERT ON ThietBi
  BEGIN
    SELECT CASE
      WHEN NEW.DonGiaThue < 0
        THEN RAISE(ABORT, 'Đơn giá thuê không được âm')
      WHEN NEW.SoLuongTong < 0 OR NEW.SoLuongKhaDung < 0
        THEN RAISE(ABORT, 'Số lượng thiết bị không được âm')
      WHEN NEW.SoLuongKhaDung > NEW.SoLuongTong
        THEN RAISE(ABORT, 'Số lượng khả dụng không được vượt quá tổng')
      WHEN NEW.TrangThai NOT IN ('Đang kinh doanh','Ngừng cho thuê','Thanh lý','Đã xóa')
        THEN RAISE(ABORT, 'Trạng thái thiết bị không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_ThietBi_validate_update
  BEFORE UPDATE ON ThietBi
  BEGIN
    SELECT CASE
      WHEN NEW.DonGiaThue < 0
        THEN RAISE(ABORT, 'Đơn giá thuê không được âm')
      WHEN NEW.SoLuongTong < 0 OR NEW.SoLuongKhaDung < 0
        THEN RAISE(ABORT, 'Số lượng thiết bị không được âm')
      WHEN NEW.SoLuongKhaDung > NEW.SoLuongTong
        THEN RAISE(ABORT, 'Số lượng khả dụng không được vượt quá tổng')
      WHEN NEW.TrangThai NOT IN ('Đang kinh doanh','Ngừng cho thuê','Thanh lý','Đã xóa')
        THEN RAISE(ABORT, 'Trạng thái thiết bị không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_ThietBiChiTiet_validate_insert
  BEFORE INSERT ON ThietBiChiTiet
  BEGIN
    SELECT CASE
      WHEN NEW.TinhTrang NOT IN ('Mới','Tốt','Bình thường','Cũ','Hỏng nặng')
        THEN RAISE(ABORT, 'Tình trạng thiết bị chi tiết không hợp lệ')
      WHEN NEW.TrangThai NOT IN ('Có sẵn','Đang mượn','Đang bảo trì','Hỏng','Mất','Thanh lý')
        THEN RAISE(ABORT, 'Trạng thái thiết bị chi tiết không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_ThietBiChiTiet_validate_update
  BEFORE UPDATE ON ThietBiChiTiet
  BEGIN
    SELECT CASE
      WHEN NEW.TinhTrang NOT IN ('Mới','Tốt','Bình thường','Cũ','Hỏng nặng')
        THEN RAISE(ABORT, 'Tình trạng thiết bị chi tiết không hợp lệ')
      WHEN NEW.TrangThai NOT IN ('Có sẵn','Đang mượn','Đang bảo trì','Hỏng','Mất','Thanh lý')
        THEN RAISE(ABORT, 'Trạng thái thiết bị chi tiết không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_YeuCauMuon_validate_insert
  BEFORE INSERT ON YeuCauMuon
  BEGIN
    SELECT CASE
      WHEN date(NEW.NgayDuKien) < date(NEW.NgayBatDau)
        THEN RAISE(ABORT, 'Ngày dự kiến phải sau ngày bắt đầu')
      WHEN NEW.TrangThaiYeuCau NOT IN ('Chờ duyệt','Đã duyệt','Từ chối','Đã hủy','Đã lập phiếu')
        THEN RAISE(ABORT, 'Trạng thái yêu cầu mượn không hợp lệ')
      WHEN NEW.TrangThaiYeuCau = 'Từ chối' AND NEW.LyDoTuChoi IS NULL
        THEN RAISE(ABORT, 'Yêu cầu từ chối phải có lý do')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_YeuCauMuon_validate_update
  BEFORE UPDATE ON YeuCauMuon
  BEGIN
    SELECT CASE
      WHEN date(NEW.NgayDuKien) < date(NEW.NgayBatDau)
        THEN RAISE(ABORT, 'Ngày dự kiến phải sau ngày bắt đầu')
      WHEN NEW.TrangThaiYeuCau NOT IN ('Chờ duyệt','Đã duyệt','Từ chối','Đã hủy','Đã lập phiếu')
        THEN RAISE(ABORT, 'Trạng thái yêu cầu mượn không hợp lệ')
      WHEN NEW.TrangThaiYeuCau = 'Từ chối' AND NEW.LyDoTuChoi IS NULL
        THEN RAISE(ABORT, 'Yêu cầu từ chối phải có lý do')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_PhieuMuon_validate_insert
  BEFORE INSERT ON PhieuMuon
  BEGIN
    SELECT CASE
      WHEN NEW.TongTien < 0
        THEN RAISE(ABORT, 'Tổng tiền phiếu mượn không được âm')
      WHEN date(NEW.NgayTraDuKien) < date(NEW.NgayMuon)
        THEN RAISE(ABORT, 'Ngày trả dự kiến phải sau ngày mượn')
      WHEN NEW.NgayTraThucTe IS NOT NULL AND date(NEW.NgayTraThucTe) < date(NEW.NgayMuon)
        THEN RAISE(ABORT, 'Ngày trả thực tế phải sau ngày mượn')
      WHEN NEW.TrangThai NOT IN ('Đang mượn','Đã trả','Quá hạn','Đã hủy','Đang thuê','Hoàn thành')
        THEN RAISE(ABORT, 'Trạng thái phiếu mượn không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_PhieuMuon_validate_update
  BEFORE UPDATE ON PhieuMuon
  BEGIN
    SELECT CASE
      WHEN NEW.TongTien < 0
        THEN RAISE(ABORT, 'Tổng tiền phiếu mượn không được âm')
      WHEN date(NEW.NgayTraDuKien) < date(NEW.NgayMuon)
        THEN RAISE(ABORT, 'Ngày trả dự kiến phải sau ngày mượn')
      WHEN NEW.NgayTraThucTe IS NOT NULL AND date(NEW.NgayTraThucTe) < date(NEW.NgayMuon)
        THEN RAISE(ABORT, 'Ngày trả thực tế phải sau ngày mượn')
      WHEN NEW.TrangThai NOT IN ('Đang mượn','Đã trả','Quá hạn','Đã hủy','Đang thuê','Hoàn thành')
        THEN RAISE(ABORT, 'Trạng thái phiếu mượn không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_ChiTietPM_validate_insert
  BEFORE INSERT ON ChiTietPM
  BEGIN
    SELECT CASE
      WHEN NEW.SoLuong <= 0
        THEN RAISE(ABORT, 'Số lượng chi tiết phiếu mượn phải lớn hơn 0')
      WHEN NEW.DonGiaTaiThoiDiem < 0 OR NEW.PhiBoiThuong < 0
        THEN RAISE(ABORT, 'Đơn giá và phí bồi thường không được âm')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_ChiTietPM_validate_update
  BEFORE UPDATE ON ChiTietPM
  BEGIN
    SELECT CASE
      WHEN NEW.SoLuong <= 0
        THEN RAISE(ABORT, 'Số lượng chi tiết phiếu mượn phải lớn hơn 0')
      WHEN NEW.DonGiaTaiThoiDiem < 0 OR NEW.PhiBoiThuong < 0
        THEN RAISE(ABORT, 'Đơn giá và phí bồi thường không được âm')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_ThanhToan_validate_insert
  BEFORE INSERT ON ThanhToan
  BEGIN
    SELECT CASE
      WHEN NEW.SoTien < 0
        THEN RAISE(ABORT, 'Số tiền thanh toán không được âm')
      WHEN NEW.PhuongThuc NOT IN ('Tiền mặt','Chuyển khoản','Thẻ','Ví điện tử')
        THEN RAISE(ABORT, 'Phương thức thanh toán không hợp lệ')
      WHEN NEW.LoaiThanhToan NOT IN ('Tiền thuê','Đặt cọc','Phụ phí','Bồi thường','Hoàn tiền')
        THEN RAISE(ABORT, 'Loại thanh toán không hợp lệ')
      WHEN NEW.TrangThai NOT IN ('Chờ thanh toán','Đã thanh toán','Thất bại','Đã hoàn tiền')
        THEN RAISE(ABORT, 'Trạng thái thanh toán không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_ThanhToan_validate_update
  BEFORE UPDATE ON ThanhToan
  BEGIN
    SELECT CASE
      WHEN NEW.SoTien < 0
        THEN RAISE(ABORT, 'Số tiền thanh toán không được âm')
      WHEN NEW.PhuongThuc NOT IN ('Tiền mặt','Chuyển khoản','Thẻ','Ví điện tử')
        THEN RAISE(ABORT, 'Phương thức thanh toán không hợp lệ')
      WHEN NEW.LoaiThanhToan NOT IN ('Tiền thuê','Đặt cọc','Phụ phí','Bồi thường','Hoàn tiền')
        THEN RAISE(ABORT, 'Loại thanh toán không hợp lệ')
      WHEN NEW.TrangThai NOT IN ('Chờ thanh toán','Đã thanh toán','Thất bại','Đã hoàn tiền')
        THEN RAISE(ABORT, 'Trạng thái thanh toán không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_GiaHanMuon_validate_insert
  BEFORE INSERT ON GiaHanMuon
  BEGIN
    SELECT CASE
      WHEN date(NEW.NgayTraMoi) <= date(NEW.NgayTraCu)
        THEN RAISE(ABORT, 'Ngày trả mới phải sau ngày trả cũ')
      WHEN NEW.TrangThaiGiaHan NOT IN ('Chờ duyệt','Đã duyệt','Từ chối','Đã hủy')
        THEN RAISE(ABORT, 'Trạng thái gia hạn không hợp lệ')
      WHEN NEW.TrangThaiGiaHan = 'Từ chối' AND NEW.LyDoTuChoi IS NULL
        THEN RAISE(ABORT, 'Gia hạn từ chối phải có lý do')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_GiaHanMuon_validate_update
  BEFORE UPDATE ON GiaHanMuon
  BEGIN
    SELECT CASE
      WHEN date(NEW.NgayTraMoi) <= date(NEW.NgayTraCu)
        THEN RAISE(ABORT, 'Ngày trả mới phải sau ngày trả cũ')
      WHEN NEW.TrangThaiGiaHan NOT IN ('Chờ duyệt','Đã duyệt','Từ chối','Đã hủy')
        THEN RAISE(ABORT, 'Trạng thái gia hạn không hợp lệ')
      WHEN NEW.TrangThaiGiaHan = 'Từ chối' AND NEW.LyDoTuChoi IS NULL
        THEN RAISE(ABORT, 'Gia hạn từ chối phải có lý do')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_PhuPhiViPham_validate_insert
  BEFORE INSERT ON PhuPhiViPham
  BEGIN
    SELECT CASE
      WHEN NEW.SoTien < 0
        THEN RAISE(ABORT, 'Phụ phí vi phạm không được âm')
      WHEN NEW.LoaiViPham NOT IN ('Trễ hạn','Hư hỏng','Mất thiết bị','Vệ sinh','Khác')
        THEN RAISE(ABORT, 'Loại vi phạm không hợp lệ')
      WHEN NEW.TrangThaiXL NOT IN ('Chưa xử lý','Đã lập biên bản','Đã thu phí','Đã hủy')
        THEN RAISE(ABORT, 'Trạng thái xử lý vi phạm không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_PhuPhiViPham_validate_update
  BEFORE UPDATE ON PhuPhiViPham
  BEGIN
    SELECT CASE
      WHEN NEW.SoTien < 0
        THEN RAISE(ABORT, 'Phụ phí vi phạm không được âm')
      WHEN NEW.LoaiViPham NOT IN ('Trễ hạn','Hư hỏng','Mất thiết bị','Vệ sinh','Khác')
        THEN RAISE(ABORT, 'Loại vi phạm không hợp lệ')
      WHEN NEW.TrangThaiXL NOT IN ('Chưa xử lý','Đã lập biên bản','Đã thu phí','Đã hủy')
        THEN RAISE(ABORT, 'Trạng thái xử lý vi phạm không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_BaoTri_validate_insert
  BEFORE INSERT ON BaoTri
  BEGIN
    SELECT CASE
      WHEN NEW.MucDoHuHong NOT IN ('Nhẹ','Trung bình','Nặng','Rất nặng')
        THEN RAISE(ABORT, 'Mức độ hư hỏng không hợp lệ')
      WHEN NEW.TrangThai NOT IN ('Chờ tiếp nhận','Đang xử lý','Hoàn thành','Từ chối')
        THEN RAISE(ABORT, 'Trạng thái bảo trì không hợp lệ')
      WHEN NEW.ChiPhi < 0
        THEN RAISE(ABORT, 'Chi phí bảo trì không được âm')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_BaoTri_validate_update
  BEFORE UPDATE ON BaoTri
  BEGIN
    SELECT CASE
      WHEN NEW.MucDoHuHong NOT IN ('Nhẹ','Trung bình','Nặng','Rất nặng')
        THEN RAISE(ABORT, 'Mức độ hư hỏng không hợp lệ')
      WHEN NEW.TrangThai NOT IN ('Chờ tiếp nhận','Đang xử lý','Hoàn thành','Từ chối')
        THEN RAISE(ABORT, 'Trạng thái bảo trì không hợp lệ')
      WHEN NEW.ChiPhi < 0
        THEN RAISE(ABORT, 'Chi phí bảo trì không được âm')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_BaoCao_validate_insert
  BEFORE INSERT ON BaoCao
  BEGIN
    SELECT CASE
      WHEN date(NEW.DenNgay) < date(NEW.TuNgay)
        THEN RAISE(ABORT, 'Ngày kết thúc báo cáo phải sau ngày bắt đầu')
      WHEN NEW.LoaiBaoCao NOT IN ('Doanh thu','Thiết bị','Bảo trì','Khách hàng','Tổng hợp')
        THEN RAISE(ABORT, 'Loại báo cáo không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_BaoCao_validate_update
  BEFORE UPDATE ON BaoCao
  BEGIN
    SELECT CASE
      WHEN date(NEW.DenNgay) < date(NEW.TuNgay)
        THEN RAISE(ABORT, 'Ngày kết thúc báo cáo phải sau ngày bắt đầu')
      WHEN NEW.LoaiBaoCao NOT IN ('Doanh thu','Thiết bị','Bảo trì','Khách hàng','Tổng hợp')
        THEN RAISE(ABORT, 'Loại báo cáo không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_AppUsers_validate_insert
  BEFORE INSERT ON AppUsers
  BEGIN
    SELECT CASE
      WHEN NEW.RoleId NOT IN ('requester','approver','company_staff','technician','unit_manager','admin')
        THEN RAISE(ABORT, 'Vai trò tài khoản không hợp lệ')
      WHEN NEW.Email IS NULL AND NEW.Phone IS NULL
        THEN RAISE(ABORT, 'Tài khoản phải có email hoặc số điện thoại')
      WHEN NEW.MaNV IS NOT NULL AND NEW.MaKH IS NOT NULL
        THEN RAISE(ABORT, 'Tài khoản chỉ được liên kết nhân viên hoặc khách hàng')
      WHEN NEW.IsActive NOT IN (0, 1)
        THEN RAISE(ABORT, 'Trạng thái kích hoạt tài khoản không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_AppUsers_validate_update
  BEFORE UPDATE ON AppUsers
  BEGIN
    SELECT CASE
      WHEN NEW.RoleId NOT IN ('requester','approver','company_staff','technician','unit_manager','admin')
        THEN RAISE(ABORT, 'Vai trò tài khoản không hợp lệ')
      WHEN NEW.Email IS NULL AND NEW.Phone IS NULL
        THEN RAISE(ABORT, 'Tài khoản phải có email hoặc số điện thoại')
      WHEN NEW.MaNV IS NOT NULL AND NEW.MaKH IS NOT NULL
        THEN RAISE(ABORT, 'Tài khoản chỉ được liên kết nhân viên hoặc khách hàng')
      WHEN NEW.IsActive NOT IN (0, 1)
        THEN RAISE(ABORT, 'Trạng thái kích hoạt tài khoản không hợp lệ')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_AppMaintenanceRequests_validate_insert
  BEFORE INSERT ON AppMaintenanceRequests
  BEGIN
    SELECT CASE
      WHEN NEW.Status NOT IN ('pending','approved','in_progress','completed','rejected','suspended')
        THEN RAISE(ABORT, 'Trạng thái yêu cầu bảo trì app không hợp lệ')
      WHEN NEW.Priority NOT IN ('low','medium','high','critical')
        THEN RAISE(ABORT, 'Mức ưu tiên bảo trì không hợp lệ')
      WHEN length(trim(NEW.Description)) < 10
        THEN RAISE(ABORT, 'Mô tả bảo trì phải có ít nhất 10 ký tự')
      WHEN NEW.Status = 'rejected' AND NEW.RejectionReason IS NULL
        THEN RAISE(ABORT, 'Yêu cầu bị từ chối phải có lý do')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_AppMaintenanceRequests_validate_update
  BEFORE UPDATE ON AppMaintenanceRequests
  BEGIN
    SELECT CASE
      WHEN NEW.Status NOT IN ('pending','approved','in_progress','completed','rejected','suspended')
        THEN RAISE(ABORT, 'Trạng thái yêu cầu bảo trì app không hợp lệ')
      WHEN NEW.Priority NOT IN ('low','medium','high','critical')
        THEN RAISE(ABORT, 'Mức ưu tiên bảo trì không hợp lệ')
      WHEN length(trim(NEW.Description)) < 10
        THEN RAISE(ABORT, 'Mô tả bảo trì phải có ít nhất 10 ký tự')
      WHEN NEW.Status = 'rejected' AND NEW.RejectionReason IS NULL
        THEN RAISE(ABORT, 'Yêu cầu bị từ chối phải có lý do')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_AppMaintenanceTasks_validate_insert
  BEFORE INSERT ON AppMaintenanceTasks
  BEGIN
    SELECT CASE
      WHEN NEW.Status NOT IN ('pending','in_progress','completed','cancelled')
        THEN RAISE(ABORT, 'Trạng thái công việc bảo trì không hợp lệ')
      WHEN NEW.Progress < 0 OR NEW.Progress > 100
        THEN RAISE(ABORT, 'Tiến độ bảo trì phải từ 0 đến 100')
      WHEN NEW.Cost IS NOT NULL AND NEW.Cost < 0
        THEN RAISE(ABORT, 'Chi phí công việc bảo trì không được âm')
    END;
  END
  ''',
  '''
  CREATE TRIGGER IF NOT EXISTS trg_AppMaintenanceTasks_validate_update
  BEFORE UPDATE ON AppMaintenanceTasks
  BEGIN
    SELECT CASE
      WHEN NEW.Status NOT IN ('pending','in_progress','completed','cancelled')
        THEN RAISE(ABORT, 'Trạng thái công việc bảo trì không hợp lệ')
      WHEN NEW.Progress < 0 OR NEW.Progress > 100
        THEN RAISE(ABORT, 'Tiến độ bảo trì phải từ 0 đến 100')
      WHEN NEW.Cost IS NOT NULL AND NEW.Cost < 0
        THEN RAISE(ABORT, 'Chi phí công việc bảo trì không được âm')
    END;
  END
  ''',
];

const List<String> _realisticSeedStatements = [
  '''
  INSERT OR IGNORE INTO KhachHang
  (MaKH, HoTen, SDT, Email, CCCD, DiaChi, CongNoHienTai, TrangThai) VALUES
  ('KH011','Trường Đại học Công Thương TP.HCM','0920000011','dhct@khachhang.vn','030100000011','140 Lê Trọng Tấn, Tân Phú, TP.HCM',0,'Hoạt động'),
  ('KH012','Trường Cao đẳng Kỹ thuật Cao Thắng','0920000012','caothang@khachhang.vn','030100000012','65 Huỳnh Thúc Kháng, Quận 1, TP.HCM',0,'Hoạt động'),
  ('KH013','Công ty Tổ chức Sự kiện BlueSky','0920000013','bluesky.event@khachhang.vn','030100000013','18 Nguyễn Gia Trí, Bình Thạnh, TP.HCM',850000,'Hoạt động'),
  ('KH014','Trung tâm Hội nghị Hoa Sen','0920000014','hoasen.center@khachhang.vn','030100000014','9 Phan Đăng Lưu, Phú Nhuận, TP.HCM',0,'Hoạt động'),
  ('KH015','Studio Media Ánh Dương','0920000015','anhduong.media@khachhang.vn','030100000015','27 Cách Mạng Tháng 8, Quận 3, TP.HCM',1200000,'Tạm khóa'),
  ('KH016','Công ty TNHH Giáo dục STEM Việt','0920000016','stemviet@khachhang.vn','030100000016','42 Nguyễn Thị Minh Khai, Quận 1, TP.HCM',0,'Hoạt động'),
  ('KH017','Nhà Văn hóa Thanh Niên Quận 7','0920000017','nvhtnq7@khachhang.vn','030100000017','201 Nguyễn Thị Thập, Quận 7, TP.HCM',0,'Hoạt động'),
  ('KH018','Phòng Đào tạo Doanh nghiệp Mekong','0920000018','mekong.training@khachhang.vn','030100000018','33 Võ Văn Kiệt, Ninh Kiều, Cần Thơ',300000,'Hoạt động'),
  ('KH019','Câu lạc bộ Nhiếp ảnh LensArt','0920000019','lensart.club@khachhang.vn','030100000019','12 Trần Phú, Hải Châu, Đà Nẵng',0,'Hoạt động'),
  ('KH020','Công ty Truyền thông Nam Việt','0920000020','namviet.media@khachhang.vn','030100000020','88 Lý Thường Kiệt, Hoàn Kiếm, Hà Nội',0,'Ngừng hợp tác')
  ''',
  '''
  INSERT OR IGNORE INTO AppUsers
  (Id,Email,Phone,FullName,RoleId,UnitId,PasswordSalt,PasswordHash,IsActive,MaNV,MaKH) VALUES
  ('USR-KH002','lequydon@gmail.com','0902222222','THPT Lê Quý Đôn','requester','UNIT-KH','APP-USR-KH002','123456',1,NULL,'KH002'),
  ('USR-KH003','thcstranhungdao@gmail.com','0903333333','THCS Trần Hưng Đạo','requester','UNIT-KH','APP-USR-KH003','123456',1,NULL,'KH003'),
  ('USR-KH004','abc@gmail.com','0904444444','Công ty ABC','requester','UNIT-KH','APP-USR-KH004','123456',1,NULL,'KH004'),
  ('USR-KH005','minhphat@gmail.com','0905555555','Công ty Minh Phát','requester','UNIT-KH','APP-USR-KH005','123456',1,NULL,'KH005'),
  ('USR-KH006','future@gmail.com','0906666666','Trung tâm Anh ngữ Future','requester','UNIT-KH','APP-USR-KH006','123456',1,NULL,'KH006'),
  ('USR-KH007','saoviet@gmail.com','0907777777','Trung tâm Tin học Sao Việt','requester','UNIT-KH','APP-USR-KH007','123456',1,NULL,'KH007'),
  ('USR-KH008','melody@gmail.com','0908888888','Quán Cafe Melody','requester','UNIT-KH','APP-USR-KH008','123456',1,NULL,'KH008'),
  ('USR-KH009','trithuc@gmail.com','0909999999','Nhà sách Tri Thức','requester','UNIT-KH','APP-USR-KH009','123456',1,NULL,'KH009'),
  ('USR-KH010','vantai@gmail.com','0911111111','Nguyễn Văn Tài','requester','UNIT-KH','APP-USR-KH010','123456',1,NULL,'KH010'),
  ('USR-KH011','dhct@khachhang.vn','0920000011','Trường Đại học Công Thương TP.HCM','requester','UNIT-KH','APP-USR-KH011','123456',1,NULL,'KH011'),
  ('USR-KH012','caothang@khachhang.vn','0920000012','Trường Cao đẳng Kỹ thuật Cao Thắng','requester','UNIT-KH','APP-USR-KH012','123456',1,NULL,'KH012'),
  ('USR-KH013','bluesky.event@khachhang.vn','0920000013','Công ty Tổ chức Sự kiện BlueSky','requester','UNIT-KH','APP-USR-KH013','123456',1,NULL,'KH013'),
  ('USR-KH014','hoasen.center@khachhang.vn','0920000014','Trung tâm Hội nghị Hoa Sen','requester','UNIT-KH','APP-USR-KH014','123456',1,NULL,'KH014'),
  ('USR-KH015','anhduong.media@khachhang.vn','0920000015','Studio Media Ánh Dương','requester','UNIT-KH','APP-USR-KH015','123456',1,NULL,'KH015'),
  ('USR-KH016','stemviet@khachhang.vn','0920000016','Công ty TNHH Giáo dục STEM Việt','requester','UNIT-KH','APP-USR-KH016','123456',1,NULL,'KH016'),
  ('USR-KH017','nvhtnq7@khachhang.vn','0920000017','Nhà Văn hóa Thanh Niên Quận 7','requester','UNIT-KH','APP-USR-KH017','123456',1,NULL,'KH017'),
  ('USR-KH018','mekong.training@khachhang.vn','0920000018','Phòng Đào tạo Doanh nghiệp Mekong','requester','UNIT-KH','APP-USR-KH018','123456',1,NULL,'KH018'),
  ('USR-KH019','lensart.club@khachhang.vn','0920000019','Câu lạc bộ Nhiếp ảnh LensArt','requester','UNIT-KH','APP-USR-KH019','123456',1,NULL,'KH019'),
  ('USR-KH020','namviet.media@khachhang.vn','0920000020','Công ty Truyền thông Nam Việt','requester','UNIT-KH','APP-USR-KH020','123456',1,NULL,'KH020')
  ''',
  '''
  INSERT OR IGNORE INTO AppMaintenanceRequests
  (Id,DeviceId,RequesterId,Status,Priority,Description,RejectionReason,TechnicianId,ApproverId,CompletionDate,CreatedAt,UpdatedAt) VALUES
  ('MR001','TBCT001','USR-CUSTOMER','pending','high','Máy chiếu bị mờ hình và quạt tản nhiệt kêu lớn khi sử dụng.',NULL,NULL,NULL,NULL,'2026-06-15 08:30:00','2026-06-15 08:30:00'),
  ('MR002','TBCT007','USR-KH002','approved','medium','Laptop khởi động chậm, cần kiểm tra ổ cứng và phần mềm lớp tập huấn.',NULL,'USR-TECH','USR-MANAGER',NULL,'2026-06-14 10:15:00','2026-06-14 11:00:00'),
  ('MR003','TBCT010','USR-KH002','in_progress','critical','Laptop thường xuyên tắt nguồn khi đang trình chiếu bài giảng.',NULL,'USR-TECH-NV004','USR-MANAGER',NULL,'2026-06-13 09:00:00','2026-06-13 14:30:00'),
  ('MR004','TBCT023','USR-KH004','completed','low','Camera bị trầy vỏ ngoài sau sự kiện, cần vệ sinh và kiểm tra hình ảnh.',NULL,'USR-TECH-NV007','USR-MANAGER','2026-06-12 16:45:00','2026-06-12 08:00:00','2026-06-12 16:45:00'),
  ('MR005','TBCT025','USR-KH006','rejected','medium','Router không thuộc phạm vi bảo trì do khách tự thay adapter khác.', 'Thiết bị dùng sai phụ kiện ngoài biên bản bàn giao',NULL,'USR-MANAGER',NULL,'2026-06-11 13:20:00','2026-06-11 14:00:00')
  ''',
  '''
  INSERT OR IGNORE INTO AppMaintenanceTasks
  (Id,RequestId,Status,Description,Result,Notes,TechnicianId,Cost,CompletionDate,Progress,CreatedAt,UpdatedAt) VALUES
  ('TASK-MR002','MR002','pending','Kiểm tra laptop khởi động chậm',NULL,NULL,'USR-TECH',NULL,NULL,0,'2026-06-14 11:05:00','2026-06-14 11:05:00'),
  ('TASK-MR003','MR003','in_progress','Kiểm tra lỗi nguồn laptop','Đang kiểm tra adapter và pin','Ưu tiên xử lý trước buổi học chiều','USR-TECH-NV004',0,NULL,45,'2026-06-13 14:35:00','2026-06-13 15:10:00'),
  ('TASK-MR004','MR004','completed','Vệ sinh và kiểm tra camera','Đã vệ sinh ống kính, hình ảnh ổn định','Vỏ ngoài trầy nhẹ không ảnh hưởng vận hành','USR-TECH-NV007',50000,'2026-06-12 16:45:00',100,'2026-06-12 09:00:00','2026-06-12 16:45:00')
  ''',
  '''
  INSERT OR IGNORE INTO AppStatusHistory
  (Id,RequestId,PreviousStatus,NewStatus,ChangedBy,Reason,CreatedAt) VALUES
  ('HIS-MR001-01','MR001','new','pending','USR-CUSTOMER','Khách hàng tạo yêu cầu bảo trì','2026-06-15 08:30:00'),
  ('HIS-MR002-01','MR002','new','pending','USR-KH002','Khách hàng tạo yêu cầu bảo trì','2026-06-14 10:15:00'),
  ('HIS-MR002-02','MR002','pending','approved','USR-MANAGER','Quản lý xác nhận yêu cầu hợp lệ','2026-06-14 11:00:00'),
  ('HIS-MR003-01','MR003','pending','approved','USR-MANAGER','Duyệt xử lý khẩn cấp','2026-06-13 10:00:00'),
  ('HIS-MR003-02','MR003','approved','in_progress','USR-TECH-NV004','Kỹ thuật viên bắt đầu sửa chữa','2026-06-13 14:30:00'),
  ('HIS-MR004-01','MR004','in_progress','completed','USR-TECH-NV007','Hoàn tất vệ sinh và kiểm tra camera','2026-06-12 16:45:00'),
  ('HIS-MR005-01','MR005','pending','rejected','USR-MANAGER','Thiết bị dùng sai phụ kiện ngoài biên bản bàn giao','2026-06-11 14:00:00')
  ''',
  '''
  INSERT OR IGNORE INTO AppNotifications
  (Id,UserId,Title,Message,RequestId,Type,IsRead,CreatedAt) VALUES
  ('NOT-MR002-01','USR-TECH','Bạn được phân công sửa chữa thiết bị','Kiểm tra laptop khởi động chậm cho THPT Lê Quý Đôn.','MR002','maintenance_assignment',0,'2026-06-14 11:05:00'),
  ('NOT-MR003-01','USR-TECH-NV004','Công việc bảo trì khẩn cấp','Laptop tắt nguồn khi trình chiếu, cần xử lý trong ngày.','MR003','maintenance_assignment',0,'2026-06-13 14:35:00'),
  ('NOT-MR004-01','USR-KH004','Thiết bị đã sửa chữa xong','Camera đã được vệ sinh và kiểm tra hình ảnh ổn định.','MR004','maintenance_completed',1,'2026-06-12 16:45:00'),
  ('NOT-MR005-01','USR-KH006','Yêu cầu bảo trì bị từ chối','Thiết bị dùng sai phụ kiện ngoài biên bản bàn giao.','MR005','maintenance_review',0,'2026-06-11 14:00:00')
  ''',
  '''
  INSERT OR IGNORE INTO AppUserPreferences
  (UserId,ThemeMode,Language,NotificationSettings) VALUES
  ('USR-ADMIN','system','vi','{"email":true,"push":true}'),
  ('USR-MANAGER','light','vi','{"email":true,"push":true}'),
  ('USR-TECH','system','vi','{"email":false,"push":true}'),
  ('USR-CUSTOMER','system','vi','{"email":true,"push":false}')
  ''',
];

const List<String> _externalImportStatements = [
  '''
  INSERT OR IGNORE INTO LoaiThietBi (MaLoai, TenLoai, MoTa)
  SELECT
    'EXT-' || MaLoai,
    TenLoai || ' (nguồn ngoài)',
    COALESCE(MoTa, 'Dữ liệu nhập từ quan_ly_muon_tra_thiet_bi.sqlite')
  FROM external_source.LoaiThietBi
  ''',
  '''
  INSERT OR IGNORE INTO NhaCungCap (MaNCC, TenNCC, DiaChi, SDT, Email)
  SELECT
    'EXT-' || MaNCC,
    TenNCC || ' (nguồn ngoài)',
    DiaChi,
    SDT,
    Email
  FROM external_source.NhaCungCap
  ''',
  '''
  INSERT OR IGNORE INTO NhanVien
    (MaNV, TenNV, ChucVu, QuyenHan, SDT, Email, MatKhau, TrangThai)
  SELECT
    'EXT-' || MaNV,
    TenNV,
    COALESCE(NULLIF(ChucVu, ''), 'Nhân viên'),
    CASE QuyenHan
      WHEN 'quan_tri' THEN 'Admin'
      WHEN 'quan_ly' THEN 'Quản lý'
      ELSE 'Nhân viên'
    END,
    NULL,
    'ext-' || lower(MaNV) || '@external.local',
    '123456',
    'Đang làm việc'
  FROM external_source.NhanVien
  ''',
  '''
  INSERT OR IGNORE INTO KhachHang
    (MaKH, HoTen, SDT, Email, CCCD, DiaChi, CongNoHienTai, TrangThai)
  SELECT
    'EXT-' || MaKH,
    HoTen,
    SDT,
    Email,
    CCCD,
    DiaChi,
    CongNo,
    'Hoạt động'
  FROM external_source.KhachHang
  ''',
  '''
  INSERT OR IGNORE INTO ThietBi
    (MaTB, TenTB, DonGiaThue, SoLuongTong, SoLuongKhaDung,
     MoTaKyThuat, HinhAnh, MaLoai, MaNCC, TrangThai)
  SELECT
    'EXT-' || MaTB,
    TenTB,
    DonGiaThue,
    SoLuongTong,
    SoLuongKhaDung,
    MoTaThuat,
    NULLIF(HinhAnh, ''),
    'EXT-' || MaLoai,
    'EXT-' || MaNCC,
    CASE TrangThai
      WHEN 'hong' THEN 'Thanh lý'
      WHEN 'ngung_su_dung' THEN 'Ngừng cho thuê'
      ELSE 'Đang kinh doanh'
    END
  FROM external_source.ThietBi
  ''',
  '''
  INSERT OR IGNORE INTO ThietBiChiTiet
    (MaTBCT, SoSeri, NgayNhap, TinhTrang, TrangThai, MaTB, GhiChu)
  WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM seq WHERE n < 200
  )
  SELECT
    'EXT-' || tb.MaTB || '-' || printf('%03d', seq.n),
    'EXT-' || tb.MaTB || '-' || printf('%03d', seq.n),
    date('now'),
    'Tốt',
    CASE tb.TrangThai
      WHEN 'dang_muon' THEN 'Đang mượn'
      WHEN 'bao_tri' THEN 'Đang bảo trì'
      WHEN 'hong' THEN 'Hỏng'
      WHEN 'ngung_su_dung' THEN 'Thanh lý'
      ELSE 'Có sẵn'
    END,
    'EXT-' || tb.MaTB,
    'Tự tạo từ số lượng tổng của database nguồn'
  FROM external_source.ThietBi tb
  JOIN seq ON seq.n <= tb.SoLuongTong
  ''',
  '''
  INSERT OR IGNORE INTO AppUsers
    (Id, Email, Phone, FullName, RoleId, UnitId, PasswordSalt,
     PasswordHash, IsActive, MaNV, MaKH)
  SELECT
    'EXT-USR-' || MaNV,
    'ext-' || lower(MaNV) || '@external.local',
    NULL,
    TenNV,
    CASE QuyenHan
      WHEN 'quan_tri' THEN 'admin'
      WHEN 'quan_ly' THEN 'unit_manager'
      ELSE 'company_staff'
    END,
    'UNIT01',
    'EXT-USR-' || MaNV,
    '123456',
    1,
    'EXT-' || MaNV,
    NULL
  FROM external_source.NhanVien
  ''',
  '''
  INSERT OR IGNORE INTO AppUsers
    (Id, Email, Phone, FullName, RoleId, UnitId, PasswordSalt,
     PasswordHash, IsActive, MaNV, MaKH)
  SELECT
    'EXT-USR-' || MaKH,
    Email,
    SDT,
    HoTen,
    'requester',
    'UNIT-KH',
    'EXT-USR-' || MaKH,
    '123456',
    1,
    NULL,
    'EXT-' || MaKH
  FROM external_source.KhachHang
  ''',
  '''
  INSERT OR IGNORE INTO YeuCauMuon
    (MaYC, NgayYeuCau, NgayBatDau, NgayDuKien, MucDichSuDung,
     TrangThaiYeuCau, LyDoTuChoi, MaKH, MaNV, NgayDuyet)
  SELECT
    'EXT-' || MaYCM,
    NgayYeuCau,
    NgayBatDau,
    NgayTraDuKien,
    COALESCE(NULLIF(MucDichSuDung, ''), 'Nhập từ database nguồn'),
    CASE TrangThaiYeuCau
      WHEN 'da_duyet' THEN 'Đã duyệt'
      WHEN 'tu_choi' THEN 'Từ chối'
      WHEN 'da_lap_phieu' THEN 'Đã lập phiếu'
      WHEN 'huy' THEN 'Đã hủy'
      ELSE 'Chờ duyệt'
    END,
    LyDoTuChoi,
    'EXT-' || MaKH,
    CASE WHEN MaNV IS NULL THEN NULL ELSE 'EXT-' || MaNV END,
    NULL
  FROM external_source.YeuCauMuon
  ''',
  '''
  INSERT OR IGNORE INTO PhieuMuon
    (MaPM, NgayMuon, NgayTraDuKien, NgayTraThucTe, TongTien,
     TrangThai, MaKH, MaNV, MaYC, GhiChu)
  SELECT
    'EXT-' || MaPM,
    NgayMuon,
    NgayTraDuKien,
    NgayTraThucTe,
    TongTien,
    CASE TrangThai
      WHEN 'da_tra' THEN 'Đã trả'
      WHEN 'qua_han' THEN 'Quá hạn'
      WHEN 'huy' THEN 'Đã hủy'
      ELSE 'Đang mượn'
    END,
    'EXT-' || MaKH,
    CASE WHEN MaNV IS NULL THEN 'EXT-NV002' ELSE 'EXT-' || MaNV END,
    CASE WHEN MaYCM IS NULL THEN NULL ELSE 'EXT-' || MaYCM END,
    'Nhập từ database nguồn'
  FROM external_source.PhieuMuon
  ''',
  '''
  INSERT OR IGNORE INTO ChiTietPM
    (MaCTPM, MaPM, MaTBCT, SoLuong, DonGiaTaiThoiDiem,
     TinhTrangKhiGiao, TinhTrangKhiTra, PhiBoiThuong)
  SELECT
    'EXT-' || MaPM || '-' || MaTB,
    'EXT-' || MaPM,
    'EXT-' || MaTB || '-001',
    SoLuong,
    DonGiaTaiThoiDiem,
    COALESCE(TinhTrangKhiGiao, 'Theo biên bản nguồn'),
    TinhTrangKhiTra,
    PhiBoiThuong
  FROM external_source.ChiTietPM
  ''',
  '''
  INSERT OR IGNORE INTO BaoTri
    (MaBT, NgayYeuCau, MoTaSuCo, MucDoHuHong, TrangThai,
     KetQuaXuLy, MaTBCT, MaKH, MaNV, NgayHoanThanh, ChiPhi)
  SELECT
    'EXT-' || MaBT,
    NgayYeuCau,
    MoTaSuCo,
    CASE MucDoHuHong
      WHEN 'trung_binh' THEN 'Trung bình'
      WHEN 'nang' THEN 'Nặng'
      ELSE 'Nhẹ'
    END,
    CASE TrangThai
      WHEN 'dang_xu_ly' THEN 'Đang xử lý'
      WHEN 'da_xu_ly' THEN 'Hoàn thành'
      WHEN 'huy' THEN 'Từ chối'
      ELSE 'Chờ tiếp nhận'
    END,
    KetQuaXuLy,
    'EXT-' || MaTB || '-001',
    CASE WHEN MaKH IS NULL THEN NULL ELSE 'EXT-' || MaKH END,
    CASE WHEN MaNV IS NULL THEN NULL ELSE 'EXT-' || MaNV END,
    NULL,
    0
  FROM external_source.BaoTri
  ''',
  '''
  INSERT OR IGNORE INTO PhuPhiViPham
    (MaPP, LoaiViPham, MoTa, SoTien, NgayGhiNhan, TrangThaiXL, MaPM)
  SELECT
    'EXT-' || MaPVP,
    'Khác',
    COALESCE(MoTa, LoaiViPham),
    SoTienPhat,
    NgayGhiNhan,
    CASE TrangThaiXuLy
      WHEN 'da_xu_ly' THEN 'Đã thu phí'
      WHEN 'huy' THEN 'Đã hủy'
      ELSE 'Chưa xử lý'
    END,
    'EXT-' || MaPM
  FROM external_source.PhieuViPham
  ''',
  '''
  INSERT OR IGNORE INTO ThanhToan
    (MaTT, NgayThanhToan, SoTien, PhuongThuc, LoaiThanhToan,
     TrangThai, MaPM, GhiChu)
  SELECT
    'EXT-' || MaTT,
    NgayThanhToan,
    SoTien,
    CASE PhuongThuc
      WHEN 'chuyen_khoan' THEN 'Chuyển khoản'
      WHEN 'the' THEN 'Thẻ'
      WHEN 'vi_dien_tu' THEN 'Ví điện tử'
      ELSE 'Tiền mặt'
    END,
    CASE LoaiThanhToan
      WHEN 'tien_phat' THEN 'Phụ phí'
      WHEN 'boi_thuong' THEN 'Bồi thường'
      WHEN 'dat_coc' THEN 'Đặt cọc'
      ELSE 'Tiền thuê'
    END,
    CASE TrangThai
      WHEN 'cho_thanh_toan' THEN 'Chờ thanh toán'
      WHEN 'that_bai' THEN 'Thất bại'
      WHEN 'huy' THEN 'Thất bại'
      ELSE 'Đã thanh toán'
    END,
    'EXT-' || MaPM,
    'Nhập từ database nguồn'
  FROM external_source.ThanhToan
  ''',
  '''
  INSERT OR IGNORE INTO GiaHanMuon
    (MaGH, NgayYeuCau, NgayTraCu, NgayTraMoi, TrangThaiGiaHan,
     LyDoGiaHan, LyDoTuChoi, MaPM, MaNV, NgayDuyet)
  SELECT
    'EXT-' || MaGH,
    NgayYeuCau,
    NgayTraCu,
    NgayTraMoi,
    CASE TrangThaiGiaHan
      WHEN 'da_duyet' THEN 'Đã duyệt'
      WHEN 'tu_choi' THEN 'Từ chối'
      WHEN 'huy' THEN 'Đã hủy'
      ELSE 'Chờ duyệt'
    END,
    COALESCE(NULLIF(LyDoGiaHan, ''), 'Nhập từ database nguồn'),
    NULL,
    'EXT-' || MaPM,
    CASE WHEN MaNV IS NULL THEN NULL ELSE 'EXT-' || MaNV END,
    NULL
  FROM external_source.GiaHanMuon
  ''',
  '''
  INSERT OR IGNORE INTO BaoCao
    (MaBC, LoaiBaoCao, TuNgay, DenNgay, NgayLap, NoiDungTongHop, MaNV)
  SELECT
    'EXT-' || MaBC,
    CASE LoaiBaoCao
      WHEN 'thiet_bi' THEN 'Thiết bị'
      WHEN 'doanh_thu' THEN 'Doanh thu'
      WHEN 'bao_tri' THEN 'Bảo trì'
      WHEN 'khach_hang' THEN 'Khách hàng'
      ELSE 'Tổng hợp'
    END,
    TuNgay,
    DenNgay,
    NgayLap,
    COALESCE(NULLIF(NoiDungTongLap, ''), 'Báo cáo nhập từ database nguồn'),
    'EXT-' || MaNV
  FROM external_source.BaoCao
  ''',
];

const List<String> _schemaStatements = [
  '''
  CREATE TABLE IF NOT EXISTS LoaiThietBi (
    MaLoai TEXT PRIMARY KEY, TenLoai TEXT NOT NULL UNIQUE, MoTa TEXT,
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''',
  '''
  CREATE TABLE IF NOT EXISTS NhaCungCap (
    MaNCC TEXT PRIMARY KEY, TenNCC TEXT NOT NULL, DiaChi TEXT, SDT TEXT,
    Email TEXT, CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''',
  '''
  CREATE TABLE IF NOT EXISTS NhanVien (
    MaNV TEXT PRIMARY KEY, TenNV TEXT NOT NULL, ChucVu TEXT NOT NULL,
    QuyenHan TEXT NOT NULL, SDT TEXT, Email TEXT UNIQUE,
    MatKhau TEXT NOT NULL DEFAULT '123456',
    TrangThai TEXT NOT NULL DEFAULT 'Đang làm việc',
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''',
  '''
  CREATE TABLE IF NOT EXISTS KhachHang (
    MaKH TEXT PRIMARY KEY, HoTen TEXT NOT NULL, SDT TEXT, Email TEXT UNIQUE,
    CCCD TEXT UNIQUE, DiaChi TEXT, CongNoHienTai REAL NOT NULL DEFAULT 0,
    TrangThai TEXT NOT NULL DEFAULT 'Hoạt động',
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''',
  '''
  CREATE TABLE IF NOT EXISTS ThietBi (
    MaTB TEXT PRIMARY KEY, TenTB TEXT NOT NULL, DonGiaThue REAL NOT NULL,
    SoLuongTong INTEGER NOT NULL, SoLuongKhaDung INTEGER NOT NULL,
    MoTaKyThuat TEXT, HinhAnh TEXT, MaLoai TEXT NOT NULL, MaNCC TEXT NOT NULL,
    TrangThai TEXT NOT NULL DEFAULT 'Đang kinh doanh',
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (MaLoai) REFERENCES LoaiThietBi(MaLoai),
    FOREIGN KEY (MaNCC) REFERENCES NhaCungCap(MaNCC)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS ThietBiChiTiet (
    MaTBCT TEXT PRIMARY KEY, SoSeri TEXT NOT NULL UNIQUE, NgayNhap TEXT NOT NULL,
    TinhTrang TEXT NOT NULL DEFAULT 'Tốt',
    TrangThai TEXT NOT NULL DEFAULT 'Có sẵn', MaTB TEXT NOT NULL, GhiChu TEXT,
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (MaTB) REFERENCES ThietBi(MaTB)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS YeuCauMuon (
    MaYC TEXT PRIMARY KEY, NgayYeuCau TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    NgayBatDau TEXT NOT NULL, NgayDuKien TEXT NOT NULL,
    MucDichSuDung TEXT NOT NULL,
    TrangThaiYeuCau TEXT NOT NULL DEFAULT 'Chờ duyệt', LyDoTuChoi TEXT,
    MaKH TEXT NOT NULL, MaNV TEXT, NgayDuyet TEXT,
    FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH),
    FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS PhieuMuon (
    MaPM TEXT PRIMARY KEY, NgayMuon TEXT NOT NULL, NgayTraDuKien TEXT NOT NULL,
    NgayTraThucTe TEXT, TongTien REAL NOT NULL DEFAULT 0,
    TrangThai TEXT NOT NULL DEFAULT 'Đang mượn', MaKH TEXT NOT NULL,
    MaNV TEXT NOT NULL, MaYC TEXT UNIQUE, GhiChu TEXT,
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH),
    FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV),
    FOREIGN KEY (MaYC) REFERENCES YeuCauMuon(MaYC)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS ChiTietPM (
    MaCTPM TEXT PRIMARY KEY, MaPM TEXT NOT NULL, MaTBCT TEXT NOT NULL,
    SoLuong INTEGER NOT NULL DEFAULT 1, DonGiaTaiThoiDiem REAL NOT NULL,
    TinhTrangKhiGiao TEXT NOT NULL, TinhTrangKhiTra TEXT,
    PhiBoiThuong REAL NOT NULL DEFAULT 0, UNIQUE (MaPM, MaTBCT),
    FOREIGN KEY (MaPM) REFERENCES PhieuMuon(MaPM) ON DELETE CASCADE,
    FOREIGN KEY (MaTBCT) REFERENCES ThietBiChiTiet(MaTBCT)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS ThanhToan (
    MaTT TEXT PRIMARY KEY, NgayThanhToan TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    SoTien REAL NOT NULL, PhuongThuc TEXT NOT NULL, LoaiThanhToan TEXT NOT NULL,
    TrangThai TEXT NOT NULL DEFAULT 'Chờ thanh toán', MaPM TEXT NOT NULL,
    GhiChu TEXT,
    FOREIGN KEY (MaPM) REFERENCES PhieuMuon(MaPM) ON DELETE CASCADE
  )''',
  '''
  CREATE TABLE IF NOT EXISTS GiaHanMuon (
    MaGH TEXT PRIMARY KEY, NgayYeuCau TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    NgayTraCu TEXT NOT NULL, NgayTraMoi TEXT NOT NULL,
    TrangThaiGiaHan TEXT NOT NULL DEFAULT 'Chờ duyệt',
    LyDoGiaHan TEXT NOT NULL, LyDoTuChoi TEXT, MaPM TEXT NOT NULL,
    MaNV TEXT, NgayDuyet TEXT,
    FOREIGN KEY (MaPM) REFERENCES PhieuMuon(MaPM) ON DELETE CASCADE,
    FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS PhuPhiViPham (
    MaPP TEXT PRIMARY KEY, LoaiViPham TEXT NOT NULL, MoTa TEXT,
    SoTien REAL NOT NULL, NgayGhiNhan TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    TrangThaiXL TEXT NOT NULL DEFAULT 'Chưa xử lý', MaPM TEXT NOT NULL,
    FOREIGN KEY (MaPM) REFERENCES PhieuMuon(MaPM) ON DELETE CASCADE
  )''',
  '''
  CREATE TABLE IF NOT EXISTS BaoTri (
    MaBT TEXT PRIMARY KEY, NgayYeuCau TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    MoTaSuCo TEXT NOT NULL, MucDoHuHong TEXT NOT NULL,
    TrangThai TEXT NOT NULL DEFAULT 'Chờ tiếp nhận', KetQuaXuLy TEXT,
    MaTBCT TEXT NOT NULL, MaKH TEXT, MaNV TEXT, NgayHoanThanh TEXT,
    ChiPhi REAL NOT NULL DEFAULT 0,
    FOREIGN KEY (MaTBCT) REFERENCES ThietBiChiTiet(MaTBCT),
    FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH),
    FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS BaoCao (
    MaBC TEXT PRIMARY KEY, LoaiBaoCao TEXT NOT NULL, TuNgay TEXT NOT NULL,
    DenNgay TEXT NOT NULL, NgayLap TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    NoiDungTongHop TEXT NOT NULL, MaNV TEXT NOT NULL,
    FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS AppUnits (
    Id TEXT PRIMARY KEY, Name TEXT NOT NULL, Address TEXT, Phone TEXT,
    Email TEXT, CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  )''',
  '''
  CREATE TABLE IF NOT EXISTS AppUsers (
    Id TEXT PRIMARY KEY, Email TEXT UNIQUE, Phone TEXT UNIQUE,
    FullName TEXT NOT NULL, Avatar TEXT, RoleId TEXT NOT NULL,
    UnitId TEXT NOT NULL, PasswordSalt TEXT NOT NULL, PasswordHash TEXT NOT NULL,
    IsActive INTEGER NOT NULL DEFAULT 1,
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, MaNV TEXT, MaKH TEXT,
    FOREIGN KEY (UnitId) REFERENCES AppUnits(Id),
    FOREIGN KEY (MaNV) REFERENCES NhanVien(MaNV),
    FOREIGN KEY (MaKH) REFERENCES KhachHang(MaKH)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS AppSessions (
    Token TEXT PRIMARY KEY, UserId TEXT NOT NULL, ExpiresAt TEXT NOT NULL,
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (UserId) REFERENCES AppUsers(Id) ON DELETE CASCADE
  )''',
  '''
  CREATE TABLE IF NOT EXISTS AppMaintenanceRequests (
    Id TEXT PRIMARY KEY, DeviceId TEXT NOT NULL, RequesterId TEXT NOT NULL,
    Status TEXT NOT NULL DEFAULT 'pending', Priority TEXT NOT NULL,
    Description TEXT NOT NULL, AttachmentPath TEXT, RejectionReason TEXT,
    TechnicianId TEXT, ApproverId TEXT, CompletionDate TEXT,
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (DeviceId) REFERENCES ThietBiChiTiet(MaTBCT),
    FOREIGN KEY (RequesterId) REFERENCES AppUsers(Id),
    FOREIGN KEY (TechnicianId) REFERENCES AppUsers(Id),
    FOREIGN KEY (ApproverId) REFERENCES AppUsers(Id)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS AppStatusHistory (
    Id TEXT PRIMARY KEY, RequestId TEXT NOT NULL, PreviousStatus TEXT NOT NULL,
    NewStatus TEXT NOT NULL, ChangedBy TEXT NOT NULL, Reason TEXT,
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (RequestId) REFERENCES AppMaintenanceRequests(Id)
      ON DELETE CASCADE,
    FOREIGN KEY (ChangedBy) REFERENCES AppUsers(Id)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS AppMaintenanceTasks (
    Id TEXT PRIMARY KEY, RequestId TEXT NOT NULL,
    Status TEXT NOT NULL DEFAULT 'pending', Description TEXT NOT NULL,
    Result TEXT, Notes TEXT, TechnicianId TEXT, Cost REAL,
    CompletionDate TEXT, Progress INTEGER NOT NULL DEFAULT 0,
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (RequestId) REFERENCES AppMaintenanceRequests(Id)
      ON DELETE CASCADE,
    FOREIGN KEY (TechnicianId) REFERENCES AppUsers(Id)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS AppNotifications (
    Id TEXT PRIMARY KEY, UserId TEXT NOT NULL, Title TEXT NOT NULL,
    Message TEXT NOT NULL, RequestId TEXT, Type TEXT NOT NULL,
    IsRead INTEGER NOT NULL DEFAULT 0,
    CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (UserId) REFERENCES AppUsers(Id) ON DELETE CASCADE,
    FOREIGN KEY (RequestId) REFERENCES AppMaintenanceRequests(Id)
  )''',
  '''
  CREATE TABLE IF NOT EXISTS AppUserPreferences (
    UserId TEXT PRIMARY KEY, ThemeMode TEXT NOT NULL DEFAULT 'system',
    Language TEXT NOT NULL DEFAULT 'system',
    NotificationSettings TEXT NOT NULL DEFAULT '{}',
    UpdatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (UserId) REFERENCES AppUsers(Id) ON DELETE CASCADE
  )''',
  'CREATE INDEX IF NOT EXISTS IX_ThietBi_MaLoai ON ThietBi(MaLoai)',
  'CREATE INDEX IF NOT EXISTS IX_ThietBiChiTiet_MaTB ON ThietBiChiTiet(MaTB)',
  'CREATE INDEX IF NOT EXISTS IX_PhieuMuon_MaKH ON PhieuMuon(MaKH)',
  'CREATE INDEX IF NOT EXISTS IX_ThanhToan_MaPM ON ThanhToan(MaPM)',
  'CREATE INDEX IF NOT EXISTS IX_BaoTri_MaTBCT ON BaoTri(MaTBCT)',
  '''
  CREATE VIEW IF NOT EXISTS vw_DanhSachPhieuMuon AS
  SELECT pm.MaPM, pm.NgayMuon, pm.NgayTraDuKien, pm.NgayTraThucTe,
         pm.TongTien, pm.TrangThai, kh.HoTen AS KhachHang,
         nv.TenNV AS NhanVienLapPhieu, yc.MucDichSuDung
  FROM PhieuMuon pm
  JOIN KhachHang kh ON pm.MaKH = kh.MaKH
  JOIN NhanVien nv ON pm.MaNV = nv.MaNV
  LEFT JOIN YeuCauMuon yc ON pm.MaYC = yc.MaYC
  ''',
  '''
  CREATE VIEW IF NOT EXISTS vw_TinhTrangThietBi AS
  SELECT tb.MaTB, tb.TenTB, ltb.TenLoai, ncc.TenNCC, tb.SoLuongTong,
         tb.SoLuongKhaDung,
         SUM(CASE WHEN tbct.TrangThai = 'Có sẵn' THEN 1 ELSE 0 END) SoLuongCoSan,
         SUM(CASE WHEN tbct.TrangThai = 'Đang mượn' THEN 1 ELSE 0 END) SoLuongDangMuon,
         SUM(CASE WHEN tbct.TrangThai = 'Đang bảo trì' THEN 1 ELSE 0 END) SoLuongDangBaoTri
  FROM ThietBi tb
  JOIN LoaiThietBi ltb ON tb.MaLoai = ltb.MaLoai
  JOIN NhaCungCap ncc ON tb.MaNCC = ncc.MaNCC
  LEFT JOIN ThietBiChiTiet tbct ON tb.MaTB = tbct.MaTB
  GROUP BY tb.MaTB, tb.TenTB, ltb.TenLoai, ncc.TenNCC,
           tb.SoLuongTong, tb.SoLuongKhaDung
  ''',
  '''
  CREATE VIEW IF NOT EXISTS vw_DoanhThuThanhToan AS
  SELECT date(NgayThanhToan) Ngay, LoaiThanhToan, TrangThai,
         SUM(SoTien) TongSoTien
  FROM ThanhToan
  GROUP BY date(NgayThanhToan), LoaiThanhToan, TrangThai
  ''',
  '''
  CREATE VIEW IF NOT EXISTS vw_LichSuBaoTri AS
  SELECT bt.MaBT, bt.NgayYeuCau, tb.TenTB, tbct.SoSeri,
         kh.HoTen KhachHang, nv.TenNV NhanVienXuLy,
         bt.MucDoHuHong, bt.TrangThai, bt.KetQuaXuLy, bt.ChiPhi
  FROM BaoTri bt
  JOIN ThietBiChiTiet tbct ON bt.MaTBCT = tbct.MaTBCT
  JOIN ThietBi tb ON tbct.MaTB = tb.MaTB
  LEFT JOIN KhachHang kh ON bt.MaKH = kh.MaKH
  LEFT JOIN NhanVien nv ON bt.MaNV = nv.MaNV
  ''',
  '''
  CREATE VIEW IF NOT EXISTS vw_TaiKhoanDangNhap AS
  SELECT Id, Email, Phone, FullName, RoleId, MaNV, MaKH, IsActive,
         CreatedAt, UpdatedAt
  FROM AppUsers
  ''',
];

const List<String> _seedStatements = [
  '''
  INSERT INTO LoaiThietBi (MaLoai, TenLoai, MoTa) VALUES
  ('LTB001','Máy chiếu','Thiết bị trình chiếu phục vụ lớp học, hội họp'),
  ('LTB002','Laptop','Máy tính xách tay dùng cho giảng dạy, làm việc'),
  ('LTB003','TV','Tivi/Smart TV phục vụ trình chiếu'),
  ('LTB004','Loa','Thiết bị âm thanh'),
  ('LTB005','Micro','Micro có dây/không dây'),
  ('LTB006','Máy in','Thiết bị in ấn văn phòng'),
  ('LTB007','Máy photocopy','Thiết bị sao chụp tài liệu'),
  ('LTB008','Camera','Thiết bị camera giám sát'),
  ('LTB009','Màn hình LED','Màn hình hiển thị sự kiện'),
  ('LTB010','Bộ phát Wifi','Thiết bị mạng không dây'),
  ('LTB011','Máy tính để bàn','Máy tính desktop'),
  ('LTB012','Máy quét mã vạch','Thiết bị quét mã vạch'),
  ('LTB013','Máy chấm công','Thiết bị chấm công nhân sự'),
  ('LTB014','Router','Thiết bị định tuyến mạng'),
  ('LTB015','Switch mạng','Thiết bị chuyển mạch mạng')
  ''',
  '''
  INSERT INTO NhaCungCap (MaNCC, TenNCC, DiaChi, SDT, Email) VALUES
  ('NCC001','Công ty Thiết bị Giáo dục An Phát','12 Nguyễn Văn Cừ, Quận 5, TP.HCM','0901111222','anphat@vendor.vn'),
  ('NCC002','Công ty Công nghệ Minh Phát','45 Lê Duẩn, Quận 1, TP.HCM','0902222333','minhphat@vendor.vn'),
  ('NCC003','Công ty Âm thanh Ánh Sáng Sao Việt','88 Điện Biên Phủ, Bình Thạnh, TP.HCM','0903333444','saoviet@vendor.vn'),
  ('NCC004','Công ty Camera HikTech','23 Hoàng Văn Thụ, Tân Bình, TP.HCM','0904444555','hiktech@vendor.vn'),
  ('NCC005','Công ty Máy văn phòng Phú Gia','77 Trần Hưng Đạo, Quận 1, TP.HCM','0905555666','phugia@vendor.vn'),
  ('NCC006','Công ty Mạng và Hạ tầng NetPro','19 Võ Văn Kiệt, Quận 6, TP.HCM','0906666777','netpro@vendor.vn'),
  ('NCC-APP','Nhà cung cấp mặc định',NULL,NULL,NULL)
  ''',
  '''
  INSERT INTO NhanVien
  (MaNV, TenNV, ChucVu, QuyenHan, SDT, Email, MatKhau, TrangThai) VALUES
  ('NV001','Lý Minh Tâm','Quản lý thiết bị','Quản lý','0901000009','tam@thietbi.vn','123456','Đang làm việc'),
  ('NV002','Phan Gia Bảo','Nhân viên lập phiếu','Nhân viên','0901000010','bao@thietbi.vn','123456','Đang làm việc'),
  ('NV003','Nguyễn Nhật Minh','Kỹ thuật viên','Kỹ thuật','0901000011','minh@thietbi.vn','123456','Đang làm việc'),
  ('NV004','Hoàng Anh Tuấn','Kỹ thuật viên','Kỹ thuật','0901000012','tuan@thietbi.vn','123456','Đang làm việc'),
  ('NV005','Võ Minh Khôi','Kế toán','Kế toán','0901000013','khoi@thietbi.vn','123456','Đang làm việc'),
  ('NV006','Quản lý hệ thống','Admin hệ thống','Admin','0901000014','admin@thietbi.vn','123456','Đang làm việc'),
  ('NV007','Trần Thị Linh','Kỹ thuật viên','Kỹ thuật','0901000015','linh@thietbi.vn','123456','Đang làm việc'),
  ('NV008','Trần Viên','Quản lý thiết bị','Quản lý','0901000016','vien@thietbi.vn','123456','Đang làm việc')
  ''',
  '''
  INSERT INTO KhachHang
  (MaKH, HoTen, SDT, Email, CCCD, DiaChi, CongNoHienTai, TrangThai) VALUES
  ('KH001','THPT Nguyễn Du','0901111111','nguyendu@gmail.com','030100000001','TP.HCM',0,'Hoạt động'),
  ('KH002','THPT Lê Quý Đôn','0902222222','lequydon@gmail.com','030100000002','Đà Nẵng',250000,'Hoạt động'),
  ('KH003','THCS Trần Hưng Đạo','0903333333','thcstranhungdao@gmail.com','030100000003','Cần Thơ',0,'Hoạt động'),
  ('KH004','Công ty ABC','0904444444','abc@gmail.com','030100000004','Hà Nội',500000,'Hoạt động'),
  ('KH005','Công ty Minh Phát','0905555555','minhphat@gmail.com','030100000005','TP.HCM',0,'Hoạt động'),
  ('KH006','Trung tâm Anh ngữ Future','0906666666','future@gmail.com','030100000006','Bình Dương',0,'Hoạt động'),
  ('KH007','Trung tâm Tin học Sao Việt','0907777777','saoviet@gmail.com','030100000007','Biên Hòa',150000,'Hoạt động'),
  ('KH008','Quán Cafe Melody','0908888888','melody@gmail.com','030100000008','Vũng Tàu',0,'Hoạt động'),
  ('KH009','Nhà sách Tri Thức','0909999999','trithuc@gmail.com','030100000009','Long An',0,'Hoạt động'),
  ('KH010','Nguyễn Văn Tài','0911111111','vantai@gmail.com','030100000010','Tây Ninh',0,'Hoạt động')
  ''',
  '''
  INSERT INTO ThietBi
  (MaTB, TenTB, DonGiaThue, SoLuongTong, SoLuongKhaDung, MoTaKyThuat,
   HinhAnh, MaLoai, MaNCC, TrangThai) VALUES
  ('TB001','Máy chiếu Epson X1',180000,3,2,'Độ sáng 3600 lumens, HDMI/VGA','assets/images/projector1.png','LTB001','NCC001','Đang kinh doanh'),
  ('TB002','Máy chiếu Sony VPL',220000,2,2,'Full HD, 4000 lumens','assets/images/projector1.png','LTB001','NCC001','Đang kinh doanh'),
  ('TB003','Laptop Dell Inspiron',250000,3,1,'Core i5, RAM 8GB, SSD 256GB','assets/images/laptop1.png','LTB002','NCC002','Đang kinh doanh'),
  ('TB004','Laptop HP Probook',270000,2,1,'Core i5, RAM 16GB, SSD 512GB','assets/images/laptop1.png','LTB002','NCC002','Đang kinh doanh'),
  ('TB005','TV Samsung 55 inch',300000,2,2,'Smart TV 4K 55 inch',NULL,'LTB003','NCC002','Đang kinh doanh'),
  ('TB006','Loa JBL EON',200000,2,1,'Loa active công suất 500W',NULL,'LTB004','NCC003','Đang kinh doanh'),
  ('TB007','Micro Shure SM58',80000,5,4,'Micro dynamic vocal','assets/images/microphone1.png','LTB005','NCC003','Đang kinh doanh'),
  ('TB008','Máy in Canon LBP2900',150000,2,2,'Máy in laser trắng đen',NULL,'LTB006','NCC005','Đang kinh doanh'),
  ('TB009','Máy photocopy Ricoh',500000,1,0,'Máy photocopy văn phòng',NULL,'LTB007','NCC005','Đang kinh doanh'),
  ('TB010','Camera Hikvision',100000,4,3,'Camera IP 2MP','assets/images/camera1.png','LTB008','NCC004','Đang kinh doanh'),
  ('TB011','Màn hình LED LG',250000,2,2,'Màn hình LED 43 inch',NULL,'LTB009','NCC002','Đang kinh doanh'),
  ('TB012','Router TP-Link AX3000',120000,3,2,'Wifi 6, băng tần kép',NULL,'LTB014','NCC006','Đang kinh doanh'),
  ('TB013','Switch Cisco 24 Port',180000,2,2,'Switch 24 cổng Gigabit',NULL,'LTB015','NCC006','Đang kinh doanh'),
  ('TB014','Máy tính Dell Optiplex',230000,2,2,'Core i5, RAM 8GB, SSD 256GB',NULL,'LTB011','NCC002','Đang kinh doanh'),
  ('TB015','Máy chấm công Ronald Jack',100000,1,0,'Máy chấm công vân tay',NULL,'LTB013','NCC005','Đang kinh doanh')
  ''',
  '''
  INSERT INTO ThietBiChiTiet
  (MaTBCT,SoSeri,NgayNhap,TinhTrang,TrangThai,MaTB,GhiChu) VALUES
  ('TBCT001','EPS-X1-001','2025-01-10','Tốt','Đang mượn','TB001','Phòng A1'),
  ('TBCT002','EPS-X1-002','2025-01-10','Tốt','Có sẵn','TB001','Phòng A2'),
  ('TBCT003','EPS-X1-003','2025-01-10','Bình thường','Có sẵn','TB001','Kho'),
  ('TBCT004','SNY-VPL-001','2025-01-11','Tốt','Có sẵn','TB002','Kho'),
  ('TBCT005','SNY-VPL-002','2025-01-11','Tốt','Có sẵn','TB002','Kho'),
  ('TBCT006','DELL-INSP-001','2025-01-12','Bình thường','Đang bảo trì','TB003','Laptop giáo viên'),
  ('TBCT007','DELL-INSP-002','2025-01-12','Tốt','Đang mượn','TB003','Laptop giáo viên'),
  ('TBCT008','DELL-INSP-003','2025-01-12','Tốt','Có sẵn','TB003','Kho'),
  ('TBCT009','HP-PRO-001','2025-01-13','Tốt','Có sẵn','TB004','Phòng tin học'),
  ('TBCT010','HP-PRO-002','2025-01-13','Tốt','Đang mượn','TB004','Phòng tin học'),
  ('TBCT011','SS-TV-001','2025-01-14','Tốt','Có sẵn','TB005','Phòng họp'),
  ('TBCT012','SS-TV-002','2025-01-14','Tốt','Có sẵn','TB005','Kho'),
  ('TBCT013','JBL-EON-001','2025-01-15','Cũ','Đang bảo trì','TB006','Loa hội trường'),
  ('TBCT014','JBL-EON-002','2025-01-15','Tốt','Có sẵn','TB006','Kho'),
  ('TBCT015','SHURE-001','2025-01-16','Tốt','Đang mượn','TB007','Micro lớp học'),
  ('TBCT016','SHURE-002','2025-01-16','Tốt','Có sẵn','TB007','Kho'),
  ('TBCT017','SHURE-003','2025-01-16','Tốt','Có sẵn','TB007','Kho'),
  ('TBCT018','SHURE-004','2025-01-16','Tốt','Có sẵn','TB007','Kho'),
  ('TBCT019','CANON-001','2025-01-17','Tốt','Có sẵn','TB008','Phòng giáo vụ'),
  ('TBCT020','RICOH-001','2025-01-18','Bình thường','Đang bảo trì','TB009','Khu văn phòng'),
  ('TBCT021','HIK-001','2025-01-19','Tốt','Có sẵn','TB010','Camera an ninh'),
  ('TBCT022','HIK-002','2025-01-19','Tốt','Có sẵn','TB010','Camera an ninh'),
  ('TBCT023','HIK-003','2025-01-19','Tốt','Đang mượn','TB010','Camera an ninh'),
  ('TBCT024','LG-LED-001','2025-01-20','Tốt','Có sẵn','TB011','Phòng đa năng'),
  ('TBCT025','TPLINK-001','2025-01-21','Tốt','Đang mượn','TB012','Thiết bị mạng')
  ''',
  '''
  INSERT INTO YeuCauMuon
  (MaYC,NgayYeuCau,NgayBatDau,NgayDuKien,MucDichSuDung,TrangThaiYeuCau,
   LyDoTuChoi,MaKH,MaNV,NgayDuyet) VALUES
  ('YC001','2026-06-01 08:00:00','2026-06-03','2026-06-05','Mượn thiết bị phục vụ hội thảo chuyên đề','Đã lập phiếu',NULL,'KH001','NV001','2026-06-01 10:00:00'),
  ('YC002','2026-06-02 09:30:00','2026-06-06','2026-06-08','Mượn laptop và micro cho lớp tập huấn','Đã lập phiếu',NULL,'KH002','NV002','2026-06-02 11:00:00'),
  ('YC003','2026-06-03 14:00:00','2026-06-07','2026-06-10','Mượn camera phục vụ sự kiện','Đã lập phiếu',NULL,'KH004','NV001','2026-06-03 15:00:00'),
  ('YC004','2026-06-04 08:20:00','2026-06-12','2026-06-14','Mượn router để kiểm thử mạng','Đã duyệt',NULL,'KH006','NV002','2026-06-04 09:00:00'),
  ('YC005','2026-06-05 16:15:00','2026-06-09','2026-06-11','Mượn máy in cho văn phòng tạm','Chờ duyệt',NULL,'KH007',NULL,NULL),
  ('YC006','2026-06-06 10:45:00','2026-06-12','2026-06-18','Mượn TV trưng bày hội chợ','Từ chối','Khách hàng còn công nợ quá hạn','KH004','NV001','2026-06-06 13:00:00'),
  ('YC007','2026-06-07 07:50:00','2026-06-15','2026-06-17','Mượn loa phục vụ văn nghệ','Đã lập phiếu',NULL,'KH008','NV002','2026-06-07 09:00:00'),
  ('YC008','2026-06-08 13:20:00','2026-06-20','2026-06-22','Mượn máy chiếu phục vụ dạy học','Đã hủy',NULL,'KH010',NULL,NULL)
  ''',
  '''
  INSERT INTO PhieuMuon
  (MaPM,NgayMuon,NgayTraDuKien,NgayTraThucTe,TongTien,TrangThai,MaKH,MaNV,MaYC,GhiChu) VALUES
  ('PM001','2026-06-03','2026-06-05','2026-06-05',540000,'Đã trả','KH001','NV002','YC001','Trả đúng hạn'),
  ('PM002','2026-06-06','2026-06-08',NULL,660000,'Đang mượn','KH002','NV002','YC002','Đang sử dụng'),
  ('PM003','2026-06-07','2026-06-10','2026-06-12',300000,'Đã trả','KH004','NV001','YC003','Trả trễ 2 ngày'),
  ('PM004','2026-06-12','2026-06-14',NULL,240000,'Đang mượn','KH006','NV002','YC004','Mượn router'),
  ('PM005','2026-06-15','2026-06-17',NULL,400000,'Đang mượn','KH008','NV002','YC007','Mượn loa và micro'),
  ('PM006','2026-05-20','2026-05-22','2026-05-24',500000,'Đã trả','KH007','NV001',NULL,'Phiếu nhập thủ công')
  ''',
  '''
  INSERT INTO ChiTietPM
  (MaCTPM,MaPM,MaTBCT,SoLuong,DonGiaTaiThoiDiem,TinhTrangKhiGiao,TinhTrangKhiTra,PhiBoiThuong) VALUES
  ('CTPM001','PM001','TBCT001',1,180000,'Tốt, đầy đủ dây nguồn và HDMI','Tốt, đủ phụ kiện',0),
  ('CTPM002','PM001','TBCT015',1,80000,'Tốt, micro hoạt động bình thường','Tốt',0),
  ('CTPM003','PM002','TBCT007',1,250000,'Tốt, pin ổn định',NULL,0),
  ('CTPM004','PM002','TBCT010',1,270000,'Tốt, đã cài phần mềm học tập',NULL,0),
  ('CTPM005','PM002','TBCT015',1,80000,'Tốt',NULL,0),
  ('CTPM006','PM003','TBCT023',1,100000,'Tốt, camera hoạt động','Trầy nhẹ vỏ ngoài',50000),
  ('CTPM007','PM004','TBCT025',1,120000,'Tốt, đủ adapter',NULL,0),
  ('CTPM008','PM005','TBCT014',1,200000,'Tốt, loa hoạt động',NULL,0),
  ('CTPM009','PM005','TBCT016',1,80000,'Tốt',NULL,0),
  ('CTPM010','PM006','TBCT019',1,150000,'Tốt','Khay giấy bị kẹt nhẹ',100000)
  ''',
  '''
  INSERT INTO ThanhToan
  (MaTT,NgayThanhToan,SoTien,PhuongThuc,LoaiThanhToan,TrangThai,MaPM,GhiChu) VALUES
  ('TT001','2026-06-03 09:00:00',540000,'Chuyển khoản','Tiền thuê','Đã thanh toán','PM001','Thanh toán khi lập phiếu'),
  ('TT002','2026-06-06 10:00:00',660000,'Tiền mặt','Tiền thuê','Đã thanh toán','PM002','Đã thu đủ'),
  ('TT003','2026-06-12 15:30:00',300000,'Chuyển khoản','Tiền thuê','Đã thanh toán','PM003','Thanh toán tiền thuê'),
  ('TT004','2026-06-12 15:40:00',200000,'Tiền mặt','Phụ phí','Đã thanh toán','PM003','Thu phí trả trễ'),
  ('TT005','2026-06-12 08:30:00',240000,'Ví điện tử','Tiền thuê','Đã thanh toán','PM004','Thanh toán qua ví điện tử'),
  ('TT006','2026-06-15 09:00:00',400000,'Tiền mặt','Tiền thuê','Đã thanh toán','PM005','Thu tiền thuê ban đầu'),
  ('TT007','2026-05-24 16:00:00',100000,'Tiền mặt','Bồi thường','Đã thanh toán','PM006','Bồi thường kẹt khay giấy')
  ''',
  '''
  INSERT INTO GiaHanMuon
  (MaGH,NgayYeuCau,NgayTraCu,NgayTraMoi,TrangThaiGiaHan,LyDoGiaHan,LyDoTuChoi,MaPM,MaNV,NgayDuyet) VALUES
  ('GH001','2026-06-08 08:00:00','2026-06-08','2026-06-10','Đã duyệt','Cần thêm thời gian hoàn tất lớp tập huấn',NULL,'PM002','NV001','2026-06-08 09:00:00'),
  ('GH002','2026-06-13 10:00:00','2026-06-14','2026-06-16','Chờ duyệt','Kéo dài thời gian kiểm thử mạng',NULL,'PM004',NULL,NULL),
  ('GH003','2026-06-16 14:00:00','2026-06-17','2026-06-20','Từ chối','Muốn giữ thiết bị thêm 3 ngày','Thiết bị đã có lịch cho khách khác','PM005','NV002','2026-06-16 15:00:00')
  ''',
  '''
  INSERT INTO PhuPhiViPham
  (MaPP,LoaiViPham,MoTa,SoTien,NgayGhiNhan,TrangThaiXL,MaPM) VALUES
  ('PP001','Trễ hạn','Trả trễ 2 ngày so với ngày dự kiến',200000,'2026-06-12 15:00:00','Đã thu phí','PM003'),
  ('PP002','Hư hỏng','Camera bị trầy nhẹ vỏ ngoài',50000,'2026-06-12 15:10:00','Đã lập biên bản','PM003'),
  ('PP003','Hư hỏng','Máy in bị kẹt khay giấy khi trả',100000,'2026-05-24 15:40:00','Đã thu phí','PM006')
  ''',
  '''
  INSERT INTO BaoTri
  (MaBT,NgayYeuCau,MoTaSuCo,MucDoHuHong,TrangThai,KetQuaXuLy,MaTBCT,MaKH,MaNV,NgayHoanThanh,ChiPhi) VALUES
  ('BT001','2026-05-28 08:00:00','Laptop không lên nguồn','Nặng','Đang xử lý','Đang kiểm tra mainboard và adapter','TBCT006','KH001','NV003',NULL,0),
  ('BT002','2026-05-29 09:30:00','Loa bị rè tiếng khi mở âm lượng lớn','Trung bình','Đang xử lý','Đã vệ sinh cổng kết nối, chờ test lại','TBCT013','KH002','NV004',NULL,150000),
  ('BT003','2026-05-30 10:45:00','Máy photocopy kẹt giấy liên tục','Trung bình','Hoàn thành','Đã thay bộ kéo giấy','TBCT020','KH007','NV003','2026-05-31 16:00:00',500000),
  ('BT004','2026-06-01 14:00:00','Máy in bị kẹt khay giấy sau khi trả','Nhẹ','Hoàn thành','Đã vệ sinh và cân chỉnh khay giấy','TBCT019','KH007','NV004','2026-06-01 17:00:00',100000)
  ''',
  '''
  INSERT INTO BaoCao
  (MaBC,LoaiBaoCao,TuNgay,DenNgay,NgayLap,NoiDungTongHop,MaNV) VALUES
  ('BC001','Doanh thu','2026-06-01','2026-06-15','2026-06-15 17:00:00','Tổng hợp doanh thu thuê thiết bị và phụ phí nửa đầu tháng 06/2026.','NV005'),
  ('BC002','Thiết bị','2026-06-01','2026-06-15','2026-06-15 17:15:00','Tổng hợp số lượng thiết bị còn khả dụng, đang mượn, đang bảo trì.','NV001'),
  ('BC003','Bảo trì','2026-05-28','2026-06-15','2026-06-15 17:30:00','Tổng hợp các yêu cầu bảo trì đang xử lý và đã hoàn thành.','NV003'),
  ('BC004','Tổng hợp','2026-06-01','2026-06-30','2026-06-30 17:00:00','Báo cáo tổng hợp hoạt động mượn, trả, thanh toán, gia hạn và bảo trì.','NV001')
  ''',
  '''
  INSERT INTO AppUnits (Id,Name,Address,Phone,Email) VALUES
  ('UNIT01','Đơn vị quản lý thiết bị','TP. Hồ Chí Minh','0909000000','unit@thietbi.vn'),
  ('UNIT-KH','Nhóm khách hàng thuê thiết bị','TP. Hồ Chí Minh','0909000099','khachhang@thietbi.vn')
  ''',
  '''
  INSERT INTO AppUsers
  (Id,Email,Phone,FullName,RoleId,UnitId,PasswordSalt,PasswordHash,IsActive,MaNV,MaKH) VALUES
  ('USR-ADMIN','admin@thietbi.vn','0909000001','Quản trị hệ thống','admin','UNIT01','APP-USR-ADMIN','123456',1,'NV006',NULL),
  ('USR-MANAGER','manager@thietbi.vn','0909000011','Quản lý đơn vị','unit_manager','UNIT01','APP-USR-MANAGER','123456',1,'NV001',NULL),
  ('USR-STAFF','staff@thietbi.vn','0909000002','Nhân viên công ty','company_staff','UNIT01','APP-USR-STAFF','123456',1,'NV002',NULL),
  ('USR-TECH','tech@thietbi.vn','0909000003','Nguyễn Nhật Minh','technician','UNIT01','APP-USR-TECH','123456',1,'NV003',NULL),
  ('USR-TECH-NV004','tuan@thietbi.vn','0901000012','Hoàng Anh Tuấn','technician','UNIT01','APP-USR-TECH-NV004','123456',1,'NV004',NULL),
  ('USR-TECH-NV007','linh@thietbi.vn','0901000015','Trần Thị Linh','technician','UNIT01','APP-USR-TECH-NV007','123456',1,'NV007',NULL),
  ('USR-MANAGER-NV008','vien@thietbi.vn','0901000016','Trần Viên','unit_manager','UNIT01','APP-USR-MANAGER-NV008','123456',1,'NV008',NULL),
  ('USR-CUSTOMER','customer@thietbi.vn','0909000010','Khách hàng thuê thiết bị','requester','UNIT-KH','APP-USR-CUSTOMER','123456',1,NULL,'KH001')
  ''',
];
