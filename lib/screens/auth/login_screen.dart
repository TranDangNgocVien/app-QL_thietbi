import 'package:flutter/material.dart';
import 'package:ung_dung_quan_ly_thiet_bi/core/constants/user_session.dart';
import 'package:ung_dung_quan_ly_thiet_bi/core/routes/app_routes.dart';
import 'package:ung_dung_quan_ly_thiet_bi/core/theme/app_theme.dart';
import 'package:ung_dung_quan_ly_thiet_bi/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key}); // phải có const

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _roles = [
    ('Nhân viên', Icons.badge_outlined),
    ('Quản lý', Icons.admin_panel_settings_outlined),
    ('Khách hàng', Icons.person_outline),
    ('Kỹ thuật viên', Icons.engineering_outlined),
  ];

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool hidePassword = true;
  bool _isSubmitting = false;
  late String selectedRole = _roles.any((item) => item.$1 == UserSession.role)
      ? UserSession.role
      : '';

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.loginBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Image.asset("assets/images/logo.png", width: 84),
              const SizedBox(height: 14),
              Text(
                'Đăng nhập hệ thống',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ứng dụng quản lý cho thuê thiết bị',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vai trò đăng nhập',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2.65,
                          ),
                      itemCount: _roles.length,
                      itemBuilder: (context, index) {
                        final item = _roles[index];
                        final selected = selectedRole == item.$1;
                        return Material(
                          key: ValueKey('login-role-${item.$1}'),
                          color: selected
                              ? AppTheme.primaryColor
                              : const Color(0xFFF7FBFD),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() => selectedRole = item.$1);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? AppTheme.primaryColor
                                      : const Color(0xFF7FA8BC),
                                  width: selected ? 2 : 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.$2,
                                    size: 20,
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF234E63),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      item.$1,
                                      maxLines: 2,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFF183B56),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Tên đăng nhập hoặc email",
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Mật khẩu",
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Colors.white54,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.white54,
                          ),
                          onPressed: () {
                            setState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "Quên mật khẩu?",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _login,
                      icon: const Icon(Icons.login),
                      label: Text(
                        _isSubmitting
                            ? 'Đang đăng nhập...'
                            : 'Đăng nhập với vai trò $selectedRole',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.register);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
                label: const Text(
                  "Tạo tài khoản mới",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    final usernameOrEmail = emailController.text.trim();
    final password = passwordController.text;

    if (selectedRole.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn vai trò đăng nhập')),
      );
      return;
    }

    if (usernameOrEmail.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tài khoản và mật khẩu')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    AuthUser? user;
    try {
      user = await AuthService.instance
          .login(
            emailOrUsername: usernameOrEmail,
            password: password,
            role: selectedRole,
          )
          .timeout(const Duration(seconds: 12));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể đăng nhập: $error')));
      return;
    }

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thông tin đăng nhập không hợp lệ')),
      );
      return;
    }

    await UserSession.saveLogin(
      userRole: user.role,
      userName: user.name,
      userEmail: user.email,
      authenticatedUserId: user.id,
      authenticatedCustomerId: user.customerId ?? '',
    );

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
  }
}
