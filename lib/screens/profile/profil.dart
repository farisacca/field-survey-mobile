import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // =========================================================
  // COLOR
  // =========================================================

  static const Color primaryColor = Color(0xFF7B1E3A);

  // =========================================================
  // API
  // =========================================================

  final String profileUrl =
      'https://sijala.biz.id/api/v1/profile';

  final String updateProfileUrl =
      'https://sijala.biz.id/api/v1/profile/update';

  // =========================================================
  // DATA PROFILE
  // =========================================================

  String nama = '-';
  String email = '-';
  String phone = '-';
  String gender = '-';
  String tempatLahir = '-';
  String tanggalLahir = '-';

  bool isLoading = true;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  // =========================================================
  // SHOW ERROR
  // =========================================================

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // =========================================================
  // SHOW SUCCESS
  // =========================================================

  void showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // =========================================================
  // GET PROFILE
  // =========================================================

  Future<void> loadProfile() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      debugPrint('========================================');
      debugPrint('GET PROFILE');
      debugPrint('TOKEN ADA: ${token != null && token.isNotEmpty}');
      debugPrint('URL: $profileUrl');
      debugPrint('========================================');

      if (token == null || token.isEmpty) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        showError(
          'Token login tidak ditemukan. Silakan login kembali.',
        );

        return;
      }

      final response = await http.get(
        Uri.parse(profileUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('========================================');
      debugPrint('PROFILE STATUS: ${response.statusCode}');
      debugPrint('PROFILE RESPONSE: ${response.body}');
      debugPrint('========================================');

      if (response.statusCode == 200) {
        dynamic data;

        try {
          data = jsonDecode(response.body);
        } catch (e) {
          debugPrint('JSON ERROR: $e');

          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }

          showError('Response dari server tidak valid.');
          return;
        }

        dynamic userData;

        // Response:
        // {
        //   "data": {...}
        // }

        if (data is Map && data['data'] != null) {
          userData = data['data'];
        }

        // Response:
        // {
        //   "user": {...}
        // }

        else if (data is Map && data['user'] != null) {
          userData = data['user'];
        }

        // Response langsung object

        else {
          userData = data;
        }

        if (userData is Map) {
          if (!mounted) return;

          setState(() {
            nama = _getValue(
              userData,
              [
                'name',
                'nama',
                'nama_lengkap',
              ],
            );

            email = _getValue(
              userData,
              [
                'email',
              ],
            );

            phone = _getValue(
              userData,
              [
                'phone',
                'no_hp',
                'nomor_hp',
                'telephone',
                'no_telepon',
              ],
            );

            gender = _getValue(
              userData,
              [
                'gender',
                'jenis_kelamin',
              ],
            );

            tempatLahir = _getValue(
              userData,
              [
                'birth_place',
                'tempat_lahir',
                'place_of_birth',
              ],
            );

            tanggalLahir = _getValue(
              userData,
              [
                'birth_date',
                'tanggal_lahir',
                'date_of_birth',
              ],
            );

            isLoading = false;
          });

          await prefs.setString(
            'user',
            jsonEncode(userData),
          );
        } else {
          if (!mounted) return;

          setState(() {
            isLoading = false;
          });

          showError(
            'Data profile tidak ditemukan.',
          );
        }
      }

      // =====================================================
      // 401
      // =====================================================

      else if (response.statusCode == 401) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        showError(
          'Sesi login sudah berakhir. Silakan login kembali.',
        );
      }

      // =====================================================
      // ERROR
      // =====================================================

      else {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        String message =
            'Gagal mengambil profile (${response.statusCode}).';

        try {
          final errorData = jsonDecode(response.body);

          if (errorData is Map &&
              errorData['message'] != null) {
            message = errorData['message'].toString();
          }
        } catch (_) {}

        showError(message);
      }
    } catch (e) {
      debugPrint('========================================');
      debugPrint('GET PROFILE ERROR');
      debugPrint(e.toString());
      debugPrint('========================================');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showError(
        'Tidak dapat terhubung ke server.',
      );
    }
  }

  // =========================================================
  // AMBIL VALUE DARI JSON
  // =========================================================

  String _getValue(
    Map data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value != null &&
          value.toString().trim().isNotEmpty &&
          value.toString() != 'null') {
        return value.toString();
      }
    }

    return '-';
  }

  // =========================================================
  // UPDATE PROFILE
  // =========================================================

  Future<bool> updateProfile({
    required String namaBaru,
    required String emailBaru,
    required String phoneBaru,
    required String genderBaru,
    required String tempatLahirBaru,
    required String tanggalLahirBaru,
  }) async {
    bool loadingShown = false;

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      debugPrint('========================================');
      debugPrint('UPDATE PROFILE');
      debugPrint(
        'TOKEN ADA: ${token != null && token.isNotEmpty}',
      );
      debugPrint('URL: $updateProfileUrl');
      debugPrint('========================================');

      if (token == null || token.isEmpty) {
        showError(
          'Token login tidak ditemukan.',
        );

        return false;
      }

      // =====================================================
      // VALIDASI
      // =====================================================

      if (namaBaru.trim().isEmpty) {
        showError(
          'Nama tidak boleh kosong.',
        );
        return false;
      }

      if (emailBaru.trim().isEmpty) {
        showError(
          'Email tidak boleh kosong.',
        );
        return false;
      }

      if (phoneBaru.trim().isEmpty) {
        showError(
          'Nomor HP tidak boleh kosong.',
        );
        return false;
      }

      if (genderBaru.trim().isEmpty) {
        showError(
          'Jenis kelamin harus dipilih.',
        );
        return false;
      }

      if (tempatLahirBaru.trim().isEmpty) {
        showError(
          'Tempat lahir tidak boleh kosong.',
        );
        return false;
      }

      if (tanggalLahirBaru.trim().isEmpty) {
        showError(
          'Tanggal lahir harus dipilih.',
        );
        return false;
      }

      // =====================================================
      // LOADING
      // =====================================================

      if (!mounted) return false;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return const Center(
            child: CircularProgressIndicator(
              color: primaryColor,
            ),
          );
        },
      );

      loadingShown = true;

      // =====================================================
      // MULTIPART REQUEST
      // =====================================================

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(updateProfileUrl),
      );

      // =====================================================
      // HEADER
      // =====================================================

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      // =====================================================
      // DATA
      // =====================================================

      request.fields['name'] =
          namaBaru.trim();

      request.fields['email'] =
          emailBaru.trim();

      request.fields['phone'] =
          phoneBaru.trim();

      request.fields['gender'] =
          genderBaru.trim();

      request.fields['birth_place'] =
          tempatLahirBaru.trim();

      request.fields['birth_date'] =
          tanggalLahirBaru.trim();

      // =====================================================
      // DEBUG
      // =====================================================

      debugPrint('========================================');
      debugPrint('UPDATE PROFILE BODY');
      debugPrint('name        : ${namaBaru.trim()}');
      debugPrint('email       : ${emailBaru.trim()}');
      debugPrint('phone       : ${phoneBaru.trim()}');
      debugPrint('gender      : ${genderBaru.trim()}');
      debugPrint(
        'birth_place : ${tempatLahirBaru.trim()}',
      );
      debugPrint(
        'birth_date  : ${tanggalLahirBaru.trim()}',
      );
      debugPrint('========================================');

      // =====================================================
      // SEND
      // =====================================================

      final streamedResponse =
          await request.send();

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      debugPrint('========================================');
      debugPrint(
        'UPDATE STATUS: ${response.statusCode}',
      );
      debugPrint(
        'UPDATE RESPONSE: ${response.body}',
      );
      debugPrint('========================================');

      // =====================================================
      // TUTUP LOADING
      // =====================================================

      if (mounted && loadingShown) {
        Navigator.of(context).pop();
        loadingShown = false;
      }

      if (!mounted) return false;

      // =====================================================
      // BERHASIL
      // =====================================================

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        dynamic data;

        try {
          data = jsonDecode(response.body);
        } catch (_) {
          data = null;
        }

        dynamic userData;

        if (data is Map &&
            data['data'] != null) {
          userData = data['data'];
        } else if (data is Map &&
            data['user'] != null) {
          userData = data['user'];
        }

        // ===================================================
        // UPDATE UI
        // ===================================================

        setState(() {
          nama = namaBaru.trim();
          email = emailBaru.trim();
          phone = phoneBaru.trim();
          gender = genderBaru.trim();
          tempatLahir = tempatLahirBaru.trim();
          tanggalLahir = tanggalLahirBaru.trim();
        });

        // ===================================================
        // SIMPAN CACHE
        // ===================================================

        if (userData is Map) {
          await prefs.setString(
            'user',
            jsonEncode(userData),
          );
        } else {
          await prefs.setString(
            'user',
            jsonEncode({
              'name': namaBaru.trim(),
              'email': emailBaru.trim(),
              'phone': phoneBaru.trim(),
              'gender': genderBaru.trim(),
              'birth_place':
                  tempatLahirBaru.trim(),
              'birth_date':
                  tanggalLahirBaru.trim(),
            }),
          );
        }

        showSuccess(
          'Profil berhasil diperbarui.',
        );

        return true;
      }

      // =====================================================
      // 401
      // =====================================================

      if (response.statusCode == 401) {
        showError(
          'Token tidak valid atau sesi sudah berakhir.',
        );

        return false;
      }

      // =====================================================
      // 404
      // =====================================================

      if (response.statusCode == 404) {
        showError(
          'Endpoint update profile tidak ditemukan.',
        );

        return false;
      }

      // =====================================================
      // 405
      // =====================================================

      if (response.statusCode == 405) {
        showError(
          'Method request tidak sesuai dengan API.',
        );

        return false;
      }

      // =====================================================
      // 422
      // =====================================================

      if (response.statusCode == 422) {
        String message =
            'Data profile tidak valid.';

        try {
          final data =
              jsonDecode(response.body);

          debugPrint(
            'VALIDATION DATA: $data',
          );

          if (data is Map &&
              data['message'] != null) {
            message =
                data['message'].toString();
          }

          if (data is Map &&
              data['errors'] != null) {
            debugPrint(
              'VALIDATION ERRORS:',
            );
            debugPrint(
              data['errors'].toString(),
            );
          }
        } catch (e) {
          debugPrint(
            'Gagal decode validation: $e',
          );
        }

        showError(message);

        return false;
      }

      // =====================================================
      // ERROR LAIN
      // =====================================================

      String message =
          'Gagal memperbarui profil (${response.statusCode}).';

      try {
        final data =
            jsonDecode(response.body);

        if (data is Map &&
            data['message'] != null) {
          message =
              data['message'].toString();
        }
      } catch (_) {}

      showError(message);

      return false;
    } catch (e) {
      debugPrint('========================================');
      debugPrint('UPDATE PROFILE ERROR');
      debugPrint(e.toString());
      debugPrint('========================================');

      if (mounted && loadingShown) {
        Navigator.of(context).pop();
      }

      if (!mounted) return false;

      showError(
        'Tidak dapat terhubung ke server.',
      );

      return false;
    }
  }

  // =========================================================
  // EDIT PROFILE
  // =========================================================

  void editProfile() {
    final namaController =
        TextEditingController(
      text: nama == '-' ? '' : nama,
    );

    final emailController =
        TextEditingController(
      text: email == '-' ? '' : email,
    );

    final phoneController =
        TextEditingController(
      text: phone == '-' ? '' : phone,
    );

    final tempatLahirController =
        TextEditingController(
      text: tempatLahir == '-'
          ? ''
          : tempatLahir,
    );

    String selectedGender = '';

    if (gender == 'L' ||
        gender == 'P') {
      selectedGender = gender;
    }

    String selectedDate =
        tanggalLahir == '-'
            ? ''
            : tanggalLahir;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setModalState,
          ) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(
                  context,
                ).viewInsets.bottom,
              ),
              child: Container(
                constraints:
                    BoxConstraints(
                  maxHeight:
                      MediaQuery.of(
                            context,
                          ).size.height *
                          0.92,
                ),
                decoration:
                    const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.only(
                    topLeft:
                        Radius.circular(
                      30,
                    ),
                    topRight:
                        Radius.circular(
                      30,
                    ),
                  ),
                ),
                child:
                    SingleChildScrollView(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    20,
                    15,
                    20,
                    25,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      // =================================================
                      // HANDLE
                      // =================================================

                      Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          decoration:
                              BoxDecoration(
                            color: Colors
                                .grey
                                .shade300,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              10,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      // =================================================
                      // HEADER
                      // =================================================

                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFFF7E7EB,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ),
                            ),
                            child:
                                const Icon(
                              Icons
                                  .edit_outlined,
                              color:
                                  primaryColor,
                              size: 27,
                            ),
                          ),

                          const SizedBox(
                            width: 14,
                          ),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  'Edit Profil',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        23,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    color:
                                        primaryColor,
                                  ),
                                ),
                                SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  'Perbarui informasi profil kamu',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        13,
                                    color:
                                        Colors
                                            .grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 25,
                      ),

                      // =================================================
                      // NAMA
                      // =================================================

                      _editField(
                        controller:
                            namaController,
                        label:
                            'Nama Lengkap',
                        icon: Icons
                            .person_outline,
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      // =================================================
                      // EMAIL
                      // =================================================

                      _editField(
                        controller:
                            emailController,
                        label: 'Email',
                        icon: Icons
                            .email_outlined,
                        keyboardType:
                            TextInputType
                                .emailAddress,
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      // =================================================
                      // NOMOR HP
                      // =================================================

                      _editField(
                        controller:
                            phoneController,
                        label: 'Nomor HP',
                        icon: Icons
                            .phone_outlined,
                        keyboardType:
                            TextInputType
                                .phone,
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      // =================================================
                      // JENIS KELAMIN
                      // =================================================

                      DropdownButtonFormField<
                          String>(
                        value:
                            selectedGender
                                    .isEmpty
                                ? null
                                : selectedGender,
                        decoration:
                            InputDecoration(
                          labelText:
                              'Jenis Kelamin',
                          prefixIcon:
                              const Icon(
                            Icons
                                .people_outline,
                            color:
                                primaryColor,
                          ),
                          filled: true,
                          fillColor:
                              const Color(
                            0xFFF8F8F8,
                          ),
                          contentPadding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                15,
                            vertical: 16,
                          ),
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              15,
                            ),
                            borderSide:
                                BorderSide
                                    .none,
                          ),
                          enabledBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              15,
                            ),
                            borderSide:
                                BorderSide
                                    .none,
                          ),
                          focusedBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              15,
                            ),
                            borderSide:
                                const BorderSide(
                              color:
                                  primaryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'L',
                            child: Text(
                              'Laki-laki',
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'P',
                            child: Text(
                              'Perempuan',
                            ),
                          ),
                        ],
                        onChanged:
                            (value) {
                          setModalState(() {
                            selectedGender =
                                value ?? '';
                          });
                        },
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      // =================================================
                      // TEMPAT LAHIR
                      // =================================================

                      _editField(
                        controller:
                            tempatLahirController,
                        label:
                            'Tempat Lahir',
                        icon: Icons
                            .location_city_outlined,
                      ),

                      const SizedBox(
                        height: 15,
                      ),

                      // =================================================
                      // TANGGAL LAHIR
                      // =================================================

                      GestureDetector(
                        onTap: () async {
                          DateTime?
                              pickedDate;

                          DateTime
                              initialDate =
                              DateTime(
                            2000,
                            1,
                            1,
                          );

                          if (selectedDate
                              .isNotEmpty) {
                            try {
                              initialDate =
                                  DateTime.parse(
                                selectedDate,
                              );
                            } catch (_) {}
                          }

                          pickedDate =
                              await showDatePicker(
                            context: context,
                            initialDate:
                                initialDate,
                            firstDate:
                                DateTime(
                              1900,
                            ),
                            lastDate:
                                DateTime.now(),
                            helpText:
                                'Pilih Tanggal Lahir',
                            cancelText:
                                'Batal',
                            confirmText:
                                'Pilih',
                            builder:
                                (
                              context,
                              child,
                            ) {
                              return Theme(
                                data: Theme.of(
                                  context,
                                ).copyWith(
                                  colorScheme:
                                      const ColorScheme.light(
                                    primary:
                                        primaryColor,
                                  ),
                                ),
                                child:
                                    child!,
                              );
                            },
                          );

                          if (pickedDate !=
                              null) {
                            final year =
                                pickedDate!
                                    .year
                                    .toString()
                                    .padLeft(
                                      4,
                                      '0',
                                    );

                            final month =
                                pickedDate!
                                    .month
                                    .toString()
                                    .padLeft(
                                      2,
                                      '0',
                                    );

                            final day =
                                pickedDate!
                                    .day
                                    .toString()
                                    .padLeft(
                                      2,
                                      '0',
                                    );

                            setModalState(() {
                              selectedDate =
                                  '$year-$month-$day';
                            });
                          }
                        },
                        child: Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 15,
                            vertical: 16,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFFF8F8F8,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              15,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons
                                    .calendar_month_outlined,
                                color:
                                    primaryColor,
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              Expanded(
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    const Text(
                                      'Tanggal Lahir',
                                      style:
                                          TextStyle(
                                        fontSize:
                                            12,
                                        color:
                                            Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(
                                      selectedDate
                                              .isEmpty
                                          ? 'Pilih tanggal lahir'
                                          : _formatDate(
                                              selectedDate,
                                            ),
                                      style:
                                          TextStyle(
                                        fontSize:
                                            15,
                                        fontWeight:
                                            FontWeight
                                                .w600,
                                        color: selectedDate
                                                .isEmpty
                                            ? Colors
                                                .grey
                                            : Colors
                                                .black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons
                                    .arrow_drop_down,
                                color:
                                    Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 25,
                      ),

                      // =================================================
                      // SIMPAN
                      // =================================================

                      SizedBox(
                        width:
                            double.infinity,
                        height: 55,
                        child:
                            ElevatedButton
                                .icon(
                          onPressed:
                              () async {
                            final namaValue =
                                namaController
                                    .text
                                    .trim();

                            final emailValue =
                                emailController
                                    .text
                                    .trim();

                            final phoneValue =
                                phoneController
                                    .text
                                    .trim();

                            final tempatLahirValue =
                                tempatLahirController
                                    .text
                                    .trim();

                            // ==========================================
                            // VALIDASI
                            // ==========================================

                            if (namaValue
                                .isEmpty) {
                              showError(
                                'Nama tidak boleh kosong.',
                              );
                              return;
                            }

                            if (emailValue
                                .isEmpty) {
                              showError(
                                'Email tidak boleh kosong.',
                              );
                              return;
                            }

                            if (phoneValue
                                .isEmpty) {
                              showError(
                                'Nomor HP tidak boleh kosong.',
                              );
                              return;
                            }

                            if (selectedGender
                                .isEmpty) {
                              showError(
                                'Jenis kelamin harus dipilih.',
                              );
                              return;
                            }

                            if (tempatLahirValue
                                .isEmpty) {
                              showError(
                                'Tempat lahir tidak boleh kosong.',
                              );
                              return;
                            }

                            if (selectedDate
                                .isEmpty) {
                              showError(
                                'Tanggal lahir harus dipilih.',
                              );
                              return;
                            }

                            // ==========================================
                            // UPDATE
                            // ==========================================

                            final success =
                                await updateProfile(
                              namaBaru:
                                  namaValue,
                              emailBaru:
                                  emailValue,
                              phoneBaru:
                                  phoneValue,
                              genderBaru:
                                  selectedGender,
                              tempatLahirBaru:
                                  tempatLahirValue,
                              tanggalLahirBaru:
                                  selectedDate,
                            );

                            // ==========================================
                            // TUTUP BOTTOM SHEET
                            // ==========================================

                            if (success &&
                                sheetContext
                                    .mounted) {
                              Navigator.pop(
                                sheetContext,
                              );
                            }
                          },
                          icon:
                              const Icon(
                            Icons
                                .save_outlined,
                            color:
                                Colors.white,
                          ),
                          label:
                              const Text(
                            'Simpan Perubahan',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize:
                                  16,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                primaryColor,
                            elevation: 3,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                15,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      // =================================================
                      // BATAL
                      // =================================================

                      SizedBox(
                        width:
                            double.infinity,
                        height: 50,
                        child:
                            TextButton(
                          onPressed: () {
                            Navigator.pop(
                              sheetContext,
                            );
                          },
                          child:
                              const Text(
                            'Batal',
                            style:
                                TextStyle(
                              color:
                                  Colors.grey,
                              fontSize:
                                  15,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================
  // FORMAT TANGGAL
  // =========================================================

  String _formatDate(String date) {
    try {
      final parsed =
          DateTime.parse(date);

      final day = parsed.day
          .toString()
          .padLeft(2, '0');

      final month = parsed.month
          .toString()
          .padLeft(2, '0');

      final year =
          parsed.year.toString();

      return '$day-$month-$year';
    } catch (_) {
      return date;
    }
  }

  // =========================================================
  // EDIT FIELD
  // =========================================================

  Widget _editField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: primaryColor,
        ),
        filled: true,
        fillColor:
            const Color(0xFFF8F8F8),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(15),
          borderSide:
              const BorderSide(
            color: primaryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> logout() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove('token');
    await prefs.remove('user');

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  // =========================================================
  // LOGOUT DIALOG
  // =========================================================

  void showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          content: const Text(
            'Apakah kamu yakin ingin keluar?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child: const Text(
                'Batal',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                logout();
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryColor,
                foregroundColor:
                    Colors.white,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
              ),
              child:
                  const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F5F5),

      // =======================================================
      // APP BAR
      // =======================================================

      appBar: AppBar(
        backgroundColor:
            primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme:
            const IconThemeData(
          color: Colors.white,
        ),
        title: const Text(
          'Profil',
          style: TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: editProfile,
            icon: const Icon(
              Icons.edit_outlined,
              color: Colors.white,
            ),
          ),
        ],
      ),

      // =======================================================
      // BODY
      // =======================================================

      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: loadProfile,
              child:
                  SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // =================================================
                    // HEADER
                    // =================================================

                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets
                              .only(
                        bottom: 30,
                      ),
                      decoration:
                          const BoxDecoration(
                        color:
                            primaryColor,
                        borderRadius:
                            BorderRadius.only(
                          bottomLeft:
                              Radius.circular(
                            30,
                          ),
                          bottomRight:
                              Radius.circular(
                            30,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(
                            height: 20,
                          ),

                          const CircleAvatar(
                            radius: 50,
                            backgroundColor:
                                Colors.white,
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color:
                                  primaryColor,
                            ),
                          ),

                          const SizedBox(
                            height: 15,
                          ),

                          Text(
                            nama,
                            textAlign:
                                TextAlign
                                    .center,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 24,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          const Text(
                            'Survey Officer',
                            style:
                                TextStyle(
                              color:
                                  Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 25,
                    ),

                    // =================================================
                    // TITLE
                    // =================================================

                    const Padding(
                      padding:
                          EdgeInsets
                              .symmetric(
                        horizontal: 20,
                      ),
                      child: Align(
                        alignment:
                            Alignment
                                .centerLeft,
                        child: Text(
                          'Informasi Pribadi',
                          style:
                              TextStyle(
                            fontSize: 21,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    // =================================================
                    // PROFILE CARD
                    // =================================================

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 20,
                      ),
                      child: Card(
                        elevation: 5,
                        shadowColor:
                            Colors.black12,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .all(
                            15,
                          ),
                          child: Column(
                            children: [
                              _profileItem(
                                icon: Icons
                                    .person,
                                title: 'Nama',
                                value: nama,
                              ),

                              const Divider(),

                              _profileItem(
                                icon: Icons
                                    .email,
                                title: 'Email',
                                value: email,
                              ),

                              const Divider(),

                              _profileItem(
                                icon: Icons
                                    .phone,
                                title:
                                    'Nomor HP',
                                value: phone,
                              ),

                              const Divider(),

                              _profileItem(
                                icon: Icons
                                    .people,
                                title:
                                    'Jenis Kelamin',
                                value: gender ==
                                        'L'
                                    ? 'Laki-laki'
                                    : gender ==
                                            'P'
                                        ? 'Perempuan'
                                        : gender,
                              ),

                              const Divider(),

                              _profileItem(
                                icon: Icons
                                    .location_city,
                                title:
                                    'Tempat Lahir',
                                value:
                                    tempatLahir,
                              ),

                              const Divider(),

                              _profileItem(
                                icon: Icons
                                    .calendar_month,
                                title:
                                    'Tanggal Lahir',
                                value:
                                    tanggalLahir ==
                                            '-'
                                        ? '-'
                                        : _formatDate(
                                            tanggalLahir,
                                          ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 25,
                    ),

                    // =================================================
                    // EDIT BUTTON
                    // =================================================

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 20,
                      ),
                      child: SizedBox(
                        width:
                            double.infinity,
                        height: 55,
                        child:
                            ElevatedButton
                                .icon(
                          onPressed:
                              editProfile,
                          icon:
                              const Icon(
                            Icons.edit,
                            color:
                                Colors.white,
                          ),
                          label:
                              const Text(
                            'Edit Profil',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 16,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                primaryColor,
                            elevation: 5,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // =================================================
                    // LOGOUT
                    // =================================================

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 20,
                      ),
                      child: SizedBox(
                        width:
                            double.infinity,
                        height: 55,
                        child:
                            OutlinedButton
                                .icon(
                          onPressed:
                              showLogoutDialog,
                          icon:
                              const Icon(
                            Icons.logout,
                            color:
                                primaryColor,
                          ),
                          label:
                              const Text(
                            'Logout',
                            style:
                                TextStyle(
                              color:
                                  primaryColor,
                              fontSize: 16,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          style:
                              OutlinedButton
                                  .styleFrom(
                            side:
                                const BorderSide(
                              color:
                                  primaryColor,
                              width: 1.5,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 30,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // =========================================================
  // PROFILE ITEM
  // =========================================================

  Widget _profileItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 3,
      ),
      leading: CircleAvatar(
        backgroundColor:
            const Color(0xFFF7E7EB),
        child: Icon(
          icon,
          color: primaryColor,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 13,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
          fontWeight:
              FontWeight.w600,
        ),
      ),
    );
  }
}