import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase/auth_service.dart';
import '../firebase/firestore_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isPasswordVisible = false;
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      
      // 1. Kiểm tra email trong Firestore (dùng chữ thường)
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('Email không tồn tại trong hệ thống.');
      }

      final userData = userQuery.docs.first.data();
      final userId = userQuery.docs.first.id;
      
      // 2. Kiểm tra tài khoản bị khóa
      if (userData['isBanned'] == true) {
        throw Exception('Tài khoản của bạn đã bị khóa. Vui lòng liên hệ hỗ trợ.');
      }

      // 3. Thực hiện đăng nhập
      final user = await _authService.signInWithEmail(
        email,
        _passwordController.text,
      );

      if (!mounted) return;

      if (user != null) {
        // Luôn cập nhật/tạo doc để đảm bảo tính nhất quán
        await FirestoreService.createUserDocument(
          userId: user.uid,
          email: email,
          displayName: user.displayName,
        );
        
        if (!mounted) return;
        
        // Kiểm tra quyền Admin dựa trên UID thực tế
        final isAdmin = await FirestoreService.checkUserIsAdmin(user.uid);
        
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(isAdmin ? '/admin-dashboard' : '/main');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMsg = 'Lỗi đăng nhập';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMsg = 'Mật khẩu không chính xác hoặc tài khoản này chỉ đăng nhập được bằng Google.';
      } else {
        errorMsg = e.message ?? e.code;
      }
      setState(() => _errorMessage = errorMsg);
    } catch (e) {
      if (!mounted) return;
      String errorMsg = e.toString().replaceFirst('Exception: ', '');
      setState(() => _errorMessage = errorMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        await _finishSignIn(user);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential' && e.credential != null) {
        // Email đã tồn tại với phương thức khác (thường là password)
        if (!mounted) return;
        _showLinkAccountDialog(e.email!, e.credential!);
      } else {
        setState(() => _errorMessage = 'Đăng nhập Google thất bại: ${e.message}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Đăng nhập Google thất bại: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finishSignIn(User user) async {
    // Kiểm tra ban
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc.data()?['isBanned'] == true) {
      await _authService.signOut();
      throw Exception('Tài khoản này đã bị khóa.');
    }

    await FirestoreService.createUserDocument(
      userId: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
    );
    
    if (!mounted) return;

    final isAdmin = await FirestoreService.checkUserIsAdmin(user.uid);
    if (!mounted) return;
    
    Navigator.of(context).pushReplacementNamed(isAdmin ? '/admin-dashboard' : '/main');
  }

  void _showLinkAccountDialog(String email, AuthCredential credential) {
    final passController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Liên kết tài khoản'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Email $email đã được đăng ký bằng mật khẩu. Vui lòng nhập mật khẩu để gộp tài khoản Google này vào.'),
            const SizedBox(height: 16),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passController.text.trim();
              if (password.isEmpty) return;
              
              Navigator.pop(context); // Đóng dialog
              setState(() => _isLoading = true);
              
              try {
                final user = await _authService.linkGoogleWithEmail(email, password, credential);
                if (user != null) {
                  await _finishSignIn(user);
                }
              } catch (e) {
                setState(() => _errorMessage = e.toString());
              } finally {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _mintGreen, foregroundColor: Colors.white),
            child: const Text('Xác minh & Gộp'),
          ),
        ],
      ),
    );
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
                  const SizedBox(height: 36),
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _mintGreen,
                        boxShadow: [
                          BoxShadow(
                            color: _mintGreen.withValues(alpha: 0.28),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: _bodyStyle.copyWith(
                      color: _darkText,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sign in to continue listening',
                    textAlign: TextAlign.center,
                    style: _bodyStyle.copyWith(
                      color: _darkText.withValues(alpha: 0.55),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
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
                    textInputAction: TextInputAction.done,
                    style: _bodyStyle.copyWith(color: _darkText, fontSize: 15),
                    decoration: _inputDecoration(
                      label: 'Password',
                      hint: 'Enter your password',
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
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/forgot-password');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: _mintGreen,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                      ),
                      child: Text(
                        'Forgot password?',
                        style: _bodyStyle.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: _buttonStyle(),
                    child: _isLoading
                        ? const _LoadingIndicator()
                        : Text(
                            'Log in',
                            style: _bodyStyle.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: Divider(color: _darkText.withValues(alpha: 0.15), thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: _bodyStyle.copyWith(
                            color: _darkText.withValues(alpha: 0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: _darkText.withValues(alpha: 0.15), thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    style: _outlinedButtonStyle(),
                    icon: Icon(Icons.g_mobiledata_rounded, size: 22, color: _darkText),
                    label: Text(
                      'Continue with Google',
                      style: _bodyStyle.copyWith(
                        color: _darkText,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: _bodyStyle.copyWith(
                          color: _darkText.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushNamed('/register'),
                        style: TextButton.styleFrom(
                          foregroundColor: _mintGreen,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                        ),
                        child: Text(
                          'Sign up',
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

  ButtonStyle _outlinedButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _darkText,
      side: const BorderSide(color: _mintGreen, width: 1.2),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
