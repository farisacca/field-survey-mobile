import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:field_survey/routes/app_routes.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // =========================================================
  // WARNA
  // =========================================================

  static const Color primaryColor = Color(0xFF7B1E3A);

  // =========================================================
  // API
  // =========================================================

  static const String baseUrl = 'https://sijala.biz.id/api/v1';

  static const String profileUrl = '$baseUrl/profile';

  static const String updateProfileUrl = '$baseUrl/profile/update';

  static const String logoutUrl = '$baseUrl/logout';

  // =========================================================
  // PROFILE
  // =========================================================

  bool isLoading = true;
  bool isSaving = false;
  bool isUploadingPhoto = false;

  String name = '-';
  String username = '-';
  String email = '-';
  String phone = '-';
  String gender = '-';
  String birthPlace = '-';
  String birthDate = '-';

  String? photoName;

  // =========================================================
  // FOTO
  // =========================================================

  Uint8List? profileImage;
  Uint8List? selectedPhoto;

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();
    getProfile();
  }

  // =========================================================
  // TOKEN
  // =========================================================

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token');

    print('======================================');
    print('TOKEN');
    print(token);
    print('======================================');

    return token;
  }

  // =========================================================
  // GET PROFILE
  // =========================================================

  Future<void> getProfile() async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }

      final token = await getToken();

      // =====================================================
      // TOKEN TIDAK ADA
      // =====================================================

      if (token == null || token.isEmpty) {
        print('TOKEN TIDAK DITEMUKAN');

        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        showMessage(
          'Token tidak ditemukan. Silakan login kembali.',
          Colors.red,
        );

        return;
      }

      print('======================================');
      print('GET PROFILE');
      print('URL: $profileUrl');
      print('======================================');

      final response = await http
          .get(
            Uri.parse(profileUrl),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      print('======================================');
      print('PROFILE STATUS: ${response.statusCode}');
      print('PROFILE RESPONSE:');
      print(response.body);
      print('======================================');

      dynamic result;

      try {
        result = jsonDecode(response.body);
      } catch (e) {
        print('JSON ERROR: $e');
        result = {};
      }

      // =====================================================
      // TOKEN EXPIRED / INVALID
      // =====================================================

      if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.remove('token');
        await prefs.remove('user');

        if (!mounted) return;

        showMessage('Sesi login telah berakhir.', Colors.red);

        context.go(AppRoutes.login);

        return;
      }

      // =====================================================
      // BERHASIL
      // =====================================================

      if (response.statusCode == 200) {
        dynamic profileData;

        if (result is Map) {
          if (result['data'] is Map) {
            profileData = result['data'];
          } else {
            profileData = result;
          }
        }

        if (profileData is Map) {
          final data = Map<String, dynamic>.from(profileData);

          // =================================================
          // DATA PROFILE
          // =================================================

          final newName = data['name']?.toString() ?? '-';

          final newUsername = data['username']?.toString() ?? '-';

          final newEmail = data['email']?.toString() ?? '-';

          final newPhone = data['phone']?.toString() ?? '-';

          final newBirthPlace =
              data['birth_place']?.toString() ??
              data['birthPlace']?.toString() ??
              '-';

          final newBirthDate =
              data['birth_date']?.toString() ??
              data['birthDate']?.toString() ??
              '-';

          String newGender = '-';

          final genderValue = data['gender']?.toString();

          if (genderValue == 'L') {
            newGender = 'Laki Laki';
          } else if (genderValue == 'P') {
            newGender = 'Perempuan';
          } else if (genderValue != null && genderValue.isNotEmpty) {
            newGender = genderValue;
          }

          String? newPhoto;

          if (data['photo'] != null) {
            final photoValue = data['photo'].toString();

            if (photoValue.isNotEmpty && photoValue != 'null') {
              newPhoto = photoValue;
            }
          }

          // =================================================
          // SET DATA
          // =================================================

          if (!mounted) return;

          setState(() {
            name = newName;
            username = newUsername;
            email = newEmail;
            phone = newPhone;
            gender = newGender;
            birthPlace = newBirthPlace;
            birthDate = newBirthDate;
            photoName = newPhoto;
          });

          // =================================================
          // SIMPAN DATA USER
          // =================================================

          final prefs = await SharedPreferences.getInstance();

          await prefs.setString('user', jsonEncode(data));

          // =================================================
          // LOAD FOTO SERVER
          // =================================================

          if (newPhoto != null && newPhoto.isNotEmpty) {
            await loadProfileImage(newPhoto);
          } else {
            await loadSavedPhoto(newEmail);
          }
        }
      } else {
        String message = 'Gagal mengambil data profile';

        if (result is Map && result['message'] != null) {
          message = result['message'].toString();
        }

        if (mounted) {
          showMessage(message, Colors.red);
        }

        await loadSavedPhoto(email);
      }
    } catch (e) {
      print('======================================');
      print('ERROR GET PROFILE');
      print(e);
      print('======================================');

      await loadSavedPhoto(email);

      if (mounted) {
        showMessage('Tidak dapat terhubung ke server.', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // LOAD FOTO DARI SERVER
  // =========================================================

  Future<void> loadProfileImage(String fileName) async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        return;
      }

      final url = 'https://sijala.biz.id/api/image/$fileName';

      print('======================================');
      print('LOAD PROFILE IMAGE');
      print(url);
      print('======================================');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $token', 'Accept': '*/*'},
          )
          .timeout(const Duration(seconds: 30));

      print('IMAGE STATUS: ${response.statusCode}');

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();

        final photoKey = 'profile_photo_${email.toLowerCase()}';

        await prefs.setString(photoKey, base64Encode(response.bodyBytes));

        if (!mounted) return;

        setState(() {
          profileImage = response.bodyBytes;
        });
      } else {
        await loadSavedPhoto(email);
      }
    } catch (e) {
      print('ERROR LOAD IMAGE: $e');

      await loadSavedPhoto(email);
    }
  }

  // =========================================================
  // LOAD FOTO LOCAL
  // =========================================================

  Future<void> loadSavedPhoto(String userEmail) async {
    try {
      if (userEmail.isEmpty || userEmail == '-') {
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      final photoKey = 'profile_photo_${userEmail.toLowerCase()}';

      final savedPhoto = prefs.getString(photoKey);

      if (savedPhoto == null || savedPhoto.isEmpty) {
        return;
      }

      final bytes = base64Decode(savedPhoto);

      if (!mounted) return;

      setState(() {
        profileImage = bytes;
      });
    } catch (e) {
      print('ERROR LOAD SAVED PHOTO: $e');
    }
  }

  // =========================================================
  // PILIH FOTO
  // =========================================================

  Future<void> pickPhoto() async {
    if (isUploadingPhoto) {
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null) {
        return;
      }

      final file = result.files.single;

      if (file.bytes == null) {
        showMessage('File gambar tidak bisa dibaca.', Colors.red);

        return;
      }

      if (!mounted) return;

      setState(() {
        selectedPhoto = file.bytes;
        profileImage = file.bytes;
      });

      await uploadPhoto(file.bytes!, file.name);
    } catch (e) {
      print('ERROR PICK PHOTO: $e');

      if (mounted) {
        showMessage('Gagal memilih foto.', Colors.red);
      }
    }
  }

  // =========================================================
  // UPLOAD FOTO
  // =========================================================

  Future<void> uploadPhoto(Uint8List bytes, String fileName) async {
    try {
      if (mounted) {
        setState(() {
          isUploadingPhoto = true;
        });
      }

      final token = await getToken();

      if (token == null || token.isEmpty) {
        showMessage('Token tidak ditemukan.', Colors.red);

        return;
      }

      print('======================================');
      print('UPLOAD FOTO');
      print('FILE: $fileName');
      print('======================================');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(updateProfileUrl),
      );

      request.headers['Accept'] = 'application/json';

      request.headers['Authorization'] = 'Bearer $token';

      // =====================================================
      // PROFILE
      // =====================================================

      if (name != '-' && name.isNotEmpty) {
        request.fields['name'] = name;
      }

      if (phone != '-' && phone.isNotEmpty) {
        request.fields['phone'] = phone;
      }

      if (gender == 'Laki Laki') {
        request.fields['gender'] = 'L';
      } else if (gender == 'Perempuan') {
        request.fields['gender'] = 'P';
      }

      // =====================================================
      // FOTO
      // =====================================================

      request.files.add(
        http.MultipartFile.fromBytes('photo', bytes, filename: fileName),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('======================================');
      print('UPLOAD STATUS: ${response.statusCode}');
      print('UPLOAD RESPONSE:');
      print(response.body);
      print('======================================');

      dynamic result;

      try {
        result = jsonDecode(response.body);
      } catch (_) {
        result = {};
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        String? newPhotoName;

        if (result is Map) {
          if (result['photo'] != null) {
            newPhotoName = result['photo'].toString();
          }

          if ((newPhotoName == null || newPhotoName.isEmpty) &&
              result['data'] is Map) {
            final dataMap = Map<String, dynamic>.from(result['data']);

            if (dataMap['photo'] != null) {
              newPhotoName = dataMap['photo'].toString();
            }
          }
        }

        // ===================================================
        // SIMPAN FOTO BERDASARKAN EMAIL
        // ===================================================

        final prefs = await SharedPreferences.getInstance();

        final photoKey = 'profile_photo_${email.toLowerCase()}';

        await prefs.setString(photoKey, base64Encode(bytes));

        // ===================================================
        // SIMPAN NAMA FOTO
        // ===================================================

        if (newPhotoName != null && newPhotoName.isNotEmpty) {
          photoName = newPhotoName;

          await prefs.setString(
            'profile_photo_name_${email.toLowerCase()}',
            newPhotoName,
          );
        }

        if (mounted) {
          setState(() {
            profileImage = bytes;
          });

          showMessage('Foto profile berhasil diperbarui.', Colors.green);
        }
      } else {
        String message = 'Gagal mengupload foto.';

        if (result is Map && result['message'] != null) {
          message = result['message'].toString();
        }

        if (mounted) {
          showMessage(message, Colors.red);
        }
      }
    } catch (e) {
      print('======================================');
      print('ERROR UPLOAD PHOTO');
      print(e);
      print('======================================');

      if (mounted) {
        showMessage('Gagal mengupload foto.', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          isUploadingPhoto = false;
          selectedPhoto = null;
        });
      }
    }
  }

  // =========================================================
  // EDIT PROFILE
  // =========================================================

  Future<void> editProfile() async {
    final nameController = TextEditingController(text: name == '-' ? '' : name);

    final phoneController = TextEditingController(
      text: phone == '-' ? '' : phone,
    );

    String selectedGender = gender;

    if (selectedGender != 'Laki Laki' && selectedGender != 'Perempuan') {
      selectedGender = 'Laki Laki';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HANDLE
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'Perbarui informasi profil kamu',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),

                    const SizedBox(height: 22),

                    // =================================================
                    // NAMA
                    // =================================================
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nama',
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          color: primaryColor,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F6F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // =================================================
                    // NOMOR HP
                    // =================================================
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Nomor HP',
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: primaryColor,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F6F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // =================================================
                    // GENDER
                    // =================================================
                    DropdownButtonFormField<String>(
                      initialValue: selectedGender,
                      decoration: InputDecoration(
                        labelText: 'Jenis Kelamin',
                        prefixIcon: const Icon(
                          Icons.wc_outlined,
                          color: primaryColor,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F6F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(
                            color: primaryColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Laki Laki',
                          child: Text('Laki Laki'),
                        ),
                        DropdownMenuItem(
                          value: 'Perempuan',
                          child: Text('Perempuan'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setModalState(() {
                          selectedGender = value;
                        });
                      },
                    ),

                    const SizedBox(height: 25),

                    // =================================================
                    // SIMPAN
                    // =================================================
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final newName = nameController.text.trim();

                                final newPhone = phoneController.text.trim();

                                if (newName.isEmpty) {
                                  showMessage('Nama wajib diisi.', Colors.red);
                                  return;
                                }

                                if (newPhone.isEmpty) {
                                  showMessage(
                                    'Nomor HP wajib diisi.',
                                    Colors.red,
                                  );
                                  return;
                                }

                                Navigator.pop(modalContext);

                                await updateProfile(
                                  newName,
                                  newPhone,
                                  selectedGender,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Simpan Perubahan',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
  }

  // =========================================================
  // UPDATE PROFILE
  // =========================================================

  Future<void> updateProfile(
    String newName,
    String newPhone,
    String newGender,
  ) async {
    try {
      if (mounted) {
        setState(() {
          isSaving = true;
        });
      }

      final token = await getToken();

      if (token == null || token.isEmpty) {
        showMessage('Token tidak ditemukan.', Colors.red);

        return;
      }

      print('======================================');
      print('UPDATE PROFILE');
      print('======================================');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(updateProfileUrl),
      );

      request.headers['Accept'] = 'application/json';

      request.headers['Authorization'] = 'Bearer $token';

      request.fields['name'] = newName;

      request.fields['phone'] = newPhone;

      if (newGender == 'Laki Laki') {
        request.fields['gender'] = 'L';
      } else if (newGender == 'Perempuan') {
        request.fields['gender'] = 'P';
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(streamedResponse);

      print('======================================');
      print('UPDATE STATUS: ${response.statusCode}');
      print('UPDATE RESPONSE:');
      print(response.body);
      print('======================================');

      dynamic result;

      try {
        result = jsonDecode(response.body);
      } catch (_) {
        result = {};
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;

        setState(() {
          name = newName;
          phone = newPhone;
          gender = newGender;
        });

        // ===================================================
        // UPDATE DATA LOCAL
        // ===================================================

        final prefs = await SharedPreferences.getInstance();

        final oldUser = prefs.getString('user');

        Map<String, dynamic> userMap = {};

        if (oldUser != null && oldUser.isNotEmpty) {
          try {
            final decoded = jsonDecode(oldUser);

            if (decoded is Map) {
              userMap = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }

        userMap['name'] = newName;
        userMap['phone'] = newPhone;

        if (newGender == 'Laki Laki') {
          userMap['gender'] = 'L';
        } else if (newGender == 'Perempuan') {
          userMap['gender'] = 'P';
        }

        if (photoName != null) {
          userMap['photo'] = photoName;
        }

        await prefs.setString('user', jsonEncode(userMap));

        showMessage('Profile berhasil diperbarui.', Colors.green);
      } else {
        String message = 'Gagal memperbarui profile.';

        if (result is Map && result['message'] != null) {
          message = result['message'].toString();
        }

        if (mounted) {
          showMessage(message, Colors.red);
        }
      }
    } catch (e) {
      print('======================================');
      print('ERROR UPDATE PROFILE');
      print(e);
      print('======================================');

      if (mounted) {
        showMessage('Tidak dapat terhubung ke server.', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> logout() async {
    // =======================================================
    // KONFIRMASI
    // =======================================================

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Konfirmasi Logout',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('Apakah Anda yakin ingin keluar dari akun?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );

    // BATAL
    if (result != true) {
      return;
    }

    // =======================================================
    // AMBIL TOKEN
    // =======================================================

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      print('======================================');
      print('LOGOUT');
      print('TOKEN LAMA: $token');
      print('======================================');

      // =====================================================
      // REQUEST LOGOUT API
      // =====================================================

      if (token != null && token.isNotEmpty) {
        try {
          print('======================================');
          print('REQUEST LOGOUT API');
          print('URL: $logoutUrl');
          print('======================================');

          final response = await http
              .post(
                Uri.parse(logoutUrl),
                headers: {
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
              )
              .timeout(const Duration(seconds: 30));

          print('LOGOUT STATUS: ${response.statusCode}');

          print('LOGOUT RESPONSE: ${response.body}');
        } catch (e) {
          print('ERROR LOGOUT API: $e');
        }
      }

      // =====================================================
      // HAPUS TOKEN
      // =====================================================

      await prefs.remove('token');

      // =====================================================
      // HAPUS USER
      // =====================================================

      await prefs.remove('user');

      print('======================================');
      print('LOGOUT SELESAI');
      print('TOKEN DIHAPUS');
      print('USER DIHAPUS');
      print('======================================');

      // =====================================================
      // PINDAH KE LOGIN
      // =====================================================

      if (!mounted) {
        return;
      }

      context.go(AppRoutes.login);
    } catch (e) {
      print('======================================');
      print('ERROR LOGOUT');
      print(e);
      print('======================================');

      // =====================================================
      // KALAU TERJADI ERROR
      // =====================================================

      try {
        final prefs = await SharedPreferences.getInstance();

        await prefs.remove('token');
        await prefs.remove('user');
      } catch (_) {}

      if (!mounted) {
        return;
      }

      context.go(AppRoutes.login);
    }
  }

  // =========================================================
  // SNACKBAR
  // =========================================================

  void showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(15),
        ),
      );
  }

  // =========================================================
  // FOTO PROFILE
  // =========================================================

  Widget profileImageWidget() {
    if (selectedPhoto != null) {
      return CircleAvatar(
        radius: 43,
        backgroundImage: MemoryImage(selectedPhoto!),
      );
    }

    if (profileImage != null) {
      return CircleAvatar(
        radius: 43,
        backgroundImage: MemoryImage(profileImage!),
      );
    }

    return const CircleAvatar(
      radius: 43,
      backgroundColor: Colors.white,
      child: Icon(Icons.person_rounded, size: 45, color: primaryColor),
    );
  }

  // =========================================================
  // PROFILE INFO ITEM
  // =========================================================

  Widget profileInfoItem({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // ICON
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),

          const SizedBox(width: 13),

          // TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // PROFILE CARD
  // =========================================================

  Widget profileCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // =================================================
          // HEADER PROFILE
          // =================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            decoration: const BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // FOTO
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: profileImageWidget(),
                    ),

                    // CAMERA
                    GestureDetector(
                      onTap: isUploadingPhoto ? null : pickPhoto,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryColor, width: 2),
                        ),
                        child: isUploadingPhoto
                            ? const Padding(
                                padding: EdgeInsets.all(7),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryColor,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                size: 17,
                                color: primaryColor,
                              ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // NAMA
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 5),

                // USERNAME
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '@$username',
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // =================================================
          // INFORMASI PROFILE
          // =================================================
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // JUDUL
                const Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      color: primaryColor,
                      size: 21,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Informasi Pribadi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // USERNAME
                profileInfoItem(
                  icon: Icons.alternate_email_rounded,
                  label: 'Username',
                  value: username,
                ),

                // EMAIL
                profileInfoItem(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: email,
                ),

                // NOMOR HP
                profileInfoItem(
                  icon: Icons.phone_outlined,
                  label: 'Nomor HP',
                  value: phone,
                ),

                // GENDER
                profileInfoItem(
                  icon: Icons.wc_outlined,
                  label: 'Jenis Kelamin',
                  value: gender,
                ),

                // TEMPAT LAHIR
                profileInfoItem(
                  icon: Icons.location_city_outlined,
                  label: 'Tempat Lahir',
                  value: birthPlace,
                ),

                // TANGGAL LAHIR
                profileInfoItem(
                  icon: Icons.calendar_month_outlined,
                  label: 'Tanggal Lahir',
                  value: birthDate,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ACTION CARD
  // =========================================================

  Widget actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLogout
              ? Colors.red.withOpacity(0.12)
              : primaryColor.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // =================================================
                // ICON
                // =================================================
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isLogout
                        ? Colors.red.withOpacity(0.09)
                        : primaryColor.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: isLogout ? Colors.red : primaryColor,
                    size: 23,
                  ),
                ),

                const SizedBox(width: 14),

                // =================================================
                // TEXT
                // =================================================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isLogout ? Colors.red : Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // =================================================
                // ARROW
                // =================================================
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isLogout
                        ? Colors.red.withOpacity(0.06)
                        : primaryColor.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: isLogout ? Colors.red : primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // =====================================================
      // APP BAR
      // =====================================================
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // =====================================================
      // BODY
      // =====================================================
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: getProfile,

        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryColor),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(18),

                child: Column(
                  children: [
                    // =================================================
                    // PROFILE
                    // =================================================
                    profileCard(),

                    const SizedBox(height: 20),

                    // =================================================
                    // AKSI
                    // =================================================
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pengaturan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // =================================================
                    // EDIT PROFILE
                    // =================================================
                    actionCard(
                      icon: Icons.edit_rounded,
                      title: 'Edit Profile',
                      subtitle: 'Perbarui data diri kamu',
                      onTap: editProfile,
                    ),

                    // =================================================
                    // LOGOUT
                    // =================================================
                    actionCard(
                      icon: Icons.logout_rounded,
                      title: 'Keluar',
                      subtitle: 'Logout dari akun',
                      isLogout: true,
                      onTap: logout,
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
      ),
    );
  }
}
