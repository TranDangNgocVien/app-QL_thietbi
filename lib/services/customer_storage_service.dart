import '../models/customer.dart';
import 'app_database.dart';

class CustomerStorageService {
  CustomerStorageService._();

  static final CustomerStorageService instance = CustomerStorageService._();

  Future<List<Customer>> loadCustomers() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('KhachHang', orderBy: 'MaKH');
    return rows
        .map(
          (row) => Customer(
            id: row['MaKH'] as String,
            name: row['HoTen'] as String,
            phone: row['SDT'] as String? ?? '',
            email: row['Email'] as String? ?? '',
            address: row['DiaChi'] as String? ?? '',
          ),
        )
        .toList();
  }

  Future<void> saveCustomers(List<Customer> customers) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((transaction) async {
      for (final customer in customers) {
        final values = <String, Object?>{
          'MaKH': customer.id,
          'HoTen': customer.name,
          'SDT': customer.phone.isEmpty ? null : customer.phone,
          'Email': customer.email.isEmpty ? null : customer.email,
          'DiaChi': customer.address.isEmpty ? null : customer.address,
        };
        final updated = await transaction.update(
          'KhachHang',
          values,
          where: 'MaKH = ?',
          whereArgs: [customer.id],
        );
        if (updated == 0) {
          await transaction.insert('KhachHang', values);
        }
      }

      if (customers.isNotEmpty) {
        final placeholders = List.filled(customers.length, '?').join(',');
        await transaction.rawDelete('''
          DELETE FROM KhachHang
          WHERE MaKH NOT IN ($placeholders)
            AND NOT EXISTS (
              SELECT 1 FROM PhieuMuon pm WHERE pm.MaKH = KhachHang.MaKH
            )
            AND NOT EXISTS (
              SELECT 1 FROM YeuCauMuon yc WHERE yc.MaKH = KhachHang.MaKH
            )
          ''', customers.map((customer) => customer.id).toList());
      }
    });
  }

  Future<void> saveCustomer(Customer customer) async {
    final db = await AppDatabase.instance.database;
    final values = <String, Object?>{
      'MaKH': customer.id,
      'HoTen': customer.name,
      'SDT': customer.phone.isEmpty ? null : customer.phone,
      'Email': customer.email.isEmpty ? null : customer.email,
      'DiaChi': customer.address.isEmpty ? null : customer.address,
    };
    final updated = await db.update(
      'KhachHang',
      values,
      where: 'MaKH = ?',
      whereArgs: [customer.id],
    );
    if (updated == 0) {
      await db.insert('KhachHang', values);
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    final db = await AppDatabase.instance.database;
    final deleted = await db.delete(
      'KhachHang',
      where: '''
        MaKH = ?
        AND NOT EXISTS (
          SELECT 1 FROM PhieuMuon pm WHERE pm.MaKH = KhachHang.MaKH
        )
        AND NOT EXISTS (
          SELECT 1 FROM YeuCauMuon yc WHERE yc.MaKH = KhachHang.MaKH
        )
      ''',
      whereArgs: [customerId],
    );
    if (deleted == 0) {
      throw StateError(
        'Không thể xóa khách hàng đã có phiếu mượn hoặc yêu cầu mượn',
      );
    }
  }
}
