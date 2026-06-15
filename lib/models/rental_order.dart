// Rental Order model

class RentalOrder {
  final String id;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerAddress;
  final String deviceName;
  final int quantity;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final String status; // "Đang thuê" or "Hoàn thành"

  RentalOrder({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.customerAddress,
    required this.deviceName,
    this.quantity = 1,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    this.status = "Đang thuê",
  });

  RentalOrder copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? deviceName,
    int? quantity,
    DateTime? startDate,
    DateTime? endDate,
    double? totalPrice,
    String? status,
  }) {
    return RentalOrder(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerAddress: customerAddress ?? this.customerAddress,
      deviceName: deviceName ?? this.deviceName,
      quantity: quantity ?? this.quantity,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
    );
  }

  factory RentalOrder.fromJson(Map<String, dynamic> json) {
    return RentalOrder(
      id: json['id'] as String,
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String,
      customerEmail: json['customerEmail'] as String,
      customerAddress: json['customerAddress'] as String,
      deviceName: json['deviceName'] as String,
      quantity: json['quantity'] as int? ?? 1,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      status: json['status'] as String? ?? 'Đang thuê',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'customerAddress': customerAddress,
      'deviceName': deviceName,
      'quantity': quantity,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalPrice': totalPrice,
      'status': status,
    };
  }
}
