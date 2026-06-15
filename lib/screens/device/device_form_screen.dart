import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/app_messenger.dart';
import '../../data/dummy_data.dart';
import '../../models/device.dart';
import 'device_action_result.dart';

class DeviceFormScreen extends StatefulWidget {
  final Device? device;

  const DeviceFormScreen({super.key, this.device});

  @override
  State<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _quantityController;
  late final TextEditingController _availableQuantityController;
  late final TextEditingController _descriptionController;
  late String _selectedType;
  late String _selectedStatus;
  late List<String> _selectedImages;
  bool _isSaving = false;

  final deviceTypes = [
    "Laptop",
    "Máy chiếu",
    "Camera",
    "Ánh sáng",
    "Âm thanh",
    "Phụ kiện",
    "Tripod",
    "Sân khấu",
    "Tablet",
    "Drone",
    "Video",
  ];

  final deviceStatuses = ["Sẵn sàng", "Đang cho thuê", "Bảo trì", "Hỏng"];

  @override
  void initState() {
    super.initState();
    final device = widget.device;
    _idController = TextEditingController(text: device?.id ?? '');
    _nameController = TextEditingController(text: device?.name ?? '');
    _priceController = TextEditingController(
      text: device?.pricePerDay.toStringAsFixed(0) ?? '',
    );
    _quantityController = TextEditingController(
      text: device?.quantityTotal.toString() ?? '',
    );
    _availableQuantityController = TextEditingController(
      text: device?.quantityAvailable.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: device?.description ?? '',
    );
    _selectedImages = [...?device?.images];
    if (_selectedImages.isEmpty) {
      _selectedImages = ['assets/images/default.png'];
    }
    _selectedType = device != null && deviceTypes.contains(device.type)
        ? device.type
        : deviceTypes.first;
    _selectedStatus = device != null && deviceStatuses.contains(device.status)
        ? device.status
        : deviceStatuses.first;
    if (widget.device == null && _idController.text.trim().isEmpty) {
      _idController.text = _generateDeviceId();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.device == null
        ? 'Thêm thiết bị'
        : 'Chỉnh sửa thiết bị';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F5E9), Color(0xFFB2DFDB)],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nhập đầy đủ mã, danh mục, giá thuê, số lượng, mô tả và ảnh theo đúng nghiệp vụ quản lý thiết bị.',
                  style: TextStyle(color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormField(
                        label: 'Mã thiết bị',
                        hint: 'VD: TB-001',
                        icon: Icons.tag,
                        controller: _idController,
                        readOnly: widget.device != null,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Vui lòng nhập mã thiết bị';
                          }
                          final duplicate = devices.any(
                            (item) =>
                                item.id.toLowerCase() == text.toLowerCase() &&
                                item.id != widget.device?.id,
                          );
                          if (duplicate) {
                            return 'Mã thiết bị đã tồn tại';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildFormField(
                        label: 'Tên thiết bị',
                        hint: 'VD: Loa JBL PRX815',
                        icon: Icons.devices,
                        controller: _nameController,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Vui lòng nhập tên thiết bị'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      _buildTypeDropdown(),
                      const SizedBox(height: 20),
                      _buildStatusDropdown(),
                      const SizedBox(height: 20),
                      _buildFormField(
                        label: 'Giá thuê/ngày (VNĐ)',
                        hint: 'VD: 250000',
                        icon: Icons.attach_money,
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final price = double.tryParse((value ?? '').trim());
                          if (price == null || price <= 0) {
                            return 'Giá thuê phải lớn hơn 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildFormField(
                        label: 'Số lượng tổng',
                        hint: 'VD: 5',
                        icon: Icons.confirmation_number,
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final quantity = int.tryParse((value ?? '').trim());
                          if (quantity == null || quantity <= 0) {
                            return 'Số lượng phải là số nguyên dương';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildFormField(
                        label: 'Số lượng khả dụng',
                        hint: 'VD: 3',
                        icon: Icons.inventory,
                        controller: _availableQuantityController,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final available = int.tryParse((value ?? '').trim());
                          final total = int.tryParse(
                            _quantityController.text.trim(),
                          );
                          if (available == null || available < 0) {
                            return 'Số lượng khả dụng phải >= 0';
                          }
                          if (total != null && available > total) {
                            return 'Số lượng khả dụng không được vượt quá tổng';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildFormField(
                        label: 'Mô tả kỹ thuật',
                        hint: 'Mô tả chi tiết thiết bị',
                        icon: Icons.description,
                        controller: _descriptionController,
                        maxLines: 4,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Vui lòng nhập mô tả'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      _buildImagePickerSection(),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.green, Color(0xFF009688)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveDevice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _isSaving
                                  ? 'Đang lưu...'
                                  : widget.device == null
                                  ? 'Lưu thiết bị'
                                  : 'Cập nhật thiết bị',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool readOnly = false,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey.withOpacity(0.05),
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: Colors.green, size: 22),
            ),
            alignLabelWithHint: maxLines > 1,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Colors.green, width: 2),
            ),
            hintStyle: TextStyle(color: Colors.grey.withOpacity(0.6)),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.category, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'Danh mục',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          items: deviceTypes
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedType = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.inventory_2,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Trạng thái',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedStatus,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          items: deviceStatuses
              .map(
                (status) =>
                    DropdownMenuItem(value: status, child: Text(status)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedStatus = value;
            });
          },
        ),
      ],
    );
  }

  Future<void> _saveDevice() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final price = double.parse(_priceController.text.trim());
      final quantity = int.parse(_quantityController.text.trim());
      final availableQuantity = int.parse(
        _availableQuantityController.text.trim(),
      );
      final device = Device(
        id: _idController.text.trim(),
        name: _nameController.text.trim(),
        type: _selectedType,
        status: _selectedStatus,
        pricePerDay: price,
        quantityTotal: quantity,
        quantityAvailable: availableQuantity,
        description: _descriptionController.text.trim(),
        images: _selectedImages,
      );

      if (widget.device == null) {
        devices.add(device);
      } else {
        final existingIndex = devices.indexWhere(
          (item) => item.id == widget.device!.id,
        );
        if (existingIndex != -1) {
          devices[existingIndex] = device;
        }
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        widget.device == null
            ? DeviceActionResult.added
            : DeviceActionResult.updated,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showAppMessage(
        'Không thể lưu thiết bị: ${_errorMessage(error)}',
        backgroundColor: Colors.red.shade700,
      );
    }
  }

  String _errorMessage(Object error) {
    final message = error.toString();
    if (message.contains('UNIQUE constraint failed: ThietBi.MaTB')) {
      return 'mã thiết bị đã tồn tại';
    }
    if (message.contains('FOREIGN KEY constraint failed')) {
      return 'danh mục hoặc nhà cung cấp không hợp lệ';
    }
    return message
        .replaceFirst('DatabaseException(', '')
        .replaceFirst('Bad state: ', '');
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _availableQuantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _generateDeviceId() {
    var maxNumber = 0;
    for (final item in devices) {
      final digits = RegExp(r'\d+').firstMatch(item.id)?.group(0);
      final number = int.tryParse(digits ?? '0') ?? 0;
      if (number > maxNumber) {
        maxNumber = number;
      }
    }

    final nextNumber = maxNumber + 1;
    return 'TB-${nextNumber.toString().padLeft(3, '0')}';
  }

  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'Ảnh minh họa',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImagesFromDevice,
                icon: const Icon(Icons.upload_file),
                label: const Text('Chọn ảnh từ máy'),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${_selectedImages.length} ảnh',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedImages.isNotEmpty)
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final imageRef = _selectedImages[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildImagePreview(
                        imageRef,
                        width: 92,
                        height: 92,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImages.removeAt(index);
                            if (_selectedImages.isEmpty) {
                              _selectedImages = ['assets/images/default.png'];
                            }
                          });
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _pickImagesFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final pickedImages = <String>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        continue;
      }
      pickedImages.add('base64:${base64Encode(bytes)}');
    }

    if (pickedImages.isEmpty) {
      return;
    }

    setState(() {
      _selectedImages = pickedImages;
    });
  }

  Widget _buildImagePreview(
    String imageRef, {
    required double width,
    required double height,
  }) {
    if (imageRef.startsWith('base64:')) {
      final encoded = imageRef.substring(7);
      return Image.memory(
        base64Decode(encoded),
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
