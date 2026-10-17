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
  // THEME BURGUNDY
  static const primaryColor = Color(0xFF800020);
  static const darkBurgundy = Color(0xFF4A0E12);
  static const backgroundColor = Color(0xFFFFF4F5);
  static const lightBurgundy = Color(0xFFFDF2F4);
  static const successColor = Color(0xFF2E7D32);
  static const errorColor = Color(0xFFC62828);

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

  void showMessage(String message, Color color, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(15),
        ),
      );
  }

  Future<void> getProfile() async {
    try {
      if (mounted) setState(() => isLoading = true);
      final token = await getToken();
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => isLoading = false);
        showMessage(
          'Token tidak ditemukan. Login kembali.',
          errorColor,
          Icons.error_outline,
        );
        return;
      }
      final response = await http
          .get(
            Uri.parse(profileUrl),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));
      dynamic result;
      try {
        result = jsonDecode(response.body);
      } catch (_) {
        result = {};
      }
      if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('user');
        if (!mounted) return;
        showMessage(
          'Sesi login berakhir.',
          errorColor,
          Icons.warning_amber_rounded,
        );
        context.go(AppRoutes.login);
        return;
      }
      if (response.statusCode == 200) {
        dynamic profileData = result is Map
            ? (result['data'] is Map ? result['data'] : result)
            : null;
        if (profileData is Map) {
          final data = Map<String, dynamic>.from(profileData);
          String newGender = '-';
          final gv = data['gender']?.toString();
          if (gv == 'L')
            newGender = 'Laki-laki';
          else if (gv == 'P')
            newGender = 'Perempuan';
          else if (gv != null && gv.isNotEmpty)
            newGender = gv;
          String? newPhoto = data['photo']?.toString();
          if (newPhoto == 'null' || newPhoto?.isEmpty == true) newPhoto = null;
          if (!mounted) return;
          setState(() {
            name = data['name']?.toString() ?? '-';
            username = data['username']?.toString() ?? '-';
            email = data['email']?.toString() ?? '-';
            phone = data['phone']?.toString() ?? '-';
            birthPlace =
                data['birth_place']?.toString() ??
                data['birthPlace']?.toString() ??
                '-';
            birthDate =
                data['birth_date']?.toString() ??
                data['birthDate']?.toString() ??
                '-';
            gender = newGender;
            photoName = newPhoto;
          });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(data));
          if (newPhoto != null)
            await loadProfileImage(newPhoto);
          else
            await loadSavedPhoto(email);
        }
      } else {
        final message = result is Map && result['message'] != null
            ? result['message'].toString()
            : 'Gagal mengambil profil';
        showMessage(message, errorColor, Icons.error_outline);
        await loadSavedPhoto(email);
      }
    } catch (e) {
      await loadSavedPhoto(email);
      showMessage(
        'Tidak dapat terhubung ke server.',
        errorColor,
        Icons.wifi_off_rounded,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> loadProfileImage(String fileName) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return;
      final response = await http
          .get(
            Uri.parse('https://sijala.biz.id/api/image/$fileName'),
            headers: {'Authorization': 'Bearer $token', 'Accept': '*/*'},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'profile_photo_${email.toLowerCase()}',
          base64Encode(response.bodyBytes),
        );
        if (!mounted) return;
        setState(() => profileImage = response.bodyBytes);
      } else {
        await loadSavedPhoto(email);
      }
    } catch (e) {
      await loadSavedPhoto(email);
    }
  }

  Future<void> loadSavedPhoto(String userEmail) async {
    try {
      if (userEmail.isEmpty || userEmail == '-') return;
      final prefs = await SharedPreferences.getInstance();
      final savedPhoto = prefs.getString(
        'profile_photo_${userEmail.toLowerCase()}',
      );
      if (savedPhoto == null || savedPhoto.isEmpty) return;
      final bytes = base64Decode(savedPhoto);
      if (!mounted) return;
      setState(() => profileImage = bytes);
    } catch (e) {
      debugPrint('ERROR LOAD SAVED PHOTO: $e');
    }
  }

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
        showMessage('File tidak bisa dibaca.', errorColor, Icons.error_outline);
        return;
      }
      if (!mounted) return;
      setState(() {
        selectedPhoto = file.bytes;
        profileImage = file.bytes;
      });
      await uploadPhoto(file.bytes!, file.name);
    } catch (e) {
      showMessage('Gagal memilih foto.', errorColor, Icons.error_outline);
    }
  }

  Future<void> uploadPhoto(Uint8List bytes, String fileName) async {
    try {
      if (mounted) setState(() => isUploadingPhoto = true);
      final token = await getToken();
      if (token == null || token.isEmpty) {
        showMessage('Token tidak ditemukan.', errorColor, Icons.error_outline);
        return;
      }
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(updateProfileUrl),
      );
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      if (name != '-') request.fields['name'] = name;
      if (username != '-') request.fields['username'] = username;
      if (email != '-') request.fields['email'] = email;
      if (phone != '-') request.fields['phone'] = phone;
      if (birthPlace != '-') request.fields['birth_place'] = birthPlace;
      if (birthDate != '-') request.fields['birth_date'] = birthDate;
      if (gender == 'Laki-laki')
        request.fields['gender'] = 'L';
      else if (gender == 'Perempuan')
        request.fields['gender'] = 'P';
      request.files.add(
        http.MultipartFile.fromBytes('photo', bytes, filename: fileName),
      );
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);
      dynamic result;
      try {
        result = jsonDecode(response.body);
      } catch (_) {
        result = {};
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        String? newPhotoName;
        if (result is Map) {
          if (result['photo'] != null)
            newPhotoName = result['photo'].toString();
          else if (result['data'] is Map && result['data']['photo'] != null)
            newPhotoName = result['data']['photo'].toString();
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'profile_photo_${email.toLowerCase()}',
          base64Encode(bytes),
        );
        if (newPhotoName != null && newPhotoName.isNotEmpty) {
          photoName = newPhotoName;
          await prefs.setString(
            'profile_photo_name_${email.toLowerCase()}',
            newPhotoName,
          );
        }
        if (!mounted) return;
        setState(() => profileImage = bytes);
        showMessage(
          'Foto profil berhasil diperbarui.',
          successColor,
          Icons.check_circle,
        );
      } else {
        final message = result is Map && result['message'] != null
            ? result['message'].toString()
            : 'Gagal upload foto.';
        showMessage(message, errorColor, Icons.error_outline);
      }
    } catch (e) {
      showMessage('Gagal upload foto.', errorColor, Icons.error_outline);
    } finally {
      if (mounted)
        setState(() {
          isUploadingPhoto = false;
          selectedPhoto = null;
        });
    }
  }

  Future<void> editProfile() async {
    final nameC = TextEditingController(text: name == '-' ? '' : name);
    final usernameC = TextEditingController(
      text: username == '-' ? '' : username,
    );
    final emailC = TextEditingController(text: email == '-' ? '' : email);
    final phoneC = TextEditingController(text: phone == '-' ? '' : phone);
    final birthPlaceC = TextEditingController(
      text: birthPlace == '-' ? '' : birthPlace,
    );
    final birthDateC = TextEditingController(
      text: birthDate == '-' ? '' : birthDate,
    );
    String selectedGender = gender == 'Perempuan' ? 'Perempuan' : 'Laki-laki';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Edit Profil',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkBurgundy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Perbarui informasi profil kamu',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameC,
                      decoration: inputDecoration(
                        'Nama',
                        Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: usernameC,
                      decoration: inputDecoration(
                        'Username',
                        Icons.alternate_email_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailC,
                      keyboardType: TextInputType.emailAddress,
                      decoration: inputDecoration(
                        'Email',
                        Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: phoneC,
                      keyboardType: TextInputType.phone,
                      decoration: inputDecoration(
                        'Nomor HP',
                        Icons.phone_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedGender = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: birthPlaceC,
                      decoration: inputDecoration(
                        'Tempat Lahir',
                        Icons.location_city_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: birthDateC,
                      decoration: inputDecoration(
                        'Tanggal Lahir (YYYY-MM-DD)',
                        Icons.calendar_month_outlined,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (nameC.text.trim().isEmpty) {
                                  showMessage(
                                    'Nama wajib diisi.',
                                    errorColor,
                                    Icons.error_outline,
                                  );
                                  return;
                                }
                                if (Navigator.canPop(modalContext))
                                  Navigator.pop(modalContext);
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );
                                await updateProfile(
                                  newName: nameC.text.trim(),
                                  newUsername: usernameC.text.trim(),
                                  newEmail: emailC.text.trim(),
                                  newPhone: phoneC.text.trim(),
                                  newGender: selectedGender,
                                  newBirthPlace: birthPlaceC.text.trim(),
                                  newBirthDate: birthDateC.text.trim(),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Simpan Perubahan',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
    nameC.dispose();
    usernameC.dispose();
    emailC.dispose();
    phoneC.dispose();
    birthPlaceC.dispose();
    birthDateC.dispose();
  }

  InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true,
      fillColor: lightBurgundy,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 1.2),
      ),
    );
  }

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
        showMessage('Token tidak ditemukan.', errorColor, Icons.error_outline);
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
      final response = await http.Response.fromStream(streamedResponse);
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
          username = newUsername;
          email = newEmail;
          phone = newPhone;
          gender = newGender;
          birthPlace = newBirthPlace;
          birthDate = newBirthDate;
        });
        final prefs = await SharedPreferences.getInstance();
        Map<String, dynamic> userMap = {};
        final oldUser = prefs.getString('user');
        if (oldUser != null && oldUser.isNotEmpty) {
          try {
            final d = jsonDecode(oldUser);
            if (d is Map) userMap = Map<String, dynamic>.from(d);
          } catch (_) {}
        }
        userMap['name'] = newName;
        userMap['username'] = newUsername;
        userMap['email'] = newEmail;
        userMap['phone'] = newPhone;
        userMap['gender'] = newGender == 'Perempuan' ? 'P' : 'L';
        userMap['birth_place'] = newBirthPlace;
        userMap['birth_date'] = newBirthDate;
        if (photoName != null) userMap['photo'] = photoName;
        await prefs.setString('user', jsonEncode(userMap));
        showMessage(
          'Profil berhasil diperbarui.',
          successColor,
          Icons.check_circle,
        );
      } else {
        final message = result is Map && result['message'] != null
            ? result['message'].toString()
            : 'Gagal memperbarui profil.';
        showMessage(message, errorColor, Icons.error_outline);
      }
    } catch (e) {
      showMessage(
        'Tidak dapat terhubung ke server.',
        errorColor,
        Icons.wifi_off_rounded,
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> logout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Konfirmasi Logout',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: darkBurgundy,
            ),
          ),
          content: const Text(
            'Yakin ingin keluar dari akun?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Batal',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
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
    if (result != true) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null && token.isNotEmpty) {
        try {
          await http
              .post(
                Uri.parse(logoutUrl),
                headers: {
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
              )
              .timeout(const Duration(seconds: 30));
        } catch (_) {}
      }
      await prefs.remove('token');
      await prefs.remove('user');
      if (!mounted) return;
      context.go(AppRoutes.login);
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');
      if (!mounted) return;
      context.go(AppRoutes.login);
    }
  }

  Widget profileImageWidget() {
    if (selectedPhoto != null)
      return CircleAvatar(
        radius: 42,
        backgroundImage: MemoryImage(selectedPhoto!),
      );
    if (profileImage != null)
      return CircleAvatar(
        radius: 42,
        backgroundImage: MemoryImage(profileImage!),
      );
    return const CircleAvatar(
      radius: 42,
      backgroundColor: Colors.white,
      child: Icon(Icons.person_rounded, size: 42, color: primaryColor),
    );
  }

  Widget profileInfoItem({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightBurgundy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: darkBurgundy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget profileCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
            decoration: const BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: profileImageWidget(),
                    ),
                    GestureDetector(
                      onTap: isUploadingPhoto ? null : pickPhoto,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryColor, width: 2),
                        ),
                        child: isUploadingPhoto
                            ? const Padding(
                                padding: EdgeInsets.all(6),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: primaryColor,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: primaryColor,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '@$username',
                    style: const TextStyle(fontSize: 12.5, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Informasi Pribadi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: darkBurgundy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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

  Widget actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    final color = isLogout ? errorColor : primaryColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isLogout ? errorColor : darkBurgundy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
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
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: getProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    profileCard(),
                    const SizedBox(height: 18),
                    actionCard(
                      icon: Icons.edit_outlined,
                      title: 'Edit Profil',
                      subtitle: 'Ubah informasi data diri',
                      onTap: editProfile,
                    ),
                    actionCard(
                      icon: Icons.logout_rounded,
                      title: 'Keluar',
                      subtitle: 'Keluar dari sesi akun',
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
