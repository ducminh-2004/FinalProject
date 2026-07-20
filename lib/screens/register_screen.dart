import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase/auth_service.dart';
import '../firebase/firestore_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _authService = AuthService();
  
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isOtpSent = false;
  String? _errorMessage;
  
  // EmailJS & OTP logic
  String? _generatedOtp;
  Timer? _timer;
  int _start = 300; // 5 minutes in seconds

  // EmailJS Configuration
  final String _serviceId = 'service_ky79q9o';
  final String _templateId = 'template_v8p9v6v';
  final String _publicKey = 'afvpqN1eybYJVgPq_';

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
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void startTimer() {
    _timer?.cancel();
    _start = 300;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  String get timerText {
    int minutes = _start ~/ 60;
    int seconds = _start % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _generateRandomOtp() {
    final random = Random();
    String otp = '';
    for (int i = 0; i < 6; i++) {
      otp += random.nextInt(10).toString();
    }
    return otp;
  }

  Future<void> _sendEmailJS(String email, String otp) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'to_email': email,
          'to_name': _nameController.text.trim(),
          'otp': otp,
          'app_name': 'Spotify Clone',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Lỗi gửi mail: ${response.body}');
    }
  }

  Future<void> _handleSendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Kiểm tra Email đã tồn tại chưa
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      if (userQuery.docs.isNotEmpty) {
        throw Exception('Email này đã được sử dụng cho một tài khoản khác.');
      }

      final otp = _generateRandomOtp();
      await _sendEmailJS(_emailController.text.trim(), otp);
      
      setState(() {
        _generatedOtp = otp;
        _isOtpSent = true;
        _isLoading = false;
      });
      startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mã OTP đã được gửi đến email của bạn")),
        );
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('Exception: ')) errorMsg = errorMsg.split('Exception: ').last;
      setState(() {
        _isLoading = false;
        _errorMessage = errorMsg;
      });
    }
  }

  Future<void> _handleVerifyOTP() async {
    if (!_otpFormKey.currentState!.validate()) return;
    if (_start == 0) {
      setState(() => _errorMessage = "Mã OTP đã hết hạn. Vui lòng gửi lại.");
      return;
    }

    if (_otpController.text.trim() != _generatedOtp) {
      setState(() => _errorMessage = "Mã OTP không chính xác.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // OTP Success, proceed to create account
      final user = await _authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user != null) {
        await _authService.updateProfile(displayName: _nameController.text.trim());
        await FirestoreService.createUserDocument(
          userId: user.uid,
          email: user.email ?? _emailController.text.trim(),
          displayName: _nameController.text.trim(),
        );
        
        if (!mounted) return;
        
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text("Thành công"),
              ],
            ),
            content: const Text("Tài khoản của bạn đã được tạo thành công!"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pushReplacementNamed('/main');
                },
                child: const Text("Bắt đầu ngay", style: TextStyle(color: _mintGreen, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('Exception: ')) errorMsg = errorMsg.split('Exception: ').last;
      setState(() {
        _errorMessage = errorMsg;
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
            child: _isOtpSent ? _buildOtpForm() : _buildRegisterForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: _darkText),
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
                    color: _mintGreen.withValues(alpha: 0.28),
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
              color: _darkText.withValues(alpha: 0.55),
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
            decoration: _inputDecoration(
              label: 'Full name',
              hint: 'Enter your name',
              icon: Icons.person_outline_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Họ tên không được để trống.';
              if (value.trim().length < 2) return 'Tên quá ngắn.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: _bodyStyle.copyWith(color: _darkText, fontSize: 15),
            decoration: _inputDecoration(
              label: 'Email',
              hint: 'you@example.com',
              icon: Icons.email_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Email không được để trống.';
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
              if (!emailRegex.hasMatch(value.trim())) return 'Email phải đúng định dạng.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.next,
            style: _bodyStyle.copyWith(color: _darkText, fontSize: 15),
            decoration: _inputDecoration(
              label: 'Password',
              hint: 'At least 8 characters',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: _darkText.withValues(alpha: 0.55),
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Mật khẩu không được để trống.';
              if (value.length < 8) return 'Mật khẩu tối thiểu 8 ký tự.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_isConfirmPasswordVisible,
            textInputAction: TextInputAction.done,
            style: _bodyStyle.copyWith(color: _darkText, fontSize: 15),
            decoration: _inputDecoration(
              label: 'Confirm password',
              hint: 'Re-enter your password',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                icon: Icon(
                  _isConfirmPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: _darkText.withValues(alpha: 0.55),
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Xác nhận mật khẩu không được để trống.';
              if (value != _passwordController.text) return 'Xác nhận mật khẩu phải giống mật khẩu.';
              return null;
            },
          ),
          const SizedBox(height: 10),
          if (_errorMessage != null) _buildErrorContainer(),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSendOTP,
            style: _buttonStyle(),
            child: _isLoading
                ? const _LoadingIndicator()
                : Text('Sign up', style: _bodyStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          const SizedBox(height: 24),
          _buildLoginRedirect(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOtpForm() {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _isOtpSent = false;
                  _timer?.cancel();
                  _errorMessage = null;
                }),
                icon: const Icon(Icons.arrow_back_rounded, color: _darkText),
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
                    color: _mintGreen.withValues(alpha: 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Xác nhận Email',
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
            'Chúng tôi đã gửi mã OTP đến\n${_emailController.text}',
            textAlign: TextAlign.center,
            style: _bodyStyle.copyWith(
              color: _darkText.withValues(alpha: 0.55),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: _bodyStyle.copyWith(
              color: _darkText, 
              fontSize: 24, 
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            decoration: _inputDecoration(
              label: 'Mã OTP',
              hint: '000000',
              icon: Icons.security_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Vui lòng nhập mã OTP.';
              if (value.trim().length != 6) return 'Mã OTP phải có 6 chữ số.';
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: 16, color: _start < 60 ? Colors.red : _darkText.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                "Mã hết hạn trong: ",
                style: _bodyStyle.copyWith(color: _darkText.withValues(alpha: 0.6), fontSize: 13),
              ),
              Text(
                timerText,
                style: _bodyStyle.copyWith(
                  color: _start < 60 ? Colors.red : _mintGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_errorMessage != null) _buildErrorContainer(),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleVerifyOTP,
            style: _buttonStyle(),
            child: _isLoading
                ? const _LoadingIndicator()
                : Text('Xác nhận & Đăng ký', style: _bodyStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _start == 0 && !_isLoading ? _handleSendOTP : null,
            child: Text(
              _start == 0 ? "Gửi lại mã OTP" : "Gửi lại sau ($timerText)",
              style: _bodyStyle.copyWith(
                color: _start == 0 ? _mintGreen : _darkText.withValues(alpha: 0.4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: _bodyStyle.copyWith(color: _darkText.withValues(alpha: 0.65), fontSize: 14),
      hintText: hint,
      hintStyle: _bodyStyle.copyWith(color: _darkText.withValues(alpha: 0.35), fontSize: 14),
      prefixIcon: Icon(icon, color: _darkText.withValues(alpha: 0.55)),
      suffixIcon: suffix,
      filled: true,
      fillColor: _lightSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _mintGreen, width: 1.4)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.red.shade400)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _mintGreen,
      foregroundColor: Colors.white,
      disabledBackgroundColor: _mintGreen.withValues(alpha: 0.7),
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
    );
  }

  Widget _buildErrorContainer() {
    return Container(
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
              style: _bodyStyle.copyWith(color: Colors.red.shade700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginRedirect() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: _bodyStyle.copyWith(color: _darkText.withValues(alpha: 0.6), fontSize: 13),
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
            style: _bodyStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 22,
      width: 22,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}
