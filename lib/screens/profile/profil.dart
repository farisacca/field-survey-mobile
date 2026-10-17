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
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color lightBlue = Color(0xFFE3F0FF);


  static const String baseUrl = 'https://sijala.biz.id/api/v1';
  static const String profileUrl = '$baseUrl/profile';
  static const String updateProfileUrl = '$baseUrl/profile/update';
  static const String logoutUrl = '$baseUrl/logout';


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


  Uint8List? profileImage;
  Uint8List? selectedPhoto;

  @override
  void initState() {
    super.initState();
    getProfile();
  }


  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }


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

  // AMBIL PROFIL
  Future<void> getProfile() async {
    try {
      if (mounted) {
        setState(() => isLoading = true);
      }

      final token = await getToken();

      if (token == null || token.isEmpty) {
        if (!mounted) return;

        setState(() => isLoading = false);
        showMessage(
          'Token tidak ditemukan. Silakan login kembali.',
          Colors.red,
        );
        return;
      }

      final response = await http.get(
        Uri.parse(profileUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      dynamic result;

      try {
        result = jsonDecode(response.body);
      } catch (_) {
        result = {};
      }

      // TOKEN KEDALUWARSA
      if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('user');

        if (!mounted) return;

        showMessage('Sesi login telah berakhir.', Colors.red);
        context.go(AppRoutes.login);
        return;
      }

      if (response.statusCode == 200) {
        dynamic profileData;

        if (result is Map) {
          profileData = result['data'] is Map
              ? result['data']
              : result;
        }

        if (profileData is Map) {
          final data = Map<String, dynamic>.from(profileData);

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
            newGender = 'Laki-laki';
          } else if (genderValue == 'P') {
            newGender = 'Perempuan';
          } else if (genderValue != null &&
              genderValue.isNotEmpty) {
            newGender = genderValue;
          }

          String? newPhoto;

          if (data['photo'] != null) {
            final value = data['photo'].toString();

            if (value.isNotEmpty && value != 'null') {
              newPhoto = value;
            }
          }

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

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(data));

          if (newPhoto != null) {
            await loadProfileImage(newPhoto);
          } else {
            await loadSavedPhoto(newEmail);
          }
        }
      } else {
        final message = result is Map && result['message'] != null
            ? result['message'].toString()
            : 'Gagal mengambil data profil';

        if (mounted) {
          showMessage(message, Colors.red);
        }

        await loadSavedPhoto(email);
      }
    } catch (e) {
      debugPrint('ERROR GET PROFILE: $e');

      await loadSavedPhoto(email);

      if (mounted) {
        showMessage(
          'Tidak dapat terhubung ke server.',
          Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // AMBIL FOTO DARI SERVER
  Future<void> loadProfileImage(String fileName) async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) return;

      final response = await http.get(
        Uri.parse('https://sijala.biz.id/api/image/$fileName'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': '*/*',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 &&
          response.bodyBytes.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'profile_photo_${email.toLowerCase()}';

        await prefs.setString(
          key,
          base64Encode(response.bodyBytes),
        );

        if (!mounted) return;

        setState(() {
          profileImage = response.bodyBytes;
        });
      } else {
        await loadSavedPhoto(email);
      }
    } catch (e) {
      debugPrint('ERROR LOAD IMAGE: $e');
      await loadSavedPhoto(email);
    }
  }

  // AMBIL FOTO TERSIMPAN
  Future<void> loadSavedPhoto(String userEmail) async {
    try {
      if (userEmail.isEmpty || userEmail == '-') return;

      final prefs = await SharedPreferences.getInstance();
      final key = 'profile_photo_${userEmail.toLowerCase()}';
      final savedPhoto = prefs.getString(key);

      if (savedPhoto == null || savedPhoto.isEmpty) return;

      final bytes = base64Decode(savedPhoto);

      if (!mounted) return;

      setState(() {
        profileImage = bytes;
      });
    } catch (e) {
      debugPrint('ERROR LOAD SAVED PHOTO: $e');
    }
  }

  // PILIH FOTO
  Future<void> pickPhoto() async {
    if (isUploadingPhoto) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null) return;

      final file = result.files.single;

      if (file.bytes == null) {
        showMessage(
          'File gambar tidak bisa dibaca.',
          Colors.red,
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        selectedPhoto = file.bytes;
        profileImage = file.bytes;
      });

      await uploadPhoto(file.bytes!, file.name);
    } catch (e) {
      debugPrint('ERROR PICK PHOTO: $e');
      showMessage('Gagal memilih foto.', Colors.red);
    }
  }

  // UPLOAD FOTO
  Future<void> uploadPhoto(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      if (mounted) setState(() => isUploadingPhoto = true);

      final token = await getToken();

      if (token == null || token.isEmpty) {
        showMessage('Token tidak ditemukan.', Colors.red);
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(updateProfileUrl),
      );

      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      if (name != '-' && name.isNotEmpty) {
        request.fields['name'] = name;
      }
      if (username != '-' && username.isNotEmpty) {
        request.fields['username'] = username;
      }
      if (email != '-' && email.isNotEmpty) {
        request.fields['email'] = email;
      }
      if (phone != '-' && phone.isNotEmpty) {
        request.fields['phone'] = phone;
      }
      if (birthPlace != '-' && birthPlace.isNotEmpty) {
        request.fields['birth_place'] = birthPlace;
      }
      if (birthDate != '-' && birthDate.isNotEmpty) {
        request.fields['birth_date'] = birthDate;
      }

      if (gender == 'Laki-laki' || gender == 'Laki Laki') {
        request.fields['gender'] = 'L';
      } else if (gender == 'Perempuan') {
        request.fields['gender'] = 'P';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(
        streamedResponse,
      );

      dynamic result;

      try {
        result = jsonDecode(response.body);
      } catch (_) {
        result = {};
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        String? newPhotoName;

        if (result is Map) {
          if (result['photo'] != null) {
            newPhotoName = result['photo'].toString();
          } else if (result['data'] is Map &&
              result['data']['photo'] != null) {
            newPhotoName = result['data']['photo'].toString();
          }
        }

        final prefs = await SharedPreferences.getInstance();
        final key = 'profile_photo_${email.toLowerCase()}';

        await prefs.setString(key, base64Encode(bytes));

        if (newPhotoName != null && newPhotoName.isNotEmpty) {
          photoName = newPhotoName;

          await prefs.setString(
            'profile_photo_name_${email.toLowerCase()}',
            newPhotoName,
          );
        }

        if (!mounted) return;

        setState(() {
          profileImage = bytes;
        });

        showMessage(
          'Foto profil berhasil diperbarui.',
          Colors.green,
        );
      } else {
        final message = result is Map && result['message'] != null
            ? result['message'].toString()
            : 'Gagal mengupload foto.';

        showMessage(message, Colors.red);
      }
    } catch (e) {
      debugPrint('ERROR UPLOAD PHOTO: $e');
      showMessage('Gagal mengupload foto.', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isUploadingPhoto = false;
          selectedPhoto = null;
        });
      }
    }
  }

  // EDIT PROFIL
  Future<void> editProfile() async {
    final nameController = TextEditingController(
      text: name == '-' ? '' : name,
    );

    final usernameController = TextEditingController(
      text: username == '-' ? '' : username,
    );

    final emailController = TextEditingController(
      text: email == '-' ? '' : email,
    );

    final phoneController = TextEditingController(
      text: phone == '-' ? '' : phone,
    );

    final birthPlaceController = TextEditingController(
      text: birthPlace == '-' ? '' : birthPlace,
    );

    final birthDateController = TextEditingController(
      text: birthDate == '-' ? '' : birthDate,
    );

    String selectedGender =
        gender == 'Perempuan' ? 'Perempuan' : 'Laki-laki';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      'Edit Profil',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'Perbarui informasi profil kamu',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 22),

                    TextField(
                      controller: nameController,
                      decoration: inputDecoration(
                        'Nama',
                        Icons.person_outline_rounded,
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: usernameController,
                      decoration: inputDecoration(
                        'Username',
                        Icons.alternate_email_rounded,
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: inputDecoration(
                        'Email',
                        Icons.email_outlined,
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: inputDecoration(
                        'Nomor HP',
                        Icons.phone_outlined,
                      ),
                    ),

                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: selectedGender,
                      decoration: inputDecoration(
                        'Jenis Kelamin',
                        Icons.wc_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Laki-laki',
                          child: Text('Laki-laki'),
                        ),
                        DropdownMenuItem(
                          value: 'Perempuan',
                          child: Text('Perempuan'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            selectedGender = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: birthPlaceController,
                      decoration: inputDecoration(
                        'Tempat Lahir',
                        Icons.location_city_outlined,
                      ),
                    ),

                    const SizedBox(height: 15),

                    TextField(
                      controller: birthDateController,
                      decoration: inputDecoration(
                        'Tanggal Lahir (YYYY-MM-DD)',
                        Icons.calendar_month_outlined,
                      ),
                    ),

                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final newName = nameController.text.trim();
                                final newUsername = usernameController.text.trim();
                                final newEmail = emailController.text.trim();
                                final newPhone = phoneController.text.trim();
                                final newBirthPlace = birthPlaceController.text.trim();
                                final newBirthDate = birthDateController.text.trim();

                                if (newName.isEmpty) {
                                  showMessage(
                                    'Nama wajib diisi.',
                                    Colors.red,
                                  );
                                  return;
                                }

                                if (Navigator.canPop(modalContext)) {
                                  Navigator.pop(modalContext);
                                }

                                await Future.delayed(const Duration(milliseconds: 100));

                                await updateProfile(
                                  newName: newName,
                                  newUsername: newUsername,
                                  newEmail: newEmail,
                                  newPhone: newPhone,
                                  newGender: selectedGender,
                                  newBirthPlace: newBirthPlace,
                                  newBirthDate: newBirthDate,
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
                        child: const Text(
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
    usernameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    birthPlaceController.dispose();
    birthDateController.dispose();
  }

  // DEKORASI INPUT
  InputDecoration inputDecoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: primaryColor,
      ),
      filled: true,
      fillColor: lightBlue,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
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
    );
  }

  // UPDATE PROFIL
  Future<void> updateProfile({
    required String newName,
    required String newUsername,
    required String newEmail,
    required String newPhone,
    required String newGender,
    required String newBirthPlace,
    required String newBirthDate,
  }) async {
    try {
      if (mounted) setState(() => isSaving = true);

      final token = await getToken();

      if (token == null || token.isEmpty) {
        showMessage('Token tidak ditemukan.', Colors.red);
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(updateProfileUrl),
      );

      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['name'] = newName;
      request.fields['username'] = newUsername;
      request.fields['email'] = newEmail;
      request.fields['phone'] = newPhone;
      request.fields['gender'] = newGender == 'Perempuan' ? 'P' : 'L';
      request.fields['birth_place'] = newBirthPlace;
      request.fields['birth_date'] = newBirthDate;

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(
        streamedResponse,
      );

      dynamic result;

      try {
        result = jsonDecode(response.body);
      } catch (_) {
        result = {};
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        if (!mounted) return;

        setState(() {
          name = newName;
          username = newUsername;
          email = newEmail;
          phone = newPhone;
          gender = newGender;
          birthPlace = newBirthPlace;
          birthDate = newBirthDate;
        });

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
        userMap['username'] = newUsername;
        userMap['email'] = newEmail;
        userMap['phone'] = newPhone;
        userMap['gender'] = newGender == 'Perempuan' ? 'P' : 'L';
        userMap['birth_place'] = newBirthPlace;
        userMap['birth_date'] = newBirthDate;

        if (photoName != null) {
          userMap['photo'] = photoName;
        }

        await prefs.setString('user', jsonEncode(userMap));

        showMessage(
          'Profil berhasil diperbarui.',
          Colors.green,
        );
      } else {
        final message = result is Map && result['message'] != null
            ? result['message'].toString()
            : 'Gagal memperbarui profil.';

        showMessage(message, Colors.red);
      }
    } catch (e) {
      debugPrint('ERROR UPDATE PROFILE: $e');

      showMessage(
        'Tidak dapat terhubung ke server.',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  // LOGOUT
  Future<void> logout() async {
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
          content: const Text(
            'Apakah Anda yakin ingin keluar dari akun?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Batal',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Keluar'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token != null && token.isNotEmpty) {
        try {
          await http.post(
            Uri.parse(logoutUrl),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 30));
        } catch (e) {
          debugPrint('ERROR LOGOUT API: $e');
        }
      }

      await prefs.remove('token');
      await prefs.remove('user');

      if (!mounted) return;

      context.go(AppRoutes.login);
    } catch (e) {
      debugPrint('ERROR LOGOUT: $e');

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');

      if (!mounted) return;

      context.go(AppRoutes.login);
    }
  }

  // WIDGET FOTO PROFIL
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
      child: Icon(
        Icons.person_rounded,
        size: 45,
        color: primaryColor,
      ),
    );
  }

  // ITEM INFORMASI PROFIL
  Widget profileInfoItem({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(
        bottom: isLast ? 0 : 12,
      ),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: primaryColor,
              size: 20,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
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

  // KARTU PROFIL
  Widget profileCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
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
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: profileImageWidget(),
                    ),

                    GestureDetector(
                      onTap: isUploadingPhoto ? null : pickPhoto,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor,
                            width: 2,
                          ),
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
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

                profileInfoItem(
                  icon: Icons.alternate_email_rounded,
                  label: 'Username',
                  value: username,
                ),

                profileInfoItem(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: email,
                ),

                profileInfoItem(
                  icon: Icons.phone_outlined,
                  label: 'Nomor HP',
                  value: phone,
                ),

                profileInfoItem(
                  icon: Icons.wc_outlined,
                  label: 'Jenis Kelamin',
                  value: gender,
                ),

                profileInfoItem(
                  icon: Icons.location_city_outlined,
                  label: 'Tempat Lahir',
                  value: birthPlace,
                ),

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

  // KARTU AKSI
  Widget actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    final color = isLogout ? Colors.red : primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.04),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 14),

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

                      const SizedBox(height: 2),

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

                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profil',
          style: TextStyle(
            color: Color.fromARGB(221, 253, 252, 252),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color.fromARGB(221, 255, 255, 255)),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: getProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    profileCard(),

                    const SizedBox(height: 20),

                    actionCard(
                      icon: Icons.edit_outlined,
                      title: 'Edit Profil',
                      subtitle: 'Ubah informasi data diri akun',
                      onTap: editProfile,
                    ),

                    actionCard(
                      icon: Icons.logout_rounded,
                      title: 'Keluar',
                      subtitle: 'Keluar dari sesi akun saat ini',
                      onTap: logout,
                      isLogout: true,
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
    );
  }
}