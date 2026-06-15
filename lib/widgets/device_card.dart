// Device Card Widget

import 'package:flutter/material.dart';

class DeviceCard extends StatelessWidget {
  final String deviceName;
  final String deviceType;

  const DeviceCard({required this.deviceName, required this.deviceType, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(deviceName),
        subtitle: Text(deviceType),
      ),
    );
  }
}
