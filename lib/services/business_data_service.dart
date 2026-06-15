import 'app_database.dart';

class BusinessTableInfo {
  final String name;
  final String label;
  final int rowCount;

  const BusinessTableInfo({
    required this.name,
    required this.label,
    required this.rowCount,
  });
}

class BusinessDataService {
  BusinessDataService._();

  static final BusinessDataService instance = BusinessDataService._();

  static const tables = <String, String>{
    'LoaiThietBi': 'Loại thiết bị',
    'NhaCungCap': 'Nhà cung cấp',
    'NhanVien': 'Nhân viên',
    'KhachHang': 'Khách hàng',
    'ThietBi': 'Thiết bị',
    'ThietBiChiTiet': 'Thiết bị chi tiết',
    'YeuCauMuon': 'Yêu cầu mượn',
    'PhieuMuon': 'Phiếu mượn',
    'ChiTietPM': 'Chi tiết phiếu mượn',
    'ThanhToan': 'Thanh toán',
    'GiaHanMuon': 'Gia hạn mượn',
    'PhuPhiViPham': 'Phụ phí vi phạm',
    'BaoTri': 'Bảo trì',
    'BaoCao': 'Báo cáo',
    'AppUnits': 'Đơn vị ứng dụng',
    'AppUsers': 'Tài khoản ứng dụng',
    'AppSessions': 'Phiên đăng nhập',
    'AppMaintenanceRequests': 'Yêu cầu bảo trì ứng dụng',
    'AppStatusHistory': 'Lịch sử trạng thái',
    'AppMaintenanceTasks': 'Công việc bảo trì',
    'AppNotifications': 'Thông báo',
    'AppUserPreferences': 'Tùy chọn người dùng',
  };

  Future<List<BusinessTableInfo>> loadTableInfo() async {
    final db = await AppDatabase.instance.database;
    final result = <BusinessTableInfo>[];
    for (final entry in tables.entries) {
      final rows = await db.rawQuery('SELECT COUNT(*) count FROM ${entry.key}');
      result.add(
        BusinessTableInfo(
          name: entry.key,
          label: entry.value,
          rowCount: (rows.first['count'] as num).toInt(),
        ),
      );
    }
    return result;
  }

  Future<List<Map<String, Object?>>> loadRows(String table) async {
    if (!tables.containsKey(table)) {
      throw ArgumentError.value(table, 'table', 'Bảng không được hỗ trợ');
    }
    final db = await AppDatabase.instance.database;
    return db.query(table, limit: 200);
  }
}
