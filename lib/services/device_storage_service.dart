import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../data/dummy_data.dart' as dummy;
import '../models/device.dart';
import 'app_database.dart';

class DeviceStorageService {
  DeviceStorageService._();

  static final DeviceStorageService instance = DeviceStorageService._();

  static const _deletedStatus = 'Đã xóa';
  static const _businessStatus = 'Đang kinh doanh';
  static const _liquidatedStatus = 'Thanh lý';
  static const _inactiveStatus = 'Ngừng cho thuê';

  Future<List<Device>> loadDevices({List<Device> fallback = const []}) async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.rawQuery(
        '''
        SELECT tb.MaTB, tb.TenTB, ltb.TenLoai, tb.TrangThai,
               tb.DonGiaThue, tb.SoLuongTong, tb.SoLuongKhaDung,
               tb.MoTaKyThuat, tb.HinhAnh
        FROM ThietBi tb
        JOIN LoaiThietBi ltb ON ltb.MaLoai = tb.MaLoai
        WHERE tb.TrangThai <> ?
        ORDER BY tb.MaTB
        ''',
        [_deletedStatus],
      );
      if (rows.isEmpty) {
        return List<Device>.from(
          fallback.isNotEmpty ? fallback : dummy.devices,
        );
      }
      return rows.map(_fromRow).toList();
    } catch (_) {
      return List<Device>.from(fallback.isNotEmpty ? fallback : dummy.devices);
    }
  }

  Future<void> saveDevices(List<Device> devices) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((transaction) async {
      await _ensureDefaultSupplier(transaction);

      for (final device in devices) {
        final typeId = await _resolveTypeId(transaction, device.type);
        final values = _toDeviceValues(device, typeId);
        final updated = await transaction.update(
          'ThietBi',
          values,
          where: 'MaTB = ?',
          whereArgs: [device.id],
        );
        if (updated == 0) {
          await transaction.insert('ThietBi', values);
        }
      }

      if (devices.isNotEmpty) {
        final placeholders = List.filled(devices.length, '?').join(',');
        await transaction.rawDelete('''
          DELETE FROM ThietBi
          WHERE MaTB NOT IN ($placeholders)
            AND NOT EXISTS (
              SELECT 1 FROM ThietBiChiTiet ct WHERE ct.MaTB = ThietBi.MaTB
            )
          ''', devices.map((device) => device.id).toList());
      }
    });
  }

  Future<void> saveDevice(Device device) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((transaction) async {
      await _ensureDefaultSupplier(transaction);

      final typeId = await _resolveTypeId(transaction, device.type);
      final values = _toDeviceValues(device, typeId);
      final updated = await transaction.update(
        'ThietBi',
        values,
        where: 'MaTB = ?',
        whereArgs: [device.id],
      );
      if (updated == 0) {
        await transaction.insert('ThietBi', values);
      }
    });
  }

  Future<void> deleteDevice(String deviceId) async {
    final db = await AppDatabase.instance.database;
    final updated = await db.update(
      'ThietBi',
      {'TrangThai': _deletedStatus},
      where: 'MaTB = ?',
      whereArgs: [deviceId],
    );
    if (updated != 1) {
      throw StateError('Không tìm thấy thiết bị cần xóa');
    }
  }

  Future<bool> exportBackupJson(List<Device> devices) async {
    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(devices.map((device) => device.toJson()).toList());
    final filePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Xuất backup thiết bị',
      fileName: 'devices_backup.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (filePath == null || filePath.isEmpty) return false;
    await File(filePath).writeAsString(jsonString, encoding: utf8);
    return true;
  }

  Future<void> _ensureDefaultSupplier(DatabaseExecutor database) async {
    await database.insert('NhaCungCap', {
      'MaNCC': 'NCC-APP',
      'TenNCC': 'Nhà cung cấp mặc định',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Map<String, Object?> _toDeviceValues(Device device, String typeId) {
    return <String, Object?>{
      'MaTB': device.id,
      'TenTB': device.name,
      'DonGiaThue': device.pricePerDay,
      'SoLuongTong': device.quantityTotal,
      'SoLuongKhaDung': device.quantityAvailable,
      'MoTaKyThuat': device.description,
      'HinhAnh': device.images.isEmpty ? null : device.images.first,
      'MaLoai': typeId,
      'MaNCC': 'NCC-APP',
      'TrangThai': _toDatabaseStatus(device.status),
    };
  }

  Device _fromRow(Map<String, Object?> row) {
    final image = row['HinhAnh'] as String?;
    return Device(
      id: row['MaTB'] as String,
      name: row['TenTB'] as String,
      type: row['TenLoai'] as String,
      status: _toAppStatus(
        row['TrangThai'] as String,
        row['SoLuongTong'] as int,
        row['SoLuongKhaDung'] as int,
      ),
      pricePerDay: (row['DonGiaThue'] as num).toDouble(),
      quantityTotal: row['SoLuongTong'] as int,
      quantityAvailable: row['SoLuongKhaDung'] as int,
      description: row['MoTaKyThuat'] as String? ?? '',
      images: image == null || image.isEmpty
          ? const ['assets/images/logo.png']
          : [image],
    );
  }

  String _typeId(String type) {
    final normalized = type
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .padRight(8, 'X');
    return 'APP-${normalized.substring(0, 8)}';
  }

  Future<String> _resolveTypeId(DatabaseExecutor database, String type) async {
    final cleanType = type.trim();
    final existing = await database.query(
      'LoaiThietBi',
      columns: ['MaLoai'],
      where: 'lower(TenLoai) = lower(?)',
      whereArgs: [cleanType],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return existing.first['MaLoai'] as String;
    }

    final baseId = _typeId(cleanType);
    var typeId = baseId;
    var suffix = 1;
    while (await _typeIdExists(database, typeId)) {
      typeId = '$baseId-$suffix';
      suffix++;
    }
    await database.insert('LoaiThietBi', {
      'MaLoai': typeId,
      'TenLoai': cleanType,
    });
    return typeId;
  }

  Future<bool> _typeIdExists(DatabaseExecutor database, String typeId) async {
    final rows = await database.query(
      'LoaiThietBi',
      columns: ['MaLoai'],
      where: 'MaLoai = ?',
      whereArgs: [typeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  String _toDatabaseStatus(String status) {
    if (status == _liquidatedStatus || status == _inactiveStatus) {
      return status;
    }
    return _businessStatus;
  }

  String _toAppStatus(String status, int total, int available) {
    if (status == _liquidatedStatus) return 'Hỏng';
    if (status == _inactiveStatus) return 'Bảo trì';
    if (available == 0) return 'Bảo trì';
    if (available < total) return 'Đang cho thuê';
    return 'Sẵn sàng';
  }
}
