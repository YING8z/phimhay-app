import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phimhay_app/config/theme.dart';
import 'package:phimhay_app/providers/auth_provider.dart';
import 'package:phimhay_app/providers/home_provider.dart';
import 'package:phimhay_app/services/push_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
      PushService.sendTokenToServerAfterLogin();
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
      if (mounted) {
        await context.read<HomeProvider>().fetchHome();
        Navigator.pop(context);
      }
    } else {
      if (mounted) setState(() => _registerError = auth.error ?? 'Đăng ký thất bại');
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -120,
            left: -60,
            right: -60,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.textSub, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // Tab selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: const EdgeInsets.all(4),
                      labelColor: const Color(0xFF1A1100),
                      unselectedLabelColor: AppTheme.textSub,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                      dividerColor: Colors.transparent,
                      splashBorderRadius: BorderRadius.circular(12),
                      tabs: const [
                        Tab(text: 'Đăng nhập'),
                        Tab(text: 'Đăng ký'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

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
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chào mừng trở lại',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Đăng nhập để tiếp tục xem phim',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 36),

            if (_loginError != null) ...[
              _ErrorBanner(message: _loginError!),
              const SizedBox(height: 16),
            ],

            _AuthField(
              controller: _loginUsernameCtrl,
              hint: 'Tên đăng nhập hoặc Email',
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên đăng nhập' : null,
            ),
            const SizedBox(height: 14),

            _AuthField(
              controller: _loginPasswordCtrl,
              hint: 'Mật khẩu',
              prefixIcon: Icons.lock_outline_rounded,
              obscure: _loginObscured,
              textInputAction: TextInputAction.done,
              suffixIcon: _toggleObscure(
                visible: !_loginObscured,
                onTap: () => setState(() => _loginObscured = !_loginObscured),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Vui lòng nhập mật khẩu' : null,
              onFieldSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                child: const Text(
                  'Quên mật khẩu?',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _SubmitButton(
              label: 'Đăng nhập',
              loading: _isSubmitting,
              onTap: _handleLogin,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tạo tài khoản mới',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Đăng ký để khám phá kho phim',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 36),

            if (_registerError != null) ...[
              _ErrorBanner(message: _registerError!),
              const SizedBox(height: 16),
            ],

            _AuthField(
              controller: _regUsernameCtrl,
              hint: 'Tên đăng nhập',
              prefixIcon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên đăng nhập' : null,
            ),
            const SizedBox(height: 14),

            _AuthField(
              controller: _regEmailCtrl,
              hint: 'Email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
                if (!v.contains('@')) return 'Email không hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 14),

            _AuthField(
              controller: _regPasswordCtrl,
              hint: 'Mật khẩu',
              prefixIcon: Icons.lock_outline_rounded,
              obscure: _regObscured,
              textInputAction: TextInputAction.next,
              suffixIcon: _toggleObscure(
                visible: !_regObscured,
                onTap: () => setState(() => _regObscured = !_regObscured),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
                if (v.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
                return null;
              },
            ),
            const SizedBox(height: 14),

            _AuthField(
              controller: _regConfirmCtrl,
              hint: 'Xác nhận mật khẩu',
              prefixIcon: Icons.lock_outline_rounded,
              obscure: _regConfirmObscured,
              textInputAction: TextInputAction.done,
              suffixIcon: _toggleObscure(
                visible: !_regConfirmObscured,
                onTap: () => setState(() => _regConfirmObscured = !_regConfirmObscured),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                if (v != _regPasswordCtrl.text) return 'Mật khẩu không khớp';
                return null;
              },
              onFieldSubmitted: (_) => _handleRegister(),
            ),
            const SizedBox(height: 28),

            _SubmitButton(
              label: 'Đăng ký',
              loading: _isSubmitting,
              onTap: _handleRegister,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleObscure({required bool visible, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(
          visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          color: AppTheme.textMuted,
          size: 20,
        ),
      ),
    );
  }
}

// ── Error Banner ──────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1520),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5C2030), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6B), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Auth Field ────────────────────────────────────────────────
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;

  const _AuthField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
      cursorColor: AppTheme.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14, fontWeight: FontWeight.w400),
        prefixIcon: Icon(prefixIcon, color: AppTheme.textMuted, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppTheme.bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 12),
      ),
    );
  }
}

// ── Submit Button ─────────────────────────────────────────────
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment(-0.7, -1),
            end: Alignment(0.7, 1),
            colors: [Color(0xFFFECF59), Color(0xFFFFF1CC)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1A1100)),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF1A1100),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}
