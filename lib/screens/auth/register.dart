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
  static const Color primaryColor = Color(0xFF7B1E3A);

  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  String? gender;

  bool isLoading = false;

  // =========================================================
  // API REGISTER
  // =========================================================

  final String registerUrl =
      'https://sijala.biz.id/api/v1/register';

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();

    super.dispose();
  }

  // =========================================================
  // TEXT FIELD
  // =========================================================

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
        ),

        validator: validator,
      ),
    );
  }

  // =========================================================
  // REGISTER
  // =========================================================

  Future<void> register() async {
    // -------------------------------------------------------
    // VALIDASI FORM
    // -------------------------------------------------------

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // -------------------------------------------------------
    // VALIDASI GENDER
    // -------------------------------------------------------

    if (gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Silakan pilih jenis kelamin',
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    // -------------------------------------------------------
    // LOADING
    // -------------------------------------------------------

    setState(() {
      isLoading = true;
    });

    try {
      // =====================================================
      // REQUEST DATA
      // =====================================================

      final requestData = {
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),

        // API meminta L atau P
        'gender': gender,
      };

      print('Request Register: $requestData');

      // =====================================================
      // REQUEST POST API
      // =====================================================

      final response = await http.post(
        Uri.parse(
          'https://sijala.biz.id/api/v1/register',
        ),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestData),
      );

      // =====================================================
      // DEBUG
      // =====================================================

      print(
        'Register Status Code: ${response.statusCode}',
      );

      print(
        'Register Response: ${response.body}',
      );

      // =====================================================
      // DECODE RESPONSE
      // =====================================================

      dynamic data;

      try {
        data = jsonDecode(response.body);
      } catch (e) {
        data = {};
      }

      // =====================================================
      // REGISTER BERHASIL
      // =====================================================

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        if (!mounted) return;

        String message = 'Registrasi berhasil';

        if (data is Map &&
            data['message'] != null) {
          message = data['message'].toString();
        }

        // ---------------------------------------------------
        // SIMPAN DATA REGISTER SEMENTARA
        // ---------------------------------------------------

        final prefs =
            await SharedPreferences.getInstance();

        dynamic userData;

        if (data is Map && data['user'] != null) {
          userData = data['user'];
        } else if (data is Map &&
            data['data'] != null) {
          userData = data['data'];
        }

        if (userData != null) {
          await prefs.setString(
            'user',
            jsonEncode(userData),
          );
        }

        // ---------------------------------------------------
        // PESAN BERHASIL
        // ---------------------------------------------------

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );

        // ---------------------------------------------------
        // KEMBALI KE LOGIN
        // ---------------------------------------------------

        Navigator.pop(context);
      }

      // =====================================================
      // VALIDASI GAGAL
      // =====================================================

      else if (response.statusCode == 422) {
        if (!mounted) return;

        String message = 'Validasi gagal';

        if (data is Map &&
            data['message'] != null) {
          message = data['message'].toString();
        }

        // ---------------------------------------------------
        // AMBIL DETAIL ERROR
        // ---------------------------------------------------

        if (data is Map &&
            data['errors'] is Map) {
          final errors = data['errors'] as Map;

          List<String> errorMessages = [];

          errors.forEach((key, value) {
            if (value is List) {
              for (final error in value) {
                errorMessages.add(
                  error.toString(),
                );
              }
            }
          });

          if (errorMessages.isNotEmpty) {
            message =
                errorMessages.join('\n');
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

      // =====================================================
      // ERROR LAIN
      // =====================================================

      else {
        if (!mounted) return;

        String message =
            'Registrasi gagal (${response.statusCode})';

        if (data is Map &&
            data['message'] != null) {
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
      // =====================================================
      // ERROR CONNECTION
      // =====================================================

      print('Error Register: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak dapat terhubung ke server',
          ),
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

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: Card(
              elevation: 5,

              shadowColor: Colors.black12,

              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(25),
              ),

              child: Padding(
                padding: const EdgeInsets.all(28),

                child: Form(
                  key: _formKey,

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,

                    children: [
                      // =================================================
                      // ICON
                      // =================================================

                      const CircleAvatar(
                        radius: 38,

                        backgroundColor:
                            primaryColor,

                        child: Icon(
                          Icons.person_add_alt_1,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // =================================================
                      // TITLE
                      // =================================================

                      const Text(
                        'REGISTER',

                        textAlign:
                            TextAlign.center,

                        style: TextStyle(
                          fontSize: 27,
                          fontWeight:
                              FontWeight.bold,
                          color:
                              primaryColor,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Lengkapi data diri Anda',

                        textAlign:
                            TextAlign.center,

                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // =================================================
                      // NAMA
                      // =================================================

                      buildTextField(
                        controller:
                            nameController,
                        label:
                            'Nama Lengkap',
                        icon:
                            Icons.person_outline,

                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Nama wajib diisi';
                          }

                          return null;
                        },
                      ),

                      // =================================================
                      // GENDER
                      // =================================================

                      DropdownButtonFormField<String>(
                        value: gender,

                        decoration:
                            InputDecoration(
                          labelText:
                              'Jenis Kelamin',

                          prefixIcon:
                              const Icon(
                            Icons.people_outline,
                            color:
                                primaryColor,
                          ),

                          filled: true,
                          fillColor:
                              Colors.white,

                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                                    15),
                          ),

                          enabledBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                                    15),

                            borderSide:
                                BorderSide(
                              color: Colors
                                  .grey
                                  .shade300,
                            ),
                          ),

                          focusedBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                                    15),

                            borderSide:
                                const BorderSide(
                              color:
                                  primaryColor,
                              width: 2,
                            ),
                          ),
                        ),

                        items: const [
                          DropdownMenuItem(
                            value: 'L',
                            child:
                                Text('Laki-laki'),
                          ),

                          DropdownMenuItem(
                            value: 'P',
                            child:
                                Text('Perempuan'),
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

                      const SizedBox(height: 18),

                      // =================================================
                      // EMAIL
                      // =================================================

                      buildTextField(
                        controller:
                            emailController,

                        label: 'Email',

                        icon:
                            Icons.email_outlined,

                        keyboardType:
                            TextInputType
                                .emailAddress,

                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Email wajib diisi';
                          }

                          if (!value
                              .contains('@')) {
                            return 'Format email tidak valid';
                          }

                          return null;
                        },
                      ),

                      // =================================================
                      // PHONE
                      // =================================================

                      buildTextField(
                        controller:
                            phoneController,

                        label:
                            'Nomor Handphone',

                        icon:
                            Icons.phone_outlined,

                        keyboardType:
                            TextInputType.phone,

                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Nomor handphone wajib diisi';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 10),

                      // =================================================
                      // BUTTON REGISTER
                      // =================================================

                      SizedBox(
                        height: 55,

                        child:
                            ElevatedButton(
                          onPressed:
                              isLoading
                                  ? null
                                  : register,

                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                primaryColor,

                            foregroundColor:
                                Colors.white,

                            elevation: 0,

                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      15),
                            ),
                          ),

                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,

                                  child:
                                      CircularProgressIndicator(
                                    color:
                                        Colors.white,
                                    strokeWidth:
                                        3,
                                  ),
                                )
                              : const Text(
                                  'REGISTER',

                                  style:
                                      TextStyle(
                                    fontSize:
                                        17,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // =================================================
                      // LOGIN
                      // =================================================

                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                Navigator.pop(
                                  context,
                                );
                              },

                        child: const Text(
                          'Sudah punya akun? Login',

                          style: TextStyle(
                            color:
                                primaryColor,
                            fontWeight:
                                FontWeight.w600,
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