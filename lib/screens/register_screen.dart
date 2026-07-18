import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../firebase/auth_service.dart';
import '../firebase/firestore_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  static const _white = Color(0xFFFFFFFF);
  static const _lightSurface = Color(0xFFF2F4F1);
  static const _mintGreen = Color(0xFF0E6B5A);
  static const _darkText = Color(0xFF0A1F1A);

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (user != null) {
        await _authService.updateProfile(displayName: _nameController.text.trim());
        await FirestoreService.createUserDocument(
          userId: user.uid,
          email: user.email ?? _emailController.text.trim(),
          displayName: _nameController.text.trim(),
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/main');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  TextStyle get _bodyStyle => const TextStyle(
        fontFamily: 'Roboto',
        fontFamilyFallback: ['Helvetica', 'Arial', 'sans-serif'],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_rounded, color: _darkText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _mintGreen,
                        boxShadow: [
                          BoxShadow(
                            color: _mintGreen.withOpacity(0.28),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_add_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Create account',
                    textAlign: TextAlign.center,
                    style: _bodyStyle.copyWith(
                      color: _darkText,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign up to start listening',
                    textAlign: TextAlign.center,
                    style: _bodyStyle.copyWith(
                      color: _darkText.withOpacity(0.55),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    style: _bodyStyle.copyWith(color: _darkText, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Full name',
                      labelStyle: _bodyStyle.copyWith(
                        color: _darkText.withOpacity(0.65),
                        fontSize: 14,
                      ),
                      hintText: 'Enter your name',
                      hintStyle: _bodyStyle.copyWith(
                        color: _darkText.withOpacity(0.35),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(Icons.person_outline_rounded, color: _darkText.withOpacity(0.55)),
                      filled: true,
                      fillColor: _lightSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: _mintGreen, width: 1.4),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.red.shade400),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng nhập tên';
                      if (value.length < 2) return 'Tên quá ngắn';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: _bodyStyle.copyWith(color: _darkText, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: _bodyStyle.copyWith(
                        color: _darkText.withOpacity(0.65),
                        fontSize: 14,
                      ),
                      hintText: 'you@example.com',
                      hintStyle: _bodyStyle.copyWith(
                        color: _darkText.withOpacity(0.35),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(Icons.email_outlined, color: _darkText.withOpacity(0.55)),
                      filled: true,
                      fillColor: _lightSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: _mintGreen, width: 1.4),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.red.shade400),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng nhập email';
                      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                      if (!emailRegex.hasMatch(value)) return 'Email không hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    textInputAction: TextInputAction.next,
                    style: _bodyStyle.copyWith(color: _darkText, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: _bodyStyle.copyWith(
                        color: _darkText.withOpacity(0.65),
                        fontSize: 14,
                      ),
                      hintText: 'At least 6 characters',
                      hintStyle: _bodyStyle.copyWith(
                        color: _darkText.withOpacity(0.35),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: _darkText.withOpacity(0.55)),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: _darkText.withOpacity(0.55),
                        ),
                      ),
                      filled: true,
                      fillColor: _lightSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: _mintGreen, width: 1.4),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.red.shade400),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
                      if (value.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    textInputAction: TextInputAction.done,
                    style: _bodyStyle.copyWith(color: _darkText, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      labelStyle: _bodyStyle.copyWith(
                        color: _darkText.withOpacity(0.65),
                        fontSize: 14,
                      ),
                      hintText: 'Re-enter your password',
                      hintStyle: _bodyStyle.copyWith(
                        color: _darkText.withOpacity(0.35),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: _darkText.withOpacity(0.55)),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                        icon: Icon(
                          _isConfirmPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: _darkText.withOpacity(0.55),
                        ),
                      ),
                      filled: true,
                      fillColor: _lightSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: _mintGreen, width: 1.4),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.red.shade400),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                      if (value != _passwordController.text) return 'Mật khẩu không khớp';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: _bodyStyle.copyWith(
                                color: Colors.red.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mintGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _mintGreen.withOpacity(0.7),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                      shadowColor: _mintGreen.withOpacity(0.25),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'Sign up',
                            style: _bodyStyle.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: _bodyStyle.copyWith(
                          color: _darkText.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: _mintGreen,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                        ),
                        child: Text(
                          'Log in',
                          style: _bodyStyle.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
