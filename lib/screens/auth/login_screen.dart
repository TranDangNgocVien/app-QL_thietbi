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
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool hidePassword = true;
  bool _isSubmitting = false;

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
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        _isSubmitting ? 'Đang đăng nhập...' : 'Đăng nhập',
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
          .login(emailOrUsername: usernameOrEmail, password: password)
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
