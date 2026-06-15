// Rental Card Widget

import 'package:flutter/material.dart';

class RentalCard extends StatelessWidget {
  final String rentalId;
  final String deviceName;
  final String customerName;

  const RentalCard({required this.rentalId, required this.deviceName, required this.customerName, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('Rental: $rentalId'),
        subtitle: Text('Device: $deviceName\nCustomer: $customerName'),
      ),
    );
  }
}