import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/constants/user_session.dart';
import '../../core/routes/app_routes.dart';
import '../../data/dummy_data.dart';
import '../../models/device.dart';
import 'device_action_result.dart';
import 'device_form_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  int selectedImageIndex = 0;
  late Device _device;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;

    return Scaffold(
      appBar: AppBar(title: const Text("Chi tiết thiết bị")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🖼️ ẢNH CHÍNH (nhỏ gọn hơn Shopee)
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[100],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildDeviceImage(
                  device.images.isNotEmpty
                      ? device.images[selectedImageIndex]
                      : "assets/images/default.png",
                ),
              ),
            ),

            const SizedBox(height: 10),

            /// 🖼️ THUMBNAIL NHỎ
            if (device.images.length > 1)
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: device.images.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == selectedImageIndex;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedImageIndex = index;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? Colors.blue
                                : Colors.transparent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _buildDeviceImage(
                            device.images[index],
                            width: 55,
                            height: 55,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            /// 📛 TÊN + TRẠNG THÁI
            Text(
              device.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                _statusChip(device.status),
                const SizedBox(width: 10),
                Text(
                  "${device.pricePerDay.toInt()}đ/ngày",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// 📄 THÔNG TIN CHI TIẾT
            const Text(
              "Thông tin thiết bị",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _specItem("Mã thiết bị", device.id),
            _specItem("Danh mục", device.type),
            _specItem("Số lượng tổng", device.quantityTotal.toString()),
            _specItem("Số lượng khả dụng", device.quantityAvailable.toString()),
            _specItem("Mô tả", device.description),

            const SizedBox(height: 30),

            /// 🔥 ACTION BUTTONS
            if (UserSession.isCustomer)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.customerMaintenance);
                  },
                  icon: const Icon(Icons.build_circle_outlined),
                  label: const Text('Yêu cầu bảo trì'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeviceFormScreen(device: device),
                          ),
                        );

                        if (!context.mounted) return;
                        if (result == DeviceActionResult.updated) {
                          Navigator.pop(context, DeviceActionResult.updated);
                        }
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text("Sửa"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.createRental);
                      },
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text("Thuê"),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 10),

            /// 🗑️ XOÁ (chỉ manager)
            if (!UserSession.isCustomer)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    _showDeleteDialog(context);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    "Xóa thiết bị",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 🎨 STATUS CHIP
  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: _getStatusTextColor(status),
        ),
      ),
    );
  }

  /// 📄 SPEC ITEM
  Widget _specItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// 🗑️ CONFIRM DELETE
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Xác nhận"),
        content: Text(
          _device.status == "Đang cho thuê"
              ? "Thiết bị đang được cho thuê nên không thể xóa."
              : "Bạn có chắc muốn xóa thiết bị này không?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: _device.status == "Đang cho thuê"
                ? null
                : () async {
                    Navigator.pop(context);
                    devices.removeWhere((item) => item.id == _device.id);
                    if (!context.mounted) return;
                    Navigator.pop(context, DeviceActionResult.deleted);
                  },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Sẵn sàng":
        return const Color(0xFFC8E6C9);
      case "Đang cho thuê":
        return Colors.orange.shade100;
      case "Bảo trì":
        return Colors.red.shade100;
      case "Hỏng":
        return Colors.grey.shade300;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case "Sẵn sàng":
        return const Color(0xFF2E7D32);
      case "Đang cho thuê":
        return Colors.orange.shade800;
      case "Bảo trì":
        return Colors.red.shade800;
      case "Hỏng":
        return Colors.grey.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  Widget _buildDeviceImage(String imageRef, {double? width, double? height}) {
    if (imageRef.startsWith('base64:')) {
      return Image.memory(
        base64Decode(imageRef.substring(7)),
        width: width,
        height: height,
        fit: BoxFit.cover,
      );
    }

    return Image.asset(
      imageRef,
      width: width,
      height: height,
      fit: BoxFit.cover,
    );
  }
}
