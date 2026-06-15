import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phimhay_app/config/theme.dart';
import 'package:phimhay_app/providers/auth_provider.dart';
import 'package:phimhay_app/providers/home_provider.dart';
import 'package:phimhay_app/services/push_service.dart';
import 'package:phimhay_app/widgets/header.dart';
import 'package:phimhay_app/widgets/bottom_nav.dart';
import 'package:phimhay_app/screens/home/home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _navIndex = 4;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _loginUsernameCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  final _regUsernameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();

  bool _loginObscured = true;
  bool _regObscured = true;
  bool _regConfirmObscured = true;
  bool _isSubmitting = false;
  String? _loginError;
  String? _registerError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUsernameCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regUsernameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _loginError = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _loginUsernameCtrl.text.trim(),
      _loginPasswordCtrl.text,
    );
    if (success) {
      // Gửi FCM token lên server sau khi đăng nhập
      PushService.sendTokenToServerAfterLogin();
      // Refresh home data sau khi login thành công
      if (mounted) {
        await context.read<HomeProvider>().fetchHome();
        Navigator.pop(context);
      }
    } else {
      if (mounted) setState(() => _loginError = auth.error ?? 'Đăng nhập thất bại');
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _registerError = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _regUsernameCtrl.text.trim(),
      _regEmailCtrl.text.trim(),
      _regPasswordCtrl.text,
    );
    if (success) {
      // Refresh home data sau khi register thành công
      if (mounted) {
        await context.read<HomeProvider>().fetchHome();
        Navigator.pop(context);
      }
    } else {
      if (mounted) setState(() => _registerError = auth.error ?? 'Đăng ký thất bại');
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  void _onNavSelected(int index) {
    if (index == _navIndex) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(initialIndex: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Nội dung chính
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 56,
            ),
            child: Column(
              children: [
                // Close button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textPrimary),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                // Tab bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.black,
                    unselectedLabelColor: AppTheme.textSub,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 14,
                    ),
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(4),
                    tabs: const [
                      Tab(text: 'Đăng nhập'),
                      Tab(text: 'Đăng ký'),
                    ],
                  ),
                ),

                // Forms
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLoginForm(),
                      _buildRegisterForm(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Header cố định
          const Positioned(top: 0, left: 0, right: 0, child: Header()),
          // BottomNav
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: BottomNav(currentIndex: _navIndex, onTabSelected: _onNavSelected),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Chào mừng trở lại',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đăng nhập để tiếp tục xem phim',
              style: TextStyle(
                color: AppTheme.textSub,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // Error message
            if (_loginError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _loginError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Username field
            _AuthField(
              controller: _loginUsernameCtrl,
              label: 'Tên đăng nhập hoặc Email',
              prefixIcon: Icons.person_outline,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Vui lòng nhập tên đăng nhập' : null,
            ),
            const SizedBox(height: 16),

            // Password field
            _AuthField(
              controller: _loginPasswordCtrl,
              label: 'Mật khẩu',
              prefixIcon: Icons.lock_outline,
              obscure: _loginObscured,
              suffixIcon: IconButton(
                icon: Icon(
                  _loginObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
                onPressed: () => setState(() => _loginObscured = !_loginObscured),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Vui lòng nhập mật khẩu' : null,
            ),
            const SizedBox(height: 24),

            // Submit button
            _SubmitButton(
              label: 'Đăng nhập',
              loading: _isSubmitting,
              onTap: _handleLogin,
            ),

            const SizedBox(height: 16),

            // Forgot password
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text(
                  'Quên mật khẩu?',
                  style: TextStyle(color: AppTheme.textSub, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 80), // Spacer cho BottomNav
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Tạo tài khoản mới',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đăng ký để khám phá kho phim',
              style: TextStyle(
                color: AppTheme.textSub,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),

            // Error message
            if (_registerError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _registerError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],

            _AuthField(
              controller: _regUsernameCtrl,
              label: 'Tên đăng nhập',
              prefixIcon: Icons.person_outline,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Vui lòng nhập tên đăng nhập' : null,
            ),
            const SizedBox(height: 16),

            _AuthField(
              controller: _regEmailCtrl,
              label: 'Email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                if (!v.contains('@')) return 'Email không hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _AuthField(
              controller: _regPasswordCtrl,
              label: 'Mật khẩu',
              prefixIcon: Icons.lock_outline,
              obscure: _regObscured,
              suffixIcon: IconButton(
                icon: Icon(
                  _regObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
                onPressed: () => setState(() => _regObscured = !_regObscured),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                if (v.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _AuthField(
              controller: _regConfirmCtrl,
              label: 'Xác nhận mật khẩu',
              prefixIcon: Icons.lock_outline,
              obscure: _regConfirmObscured,
              suffixIcon: IconButton(
                icon: Icon(
                  _regConfirmObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _regConfirmObscured = !_regConfirmObscured),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                if (v != _regPasswordCtrl.text) return 'Mật khẩu không khớp';
                return null;
              },
            ),
            const SizedBox(height: 24),

            _SubmitButton(
              label: 'Đăng ký',
              loading: _isSubmitting,
              onTap: _handleRegister,
            ),
            const SizedBox(height: 80), // Spacer cho BottomNav
          ],
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  const _AuthField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(prefixIcon, color: AppTheme.textMuted, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppTheme.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        labelStyle: const TextStyle(color: AppTheme.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE59A), AppTheme.accent],
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
