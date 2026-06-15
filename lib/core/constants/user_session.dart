import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static const String _sessionLoggedInKey = 'session_logged_in_v1';
  static const String _sessionRoleKey = 'session_role_v1';
  static const String _sessionNameKey = 'session_name_v1';
  static const String _sessionEmailKey = 'session_email_v1';
  static const String _sessionUserIdKey = 'session_user_id_v1';
  static const String _sessionCustomerIdKey = 'session_customer_id_v1';

  static String role = 'Nhân viên';
  static String displayName = 'Người dùng';
  static String email = '';
  static String userId = '';
  static String customerId = '';
  static bool isLoggedIn = false;

  static bool get isManager => role == 'Quản lý';
  static bool get isCustomer => role == 'Khách hàng';
  static bool get isTechnician => role == 'Kỹ thuật viên';

  static Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    isLoggedIn = preferences.getBool(_sessionLoggedInKey) ?? false;
    role = preferences.getString(_sessionRoleKey) ?? 'Nhân viên';
    displayName = preferences.getString(_sessionNameKey) ?? 'Người dùng';
    email = preferences.getString(_sessionEmailKey) ?? '';
    userId = preferences.getString(_sessionUserIdKey) ?? '';
    customerId = preferences.getString(_sessionCustomerIdKey) ?? '';
  }

  static Future<void> saveLogin({
    required String userRole,
    required String userName,
    required String userEmail,
    required String authenticatedUserId,
    String authenticatedCustomerId = '',
  }) async {
    final preferences = await SharedPreferences.getInstance();
    isLoggedIn = true;
    role = userRole;
    displayName = userName;
    email = userEmail;
    userId = authenticatedUserId;
    customerId = authenticatedCustomerId;
    await preferences.setBool(_sessionLoggedInKey, true);
    await preferences.setString(_sessionRoleKey, userRole);
    await preferences.setString(_sessionNameKey, userName);
    await preferences.setString(_sessionEmailKey, userEmail);
    await preferences.setString(_sessionUserIdKey, authenticatedUserId);
    await preferences.setString(_sessionCustomerIdKey, authenticatedCustomerId);
  }

  static Future<void> logout() async {
    final preferences = await SharedPreferences.getInstance();
    isLoggedIn = false;
    role = 'Nhân viên';
    displayName = 'Người dùng';
    email = '';
    userId = '';
    customerId = '';
    await preferences.remove(_sessionLoggedInKey);
    await preferences.remove(_sessionRoleKey);
    await preferences.remove(_sessionNameKey);
    await preferences.remove(_sessionEmailKey);
    await preferences.remove(_sessionUserIdKey);
    await preferences.remove(_sessionCustomerIdKey);
  }
}
