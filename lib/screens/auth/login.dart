import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:field_survey/routes/app_routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isHidden = true;
  bool isLoading = false;

  static const primaryColor = Color(0xFF800020);
  static const darkBurgundy = Color(0xFF4A0E12);
  static const bgColor = Color(0xFFFFF4F5);
  static const successColor = Color(0xFF2E7D32);
  static const errorColor = Color(0xFFC62828);

  static const apiUrl = 'https://sijala.biz.id/api/v1/login';

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty) {
      showMessage('Email wajib diisi', errorColor, Icons.error_outline);
      return;
    }
    if (!email.contains('@')) {
      showMessage(
        'Format email tidak valid',
        errorColor,
        Icons.alternate_email,
      );
      return;
    }
    if (password.isEmpty) {
      showMessage('Password wajib diisi', errorColor, Icons.lock_outline);
      return;
    }

    setState(() => isLoading = true);
    try {
      final res = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));

      dynamic data;
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        data = {};
      }

      if (res.statusCode == 200) {
        String? token =
            data['token']?.toString() ?? data['access_token']?.toString();
        if ((token == null || token.isEmpty) && data['data'] is Map) {
          final m = Map<String, dynamic>.from(data['data']);
          token = m['token']?.toString() ?? m['access_token']?.toString();
        }
        if (token == null || token.isEmpty) {
          showMessage(
            'Token tidak ditemukan',
            errorColor,
            Icons.warning_amber_rounded,
          );
          return;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        if (data['user'] is Map)
          await prefs.setString('user', jsonEncode(data['user']));
        if (!mounted) return;
        showMessage(
          'Login berhasil! Selamat datang',
          successColor,
          Icons.check_circle,
        );
        context.go(AppRoutes.dashboard);
      } else {
        String msg = data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Login gagal';
        showMessage(msg, errorColor, Icons.error_outline);
      }
    } catch (e) {
      showMessage(
        'Tidak dapat terhubung ke server',
        errorColor,
        Icons.wifi_off_rounded,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showMessage(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF4B5B5).withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8A0A0).withOpacity(0.35),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  // BRANDING HEADER
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB02A37), Color(0xFF800020)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'FIELD SURVEY',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: darkBurgundy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 35),

                  // CARD FORM
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Masuk Akun',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: darkBurgundy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Masukkan email dan password kamu',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 26),

                        _buildField(
                          controller: emailController,
                          label: 'Email Address',
                          icon: Icons.email_outlined,
                          hint: 'nama@email.com',
                          keyboard: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 18),
                        _buildField(
                          controller: passwordController,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          hint: '••••••••',
                          isPassword: true,
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Lupa Password?',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                              shadowColor: primaryColor.withOpacity(0.4),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'MASUK SEKARANG',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Belum punya akun?',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13.5,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push(AppRoutes.register),
                              child: const Text(
                                'Daftar di sini',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'v1.0 • Secure Field Survey App',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboard,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: darkBurgundy,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          obscureText: isPassword ? isHidden : false,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: primaryColor, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isHidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey.shade500,
                      size: 20,
                    ),
                    onPressed: () => setState(() => isHidden = !isHidden),
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFFDF2F4),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
