import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? customerId;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.customerId,
  });
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  Future<AuthUser?> login({
    required String emailOrUsername,
    required String password,
    String? role,
  }) async {
    if (role == null) {
      return _loginAnyRole(emailOrUsername, password);
    }

    if (role == 'Khách hàng') {
      return _loginCustomer(emailOrUsername, password);
    }
    return _loginEmployee(emailOrUsername, password, role);
  }

  Future<AuthUser?> _loginAnyRole(String login, String password) async {
    return await _loginCustomer(login, password) ??
        await _loginTechnician(login, password) ??
        await _loginEmployee(login, password, 'Quản lý') ??
        await _loginEmployee(login, password, 'Nhân viên');
  }

  Future<AuthUser?> _loginCustomer(String login, String password) async {
    final db = await AppDatabase.instance.database;
    final keyword = login.trim();
    final rows = await db.rawQuery(
      '''
      SELECT Id, FullName, Email, MaKH
      FROM AppUsers
      WHERE IsActive = 1
        AND RoleId = 'requester'
        AND (lower(Email) = lower(?) OR Phone = ? OR lower(FullName) = lower(?))
        AND PasswordHash = ?
      LIMIT 1
      ''',
      [keyword, keyword, keyword, password],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return AuthUser(
      id: row['Id'] as String,
      name: row['FullName'] as String,
      email: row['Email'] as String? ?? '',
      role: 'Khách hàng',
      customerId: row['MaKH'] as String?,
    );
  }

  Future<AuthUser?> _loginEmployee(
    String login,
    String password,
    String role,
  ) async {
    if (role == 'Kỹ thuật viên') {
      return _loginTechnician(login, password);
    }

    final db = await AppDatabase.instance.database;
    final keyword = login.trim();
    final roleValues = switch (role) {
      'Quản lý' => const ['Quản lý', 'Admin'],
      _ => const ['Nhân viên', 'Kế toán'],
    };
    final appRoleValues = switch (role) {
      'Quản lý' => const ['unit_manager', 'admin'],
      _ => const ['company_staff', 'approver'],
    };
    final placeholders = List.filled(roleValues.length, '?').join(',');
    final appPlaceholders = List.filled(appRoleValues.length, '?').join(',');
    final rows = await db.rawQuery(
      '''
      SELECT employee.MaNV, employee.TenNV,
             COALESCE(app.Email, employee.Email) AS Email
      FROM NhanVien employee
      LEFT JOIN AppUsers app
        ON app.MaNV = employee.MaNV
       AND app.IsActive = 1
      WHERE employee.TrangThai = 'Đang làm việc'
        AND (
          (
            app.Id IS NOT NULL
            AND app.RoleId IN ($appPlaceholders)
            AND (lower(app.Email) = lower(?) OR app.Phone = ? OR lower(app.FullName) = lower(?))
            AND app.PasswordHash = ?
          )
          OR
          (
            employee.QuyenHan IN ($placeholders)
            AND (
              lower(employee.Email) = lower(?)
              OR lower(employee.TenNV) = lower(?)
              OR employee.MaNV = ?
            )
            AND employee.MatKhau = ?
          )
        )
      LIMIT 1
      ''',
      [
        ...appRoleValues,
        keyword,
        keyword,
        keyword,
        password,
        ...roleValues,
        keyword,
        keyword,
        keyword,
        password,
      ],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return AuthUser(
      id: row['MaNV'] as String,
      name: row['TenNV'] as String,
      email: row['Email'] as String? ?? '',
      role: role,
    );
  }

  Future<AuthUser?> _loginTechnician(String login, String password) async {
    final db = await AppDatabase.instance.database;
    final keyword = login.trim();
    final rows = await db.rawQuery(
      '''
      SELECT employee.MaNV, employee.TenNV,
             COALESCE(app.Email, employee.Email) AS Email
      FROM AppUsers app
      JOIN NhanVien employee ON employee.MaNV = app.MaNV
      WHERE app.IsActive = 1
        AND app.RoleId = 'technician'
        AND employee.TrangThai = 'Đang làm việc'
        AND (
          (
            (lower(app.Email) = lower(?) OR app.Phone = ?)
            AND app.PasswordHash = ?
          )
          OR
          (
            (
              lower(employee.Email) = lower(?)
              OR lower(employee.TenNV) = lower(?)
              OR employee.MaNV = ?
            )
            AND employee.MatKhau = ?
          )
        )
      LIMIT 1
      ''',
      [keyword, keyword, password, keyword, keyword, keyword, password],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return AuthUser(
      id: row['MaNV'] as String,
      name: row['TenNV'] as String,
      email: row['Email'] as String? ?? '',
      role: 'Kỹ thuật viên',
    );
  }

  Future<String?> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    if (role == 'Khách hàng') {
      return _registerCustomer(name, email, phone, password);
    }
    return _registerEmployee(name, email, phone, password, role);
  }

  Future<String?> _registerCustomer(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    final db = await AppDatabase.instance.database;
    final normalizedEmail = email.trim().toLowerCase();
    final duplicate =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
            SELECT
              (SELECT COUNT(*) FROM AppUsers
               WHERE lower(Email) = ? OR Phone = ?)
              +
              (SELECT COUNT(*) FROM KhachHang
               WHERE lower(Email) = ?)
            ''',
            [normalizedEmail, phone.trim(), normalizedEmail],
          ),
        ) ??
        0;
    if (duplicate > 0) {
      return 'Email hoặc số điện thoại đã được sử dụng';
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final customerId = 'KH$timestamp';
    final userId = 'USR-KH-$timestamp';
    await db.transaction((transaction) async {
      await transaction.insert('KhachHang', {
        'MaKH': customerId,
        'HoTen': name.trim(),
        'SDT': phone.trim(),
        'Email': normalizedEmail,
        'TrangThai': 'Hoạt động',
      });
      await transaction.insert('AppUsers', {
        'Id': userId,
        'Email': normalizedEmail,
        'Phone': phone.trim(),
        'FullName': name.trim(),
        'RoleId': 'requester',
        'UnitId': 'UNIT-KH',
        'PasswordSalt': userId,
        'PasswordHash': password,
        'IsActive': 1,
        'MaKH': customerId,
      });
    });
    return null;
  }

  Future<String?> _registerEmployee(
    String name,
    String email,
    String phone,
    String password,
    String role,
  ) async {
    final db = await AppDatabase.instance.database;
    final normalizedEmail = email.trim().toLowerCase();
    final duplicate =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM NhanVien WHERE lower(Email) = ?',
            [normalizedEmail],
          ),
        ) ??
        0;
    if (duplicate > 0) {
      return 'Email đã tồn tại, vui lòng dùng email khác';
    }

    final nextNumber =
        Sqflite.firstIntValue(
          await db.rawQuery('''
            SELECT COALESCE(MAX(CAST(substr(MaNV, 3) AS INTEGER)), 0) + 1
            FROM NhanVien
            '''),
        ) ??
        1;
    final id = 'NV${nextNumber.toString().padLeft(3, '0')}';
    await db.insert('NhanVien', {
      'MaNV': id,
      'TenNV': name.trim(),
      'ChucVu': role,
      'QuyenHan': role,
      'SDT': phone.trim(),
      'Email': normalizedEmail,
      'MatKhau': password,
      'TrangThai': 'Đang làm việc',
    });
    return null;
  }
}
