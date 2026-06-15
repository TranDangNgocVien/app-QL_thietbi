import '../data/dummy_data.dart' as dummy;
import '../models/customer.dart';
import '../models/device.dart';
import '../models/rental_order.dart';

class OrderService {
  static final OrderService _instance = OrderService._internal();
  final List<RentalOrder> _orders = [];

  factory OrderService() => _instance;

  OrderService._internal();

  List<RentalOrder> get orders => _orders;

  Future<void> loadOrders({required List<RentalOrder> fallback}) async {
    _orders
      ..clear()
      ..addAll(fallback.isNotEmpty ? fallback : dummy.rentalOrders);
  }

  Future<List<Customer>> loadRentalCustomers() async {
    return List<Customer>.from(dummy.customers);
  }

  Future<List<Device>> loadAvailableDevices() async {
    return dummy.devices
        .where((device) => device.quantityAvailable > 0)
        .toList();
  }

  Future<List<Device>> loadDevices() async {
    return List<Device>.from(dummy.devices);
  }

  String generateNextBorrowTicketId() {
    final ids = <String>[
      ..._orders.map((order) => order.id),
      ...dummy.rentalOrders.map((order) => order.id),
    ];
    final maxNumber = ids.fold<int>(0, (maxValue, id) {
      final match = RegExp(r'^PM(\d+)$').firstMatch(id);
      if (match == null) return maxValue;
      final number = int.tryParse(match.group(1) ?? '') ?? 0;
      return number > maxValue ? number : maxValue;
    });
    return 'PM${(maxNumber + 1).toString().padLeft(3, '0')}';
  }

  Future<RentalOrder> createOrderForCustomer({
    required String customerId,
    required String deviceId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final customer = dummy.customers.firstWhere(
      (item) => item.id == customerId,
      orElse: () => throw StateError('Không tìm thấy khách hàng đã chọn'),
    );
    final device = dummy.devices.firstWhere(
      (item) => item.id == deviceId && item.quantityAvailable > 0,
      orElse: () => throw StateError('Thiết bị đã chọn không còn khả dụng'),
    );
    final days = _rentalDayCount(startDate, endDate);
    final order = RentalOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      customerName: customer.name,
      customerPhone: customer.phone,
      customerEmail: customer.email,
      customerAddress: customer.address,
      deviceName: device.name,
      quantity: 1,
      startDate: startDate,
      endDate: endDate,
      totalPrice: days * device.pricePerDay,
      status: 'Đang thuê',
    );
    addOrder(order);
    _decreaseDeviceAvailability(device.id, 1);
    return order;
  }

  void addOrder(RentalOrder order) {
    _orders.add(order);
    if (!dummy.rentalOrders.any((item) => item.id == order.id)) {
      dummy.rentalOrders.add(order);
    }
  }

  void updateOrder(String id, RentalOrder updatedOrder) {
    final index = _orders.indexWhere((item) => item.id == id);
    if (index != -1) _orders[index] = updatedOrder;

    final dummyIndex = dummy.rentalOrders.indexWhere((item) => item.id == id);
    if (dummyIndex != -1) dummy.rentalOrders[dummyIndex] = updatedOrder;
  }

  void deleteOrder(String id) {
    _orders.removeWhere((item) => item.id == id);
    dummy.rentalOrders.removeWhere((item) => item.id == id);
  }

  int getTotalOrders() => _orders.length;
  int getTotalDevices() => _orders.map((o) => o.deviceName).toSet().length;
  int getTotalCustomers() => _orders.map((o) => o.customerName).toSet().length;
  int getActiveRentals() =>
      _orders.where((o) => o.status == 'Đang thuê').length;
  int getCompletedRentals() => _orders
      .where((o) => o.status == 'Hoàn thành' || o.status == 'Đã trả')
      .length;

  double getRentingPercentage() {
    if (_orders.isEmpty || getTotalDevices() == 0) return 0;
    return getActiveRentals() / getTotalDevices() * 100;
  }

  void _decreaseDeviceAvailability(String deviceId, int quantity) {
    final index = dummy.devices.indexWhere((item) => item.id == deviceId);
    if (index == -1) return;
    final device = dummy.devices[index];
    final available = device.quantityAvailable - quantity;
    dummy.devices[index] = device.copyWith(
      quantityAvailable: available < 0 ? 0 : available,
      status: available <= 0 ? 'Bảo trì' : 'Đang cho thuê',
    );
  }

  int _rentalDayCount(DateTime startDate, DateTime endDate) {
    final days = endDate.difference(startDate).inDays;
    return days <= 0 ? 1 : days;
  }
}
