// Customer Card Widget

import 'package:flutter/material.dart';

class CustomerCard extends StatelessWidget {
  final String customerName;
  final String customerPhone;

  const CustomerCard({required this.customerName, required this.customerPhone, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(customerName),
        subtitle: Text(customerPhone),
      ),
    );
  }
}
