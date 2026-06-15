import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ung_dung_quan_ly_thiet_bi/core/app_messenger.dart';
import 'package:ung_dung_quan_ly_thiet_bi/core/constants/user_session.dart';
import 'package:ung_dung_quan_ly_thiet_bi/core/theme/app_theme.dart';
import 'package:ung_dung_quan_ly_thiet_bi/main.dart';
import 'package:ung_dung_quan_ly_thiet_bi/models/maintenance_request.dart';
import 'package:ung_dung_quan_ly_thiet_bi/screens/auth/login_screen.dart';
import 'package:ung_dung_quan_ly_thiet_bi/screens/maintenance/maintenance_review_screen.dart';
import 'package:ung_dung_quan_ly_thiet_bi/screens/maintenance/technician_jobs_screen.dart';

void main() {
  testWidgets('Ứng dụng khởi tạo MaterialApp', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('Messenger toàn cục hiển thị thông báo thành công', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    showAppMessage('Thêm thiết bị thành công');
    await tester.pump();

    expect(find.text('Thêm thiết bị thành công'), findsOneWidget);
  });

  testWidgets('Vai trò chưa chọn vẫn rõ và được xếp thành lưới hai cột', (
    tester,
  ) async {
    UserSession.role = 'Nhân viên';
    tester.view.physicalSize = const Size(900, 1900);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const LoginScreen()),
    );
    await tester.pumpAndSettle();

    final customerText = tester.widget<Text>(find.text('Khách hàng'));
    expect(customerText.style?.color, const Color(0xFF183B56));

    await tester.tap(find.text('Kỹ thuật viên'));
    await tester.pump();

    final technicianText = tester.widget<Text>(find.text('Kỹ thuật viên'));
    final employeeText = tester.widget<Text>(find.text('Nhân viên'));
    expect(technicianText.style?.color, Colors.white);
    expect(employeeText.style?.color, const Color(0xFF183B56));

    final employeeTop = tester.getTopLeft(
      find.byKey(const ValueKey('login-role-Nhân viên')),
    );
    final managerTop = tester.getTopLeft(
      find.byKey(const ValueKey('login-role-Quản lý')),
    );
    final customerTop = tester.getTopLeft(
      find.byKey(const ValueKey('login-role-Khách hàng')),
    );
    expect((employeeTop.dy - managerTop.dy).abs(), lessThan(4));
    expect(customerTop.dy, greaterThan(employeeTop.dy));
  });

  testWidgets('Hủy hộp thoại từ chối không phát sinh lỗi', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RejectReasonDialog(deviceName: 'Máy chiếu Epson')),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'Không đủ thông tin');
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Xác nhận từ chối trả về lý do và không phát sinh lỗi', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (_) =>
                      const RejectReasonDialog(deviceName: 'Laptop Dell'),
                );
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Thiết bị không thuộc phạm vi bảo trì',
    );
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();

    expect(result, 'Thiết bị không thuộc phạm vi bảo trì');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hủy xác nhận sửa chữa không phát sinh lỗi', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog<TechnicianCompletionData>(
                context: context,
                builder: (_) =>
                    const TechnicianCompletionDialog(job: _technicianJob),
              ),
              child: const Text('Mở kết quả'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở kết quả'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Đã thay nguồn thiết bị',
    );
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Kỹ thuật viên xác nhận đúng kết quả sửa chữa', (tester) async {
    TechnicianCompletionData? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showDialog<TechnicianCompletionData>(
                  context: context,
                  builder: (_) =>
                      const TechnicianCompletionDialog(job: _technicianJob),
                );
              },
              child: const Text('Mở kết quả'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở kết quả'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Đã thay nguồn, thiết bị hoạt động ổn định',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '150000');
    await tester.tap(find.text('Hoàn tất'));
    await tester.pumpAndSettle();

    expect(result?.deviceCondition, 'Tốt');
    expect(result?.cost, 150000);
    expect(tester.takeException(), isNull);
  });
}

const _technicianJob = TechnicianJob(
  requestId: 'MR-TEST',
  deviceDetailId: 'CT-TEST',
  deviceName: 'Máy chiếu Epson',
  serialNumber: 'SN-TEST',
  customerName: 'Khách hàng thử nghiệm',
  priority: 'medium',
  description: 'Thiết bị không khởi động',
  status: 'in_progress',
  cost: 0,
  progress: 20,
);
