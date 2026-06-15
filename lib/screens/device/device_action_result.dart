enum DeviceActionResult { added, updated, deleted }

extension DeviceActionResultMessage on DeviceActionResult {
  String get successMessage {
    switch (this) {
      case DeviceActionResult.added:
        return 'Thêm thiết bị thành công';
      case DeviceActionResult.updated:
        return 'Sửa thiết bị thành công';
      case DeviceActionResult.deleted:
        return 'Xóa thiết bị thành công';
    }
  }
}
