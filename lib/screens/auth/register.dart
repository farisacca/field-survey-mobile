
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color lightBlue = Color(0xFFE3F0FF);

  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  String? gender;
  bool isLoading = false;

  static const String registerUrl =
      'https://sijala.biz.id/api/v1/register';

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  
  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: !isLoading,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: primaryColor,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: primaryColor,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: Colors.red,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 2,
            ),
          ),
        ),
        validator: validator,
      ),
    );
  }

  // REGISTER
  Future<void> register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih jenis kelamin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final requestData = {
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'gender': gender,
      };

      debugPrint('Request Register: $requestData');

      final response = await http
          .post(
            Uri.parse(registerUrl),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestData),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('Register Status: ${response.statusCode}');
      debugPrint('Register Response: ${response.body}');

      dynamic data;

      try {
        data = jsonDecode(response.body);
      } catch (e) {
        data = {};
      }

      // REGISTER BERHASIL
      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        if (!mounted) return;

        String message = 'Registrasi berhasil';

        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        }

        // Simpan data user jika API mengembalikannya.
        // Registrasi tidak otomatis dianggap sebagai login.
        dynamic userData;

        if (data is Map && data['user'] is Map) {
          userData = data['user'];
        } else if (data is Map && data['data'] is Map) {
          final dataMap = data['data'];

          if (dataMap['user'] is Map) {
            userData = dataMap['user'];
          } else {
            userData = dataMap;
          }
        }

        if (userData is Map) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('registered_user', jsonEncode(userData));
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: primaryColor,
          ),
        );

        // Kembali ke halaman login.
        Navigator.pop(context);
      }

      // VALIDASI GAGAL
      else if (response.statusCode == 422) {
        if (!mounted) return;

        String message = 'Validasi gagal';

        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        }

        if (data is Map && data['errors'] is Map) {
          final errors = data['errors'] as Map;
          final List<String> errorMessages = [];

          errors.forEach((key, value) {
            if (value is List) {
              for (final error in value) {
                errorMessages.add(error.toString());
              }
            } else if (value != null) {
              errorMessages.add(value.toString());
            }
          });

          if (errorMessages.isNotEmpty) {
            message = errorMessages.join('\n');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // klo error
      else {
        if (!mounted) return;

        String message =
            'Registrasi gagal (${response.statusCode})';

        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error Register: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat terhubung ke server'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  // BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Register',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              color: Colors.white,
              elevation: 4,
              shadowColor: primaryColor.withOpacity(0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ICON
                      const CircleAvatar(
                        radius: 38,
                        backgroundColor: lightBlue,
                        child: Icon(
                          Icons.person_add_alt_1,
                          color: primaryColor,
                          size: 40,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // JUDUL
                      const Text(
                        'REGISTER',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Lengkapi data diri Anda',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // NAMA
                      buildTextField(
                        controller: nameController,
                        label: 'Nama Lengkap',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama wajib diisi';
                          }
                          return null;
                        },
                      ),

                      // JENIS KELAMIN
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: DropdownButtonFormField<String>(
                          value: gender,
                          decoration: InputDecoration(
                            labelText: 'Jenis Kelamin',
                            prefixIcon: const Icon(
                              Icons.people_outline,
                              color: primaryColor,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                color: primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'L',
                              child: Text('Laki-laki'),
                            ),
                            DropdownMenuItem(
                              value: 'P',
                              child: Text('Perempuan'),
                            ),
                          ],
                          onChanged: isLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    gender = value;
                                  });
                                },
                          validator: (value) {
                            if (value == null) {
                              return 'Jenis kelamin wajib dipilih';
                            }
                            return null;
                          },
                        ),
                      ),

                      // EMAIL
                      buildTextField(
                        controller: emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Email wajib diisi';
                          }
                          if (!value.contains('@')) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),

                      // NOMOR HANDPHONE
                      buildTextField(
                        controller: phoneController,
                        label: 'Nomor Handphone',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nomor handphone wajib diisi';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 8),

                      // TOMBOL REGISTER
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.blue.shade200,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : const Text(
                                  'REGISTER',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // KEMBALI KE LOGIN
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                Navigator.pop(context);
                              },
                        child: const Text(
                          'Sudah punya akun? Login',
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
