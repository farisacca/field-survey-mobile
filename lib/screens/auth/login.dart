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
  // menghubungkn text filed dgn contollr
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // VARIABLE
  bool isHidden = true;
  bool isLoading = false;


  static const Color primaryColor = Color(0xFF1976D2);
  static const Color backgroundColor = Color(0xFFF5F9FF);

  // API LOGIN
  static const String apiUrl = 'https://sijala.biz.id/api/v1/login';

  // LOGIN
  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    // VALIDASI EMAIL
    if (email.isEmpty) {
      showMessage('Email wajib diisi', Colors.red);
      return;
    }

    if (!email.contains('@')) {
      showMessage('Email harus menggunakan tanda @', Colors.red);
      return;
    }

    // VALIDASI PASSWORD
    if (password.isEmpty) {
      showMessage('Password wajib diisi', Colors.red);
      return;
    }

    if (password.length < 6) {
      showMessage('Password minimal 6 karakter', Colors.red);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final requestData = {
        'email': email,
        'password': password,
      };

      debugPrint('REQUEST LOGIN: $requestData');

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('LOGIN STATUS: ${response.statusCode}');
      debugPrint('LOGIN RESPONSE: ${response.body}');

      dynamic data;

      try {
        data = jsonDecode(response.body);
      } catch (e) {
        debugPrint('JSON ERROR: $e');
        data = {};
      }

      // LOGIN BERHASIL
      if (response.statusCode == 200) {
        String? token;
        dynamic userData;

        if (data is Map) {
          if (data['token'] != null) {
            token = data['token'].toString();
          }

          if ((token == null || token.isEmpty) &&
              data['access_token'] != null) {
            token = data['access_token'].toString();
          }

          if ((token == null || token.isEmpty) &&
              data['data'] is Map) {
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

        // TOKEN TIDAK DITEMUKAN
        if (token == null || token.isEmpty) {
          if (!mounted) return;

          showMessage(
            'Login berhasil tetapi token tidak ditemukan',
            Colors.red,
          );
          return;
        }

        // SIMPAN TOKEN
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('token', token);

        debugPrint('TOKEN BERHASIL DISIMPAN');

        // AMBIL DATA USER
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

        // SIMPAN DATA USER
        if (userData is Map) {
          await prefs.setString('user', jsonEncode(userData));
        }

        if (!mounted) return;

        showMessage('Login berhasil', Colors.green);

        // KE DASHBOARD
        context.go(AppRoutes.dashboard);
        return;
      }

      // EMAIL TIDAK DITEMUKAN
      if (response.statusCode == 404) {
        showMessage('Email tidak ditemukan', Colors.red);
        return;
      }

      // EMAIL ATAU PASSWORD SALAH
      if (response.statusCode == 401) {
        String message = 'Email atau password salah';

        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        }

        showMessage(message, Colors.red);
        return;
      }

      // ERROR LAINNYA
      String message = 'Login gagal (${response.statusCode})';

      if (data is Map && data['message'] != null) {
        message = data['message'].toString();
      }

      showMessage(message, Colors.red);
    } catch (e) {
      debugPrint('ERROR LOGIN: $e');

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

  // SNACKBAR
  void showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  // DISPOSE
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              children: [
                // ICON
                const Icon(
                  Icons.lock_outline,
                  size: 90,
                  color: primaryColor,
                ),

                const SizedBox(height: 20),

                // TITLE
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
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 40),

                // EMAIL
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    prefixIcon: const Icon(
                      Icons.email,
                      color: primaryColor,
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

                const SizedBox(height: 20),

                // PASSWORD
                TextField(
                  controller: passwordController,
                  obscureText: isHidden,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(
                      Icons.lock,
                      color: primaryColor,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isHidden
                            ? Icons.visibility_off
                            : Icons.visibility,
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

                // LUPA PASSWORD
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

                // LOGIN BUTTON
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

                // REGISTER
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Belum punya akun?'),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              context.push(AppRoutes.register);
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
