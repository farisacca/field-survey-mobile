import 'dart:convert';

import 'package:field_survey/screens/auth/register.dart';
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
  // =========================================================
  // CONTROLLER
  // =========================================================

  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  // =========================================================
  // VARIABLE
  // =========================================================

  bool isHidden = true;
  bool isLoading = false;

  static const Color primaryColor = Color(0xFF7B1E3A);

  // =========================================================
  // API LOGIN
  // =========================================================

  static const String apiUrl = 'https://sijala.biz.id/api/v1/login';

  // =========================================================
  // LOGIN
  // =========================================================

  Future<void> login() async {
    final email = emailController.text.trim();

    final password = passwordController.text.trim();

    // =======================================================
    // VALIDASI EMAIL
    // =======================================================

    if (email.isEmpty) {
      showMessage('Email wajib diisi', Colors.red);
      return;
    }

    if (!email.contains('@')) {
      showMessage('Email harus menggunakan tanda @', Colors.red);
      return;
    }

    // =======================================================
    // VALIDASI PASSWORD
    // =======================================================

    if (password.isEmpty) {
      showMessage('Password wajib diisi', Colors.red);
      return;
    }

    if (password.length < 6) {
      showMessage('Password minimal 6 karakter', Colors.red);
      return;
    }

    // =======================================================
    // LOADING
    // =======================================================

    setState(() {
      isLoading = true;
    });

    try {
      // =====================================================
      // REQUEST LOGIN
      // =====================================================

      final requestData = {'email': email, 'password': password};

      print('======================================');
      print('REQUEST LOGIN');
      print(requestData);
      print('======================================');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      // =====================================================
      // DEBUG
      // =====================================================

      print('======================================');
      print('LOGIN STATUS: ${response.statusCode}');
      print('LOGIN RESPONSE:');
      print(response.body);
      print('======================================');

      // =====================================================
      // DECODE JSON
      // =====================================================

      dynamic data;

      try {
        data = jsonDecode(response.body);
      } catch (e) {
        data = {};

        print('JSON ERROR: $e');
      }

      // =====================================================
      // LOGIN BERHASIL
      // =====================================================

      if (response.statusCode == 200) {
        print('LOGIN BERHASIL');

        String? token;
        dynamic userData;

        // ===================================================
        // CARI TOKEN
        // ===================================================

        if (data is Map) {
          // -------------------------------------------------
          // FORMAT:
          // {
          //   "token": "xxxxx"
          // }
          // -------------------------------------------------

          if (data['token'] != null) {
            token = data['token'].toString();
          }

          // -------------------------------------------------
          // FORMAT:
          // {
          //   "access_token": "xxxxx"
          // }
          // -------------------------------------------------

          if ((token == null || token.isEmpty) &&
              data['access_token'] != null) {
            token = data['access_token'].toString();
          }

          // -------------------------------------------------
          // FORMAT:
          // {
          //   "data": {
          //      "token": "xxxxx"
          //   }
          // }
          // -------------------------------------------------

          if ((token == null || token.isEmpty) && data['data'] is Map) {
            final dataMap = Map<String, dynamic>.from(data['data']);

            if (dataMap['token'] != null) {
              token = dataMap['token'].toString();
            }

            if ((token == null || token.isEmpty) &&
                dataMap['access_token'] != null) {
              token = dataMap['access_token'].toString();
            }
          }
        }

        // ===================================================
        // DEBUG TOKEN
        // ===================================================

        print('======================================');
        print('TOKEN HASIL LOGIN: $token');
        print('======================================');

        // ===================================================
        // SIMPAN TOKEN
        // ===================================================

        if (token != null && token.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();

          // Hapus token lama terlebih dahulu
          await prefs.remove('token');

          // Simpan token baru
          await prefs.setString('token', token);

          print('======================================');
          print('TOKEN BERHASIL DISIMPAN');
          print('TOKEN: $token');
          print('======================================');

          // Cek ulang token
          final savedToken = prefs.getString('token');

          print('TOKEN DARI STORAGE: $savedToken');
        } else {
          print('======================================');
          print('TOKEN TIDAK DITEMUKAN');
          print('======================================');

          if (!mounted) return;

          showMessage(
            'Login berhasil tetapi token tidak ditemukan',
            Colors.red,
          );

          return;
        }

        // ===================================================
        // CARI DATA USER
        // ===================================================

        if (data is Map) {
          if (data['user'] is Map) {
            userData = data['user'];
          } else if (data['data'] is Map) {
            final dataMap = Map<String, dynamic>.from(data['data']);

            if (dataMap['user'] is Map) {
              userData = dataMap['user'];
            } else {
              userData = dataMap;
            }
          }
        }

        // ===================================================
        // SIMPAN DATA USER
        // ===================================================

        if (userData is Map) {
          final prefs = await SharedPreferences.getInstance();

          await prefs.setString('user', jsonEncode(userData));

          print('======================================');
          print('DATA USER BERHASIL DISIMPAN');
          print(userData);
          print('======================================');
        }

        // ===================================================
        // CEK WIDGET
        // ===================================================

        if (!mounted) return;

        // ===================================================
        // PESAN BERHASIL
        // ===================================================

        showMessage('Login berhasil', Colors.green);

        // ===================================================
        // KE DASHBOARD
        // ===================================================
        //
        // PENTING:
        // Sekarang menggunakan GoRouter,
        // sama seperti logout.
        //
        // ===================================================

        context.go(AppRoutes.dashboard);

        return;
      }

      // =====================================================
      // 404
      // =====================================================

      if (response.statusCode == 404) {
        showMessage('Email tidak ditemukan', Colors.red);
        return;
      }

      // =====================================================
      // 401
      // =====================================================

      if (response.statusCode == 401) {
        String message = 'Email atau password salah';

        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        }

        showMessage(message, Colors.red);

        return;
      }

      // =====================================================
      // ERROR LAIN
      // =====================================================

      String message = 'Login gagal (${response.statusCode})';

      if (data is Map && data['message'] != null) {
        message = data['message'].toString();
      }

      showMessage(message, Colors.red);
    } catch (e) {
      print('======================================');
      print('ERROR LOGIN');
      print(e);
      print('======================================');

      if (!mounted) return;

      showMessage('Tidak dapat terhubung ke server', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // SNACKBAR
  // =========================================================

  void showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),

            child: Column(
              children: [
                // =================================================
                // ICON
                // =================================================
                const Icon(Icons.lock_outline, size: 90, color: primaryColor),

                const SizedBox(height: 20),

                // =================================================
                // TITLE
                // =================================================
                const Text(
                  'Selamat Datang',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Silakan login untuk melanjutkan',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),

                const SizedBox(height: 40),

                // =================================================
                // EMAIL
                // =================================================
                TextField(
                  controller: emailController,

                  keyboardType: TextInputType.emailAddress,

                  decoration: InputDecoration(
                    hintText: 'Email',

                    prefixIcon: const Icon(Icons.email, color: primaryColor),

                    filled: true,
                    fillColor: Colors.white,

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // =================================================
                // PASSWORD
                // =================================================
                TextField(
                  controller: passwordController,

                  obscureText: isHidden,

                  decoration: InputDecoration(
                    hintText: 'Password',

                    prefixIcon: const Icon(Icons.lock, color: primaryColor),

                    suffixIcon: IconButton(
                      icon: Icon(
                        isHidden ? Icons.visibility_off : Icons.visibility,
                        color: primaryColor,
                      ),

                      onPressed: () {
                        setState(() {
                          isHidden = !isHidden;
                        });
                      },
                    ),

                    filled: true,
                    fillColor: Colors.white,

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // =================================================
                // LUPA PASSWORD
                // =================================================
                Align(
                  alignment: Alignment.centerRight,

                  child: TextButton(
                    onPressed: isLoading ? null : () {},

                    child: const Text(
                      'Lupa Password?',
                      style: TextStyle(color: primaryColor),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // =================================================
                // LOGIN BUTTON
                // =================================================
                SizedBox(
                  width: double.infinity,

                  height: 50,

                  child: ElevatedButton(
                    onPressed: isLoading ? null : login,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,

                      foregroundColor: Colors.white,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),

                    child: isLoading
                        ? const SizedBox(
                            width: 25,
                            height: 25,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // =================================================
                // REGISTER
                // =================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    const Text('Belum punya akun?'),

                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterPage(),
                                ),
                              );
                            },

                      child: const Text(
                        'Daftar',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
