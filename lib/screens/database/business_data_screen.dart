import 'package:flutter/material.dart';

import '../../services/business_data_service.dart';

class BusinessDataScreen extends StatefulWidget {
  const BusinessDataScreen({super.key});

  @override
  State<BusinessDataScreen> createState() => _BusinessDataScreenState();
}

class _BusinessDataScreenState extends State<BusinessDataScreen> {
  late Future<List<BusinessTableInfo>> _tablesFuture;

  @override
  void initState() {
    super.initState();
    _tablesFuture = BusinessDataService.instance.loadTableInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dữ liệu nghiệp vụ')),
      body: FutureBuilder<List<BusinessTableInfo>>(
        future: _tablesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Không thể đọc dữ liệu: ${snapshot.error}'),
            );
          }
          final tables = snapshot.data ?? const [];
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _tablesFuture = BusinessDataService.instance.loadTableInfo();
              });
              await _tablesFuture;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tables.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final table = tables[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.table_rows_outlined),
                    ),
                    title: Text(table.label),
                    subtitle: Text(table.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${table.rowCount} dòng'),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BusinessTableScreen(table: table),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class BusinessTableScreen extends StatelessWidget {
  final BusinessTableInfo table;

  const BusinessTableScreen({super.key, required this.table});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(table.label)),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: BusinessDataService.instance.loadRows(table.name),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Không thể đọc bảng: ${snapshot.error}'));
          }
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return const Center(child: Text('Bảng chưa có dữ liệu'));
          }
          final columns = rows.first.keys.toList();
          return Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(
                    Theme.of(context).colorScheme.primaryContainer,
                  ),
                  columns: columns
                      .map((column) => DataColumn(label: Text(column)))
                      .toList(),
                  rows: rows
                      .map(
                        (row) => DataRow(
                          cells: columns
                              .map(
                                (column) => DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 260,
                                    ),
                                    child: Text(
                                      row[column]?.toString() ?? '',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
