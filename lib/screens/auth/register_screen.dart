import 'package:flutter/material.dart';
import 'package:ung_dung_quan_ly_thiet_bi/core/constants/user_session.dart';
import 'package:ung_dung_quan_ly_thiet_bi/core/routes/app_routes.dart';
import 'package:ung_dung_quan_ly_thiet_bi/core/theme/app_theme.dart';
import 'package:ung_dung_quan_ly_thiet_bi/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool _isSubmitting = false;
  String selectedRole = UserSession.role;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.loginBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Image.asset("assets/images/logo.png", width: 100),
              const SizedBox(height: 20),
              Text(
                "Tạo tài khoản mới",
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Nhân viên', label: Text('Nhân viên')),
                  ButtonSegment(value: 'Quản lý', label: Text('Quản lý')),
                  ButtonSegment(value: 'Khách hàng', label: Text('Khách hàng')),
                ],
                selected: {selectedRole},
                showSelectedIcon: false,
                onSelectionChanged: (value) {
                  setState(() {
                    selectedRole = value.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  foregroundColor: Colors.white,
                  selectedForegroundColor: AppTheme.primaryColor,
                  selectedBackgroundColor: Colors.white,
                  backgroundColor: Colors.transparent,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Họ và tên",
                  prefixIcon: Icon(Icons.person, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Email",
                  prefixIcon: Icon(Icons.email, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Số điện thoại",
                  prefixIcon: Icon(Icons.phone, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Mật khẩu",
                  prefixIcon: const Icon(Icons.lock, color: Colors.white54),
                  suffixIcon: IconButton(
                    icon: Icon(
                      hidePassword ? Icons.visibility_off : Icons.visibility,
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
              const SizedBox(height: 15),
              TextField(
                controller: confirmPasswordController,
                obscureText: hideConfirmPassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Xác nhận mật khẩu",
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: Colors.white54,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      hideConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white54,
                    ),
                    onPressed: () {
                      setState(() {
                        hideConfirmPassword = !hideConfirmPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _register,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.app_registration),
                label: Text(
                  _isSubmitting
                      ? 'Đang đăng ký...'
                      : 'Đăng ký tài khoản $selectedRole',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Đã có tài khoản? ",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    },
                    child: Text(
                      "Đăng nhập",
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        phoneController.text.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng điền đầy đủ thông tin")),
      );
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mật khẩu xác nhận không khớp")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final error = await AuthService.instance.register(
      name: nameController.text,
      email: emailController.text,
      phone: phoneController.text,
      password: passwordController.text,
      role: selectedRole,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final user = await AuthService.instance.login(
      emailOrUsername: emailController.text,
      password: passwordController.text,
      role: selectedRole,
    );
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thành công, vui lòng đăng nhập')),
      );
      Navigator.pushReplacementNamed(context, AppRoutes.login);
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Đăng ký thành công")));

    Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
  }
}
