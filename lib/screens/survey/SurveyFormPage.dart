import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:field_survey/screens/auth/login.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SurveyFormPage extends StatefulWidget {
  // Jika survey null, maka mode Tambah
  // Jika survey != null, maka mode Edit
  final Map<String, dynamic>? survey;

  const SurveyFormPage({super.key, this.survey});

  @override
  State<SurveyFormPage> createState() => _SurveyFormPageState();
}

class _SurveyFormPageState extends State<SurveyFormPage> {
  // ============================================================
  // STATE & CONTROLLER
  // ============================================================

  final formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  // Kategori survey
  int? selectedCategoryId;
  List<Map<String, dynamic>> categories = [];
  bool isLoadingCategories = true;

  // Foto survey
  XFile? selectedImage;
  Uint8List? selectedImageBytes;
  Uint8List? existingImageBytes;

  // Status proses simpan
  bool isSubmitting = false;

  // Mode edit / tambah
  bool get isEdit => widget.survey != null;

  // ============================================================
  // WARNA UTAMA MAROON
  // ============================================================

  static const Color primaryColor = Color(0xFF7B1E3A);

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    // Jika mode edit
    if (isEdit) {
      final s = widget.survey!;

      titleController.text = s['title']?.toString() ?? '';

      descriptionController.text = s['description']?.toString() == ''
          ? ''
          : s['description']?.toString() ?? '';

      latitudeController.text = s['latitude']?.toString() ?? '';

      longitudeController.text = s['longitude']?.toString() ?? '';

      selectedCategoryId = int.tryParse(s['category_id']?.toString() ?? '');

      final photoName = s['photo']?.toString();

      if (photoName != null &&
          photoName.isNotEmpty &&
          photoName != 'placeholder.jpg') {
        fetchExistingImage(photoName);
      }
    }

    // Ambil kategori
    fetchCategories();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  // ============================================================
  // GET KATEGORI
  // ============================================================

  Future<void> fetchCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('https://sijala.biz.id/api/v1/categories'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map && decoded['data'] is List) {
          final List rawList = decoded['data'];

          if (!mounted) return;

          setState(() {
            categories = rawList
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();

            isLoadingCategories = false;
          });

          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        isLoadingCategories = false;
      });
    }
  }

  // ============================================================
  // GET FOTO EXISTING
  // ============================================================

  Future<void> fetchExistingImage(String photoName) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token') ?? '';

      final fileName = photoName.contains('/')
          ? photoName.split('/').last
          : photoName;

      final response = await http.get(
        Uri.parse('https://sijala.biz.id/api/image/$fileName'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          existingImageBytes = response.bodyBytes;
        });
      }
    } catch (_) {}
  }

  // ============================================================
  // PILIH FOTO
  // ============================================================

  Future<void> pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();

      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();

        if (!mounted) return;

        setState(() {
          selectedImage = pickedFile;
          selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      showErrorSnackBar('Gagal memilih foto.');
    }
  }

  // ============================================================
  // HAPUS FOTO
  // ============================================================

  void removeSelectedImage() {
    setState(() {
      selectedImage = null;
      selectedImageBytes = null;
      existingImageBytes = null;
    });
  }

  // ============================================================
  // DIALOG PILIH FOTO
  // ============================================================

  void showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pilih Sumber Foto',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              ListTile(
                leading: const Icon(Icons.photo_library, color: primaryColor),
                title: const Text('Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  pickImage(ImageSource.gallery);
                },
              ),

              ListTile(
                leading: const Icon(Icons.camera_alt, color: primaryColor),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.pop(ctx);
                  pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SIMPAN SURVEY
  // ============================================================

  Future<void> saveSurvey() async {
    if (!formKey.currentState!.validate()) {
      showErrorSnackBar('Lengkapi data yang wajib diisi.');
      return;
    }

    if (selectedCategoryId == null || selectedCategoryId == 0) {
      showErrorSnackBar('Kategori survey wajib dipilih.');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );

        return;
      }

      // URL API
      final uri = Uri.parse('https://sijala.biz.id/api/v1/surveys/save');

      final request = http.MultipartRequest('POST', uri);

      // Header
      request.headers['Accept'] = 'application/json';

      request.headers['Authorization'] = 'Bearer $token';

      // Data
      request.fields['title'] = titleController.text.trim();

      request.fields['category_id'] = selectedCategoryId.toString();

      request.fields['description'] = descriptionController.text.trim();

      if (latitudeController.text.trim().isNotEmpty) {
        request.fields['latitude'] = latitudeController.text.trim();
      }

      if (longitudeController.text.trim().isNotEmpty) {
        request.fields['longitude'] = longitudeController.text.trim();
      }

      // Edit
      if (isEdit) {
        request.fields['id'] = widget.survey!['id'].toString();

        request.fields['_method'] = 'PUT';
      }

      // Foto
      if (selectedImage != null && selectedImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            selectedImageBytes!,
            filename: selectedImage!.name,
          ),
        );
      }

      // Kirim
      final streamed = await request.send();

      final response = await http.Response.fromStream(streamed);

      // Berhasil
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Survey berhasil diperbarui!'
                  : 'Survey berhasil disimpan!',
            ),
            backgroundColor: const Color(0xFF108981),
          ),
        );

        Navigator.pop(context, true);

        return;
      }

      // Error validasi
      if (response.statusCode == 422) {
        final decoded = jsonDecode(response.body);

        final message = decoded['message'] ?? 'Data yang dikirim tidak valid.';

        throw Exception(message);
      }

      throw Exception(
        'Gagal menyimpan '
        '(Kode: ${response.statusCode})',
      );
    } catch (e) {
      if (!mounted) return;

      showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  // ============================================================
  // SNACKBAR ERROR
  // ============================================================

  void showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444)),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Survey' : 'Tambah Survey'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Form(
          key: formKey,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              // ==================================================
              // KARTU DATA UTAMA
              // ==================================================
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),

                child: Padding(
                  padding: const EdgeInsets.all(16),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'Data Utama Survey',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // JUDUL
                      const Text(
                        'Judul Survey *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      TextFormField(
                        controller: titleController,

                        decoration: const InputDecoration(
                          hintText: 'Masukkan judul survey',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title, color: primaryColor),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                        ),

                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Judul wajib diisi';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // KATEGORI
                      const Text(
                        'Kategori Survey *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      if (isLoadingCategories)
                        const LinearProgressIndicator(color: primaryColor)
                      else
                        DropdownButtonFormField<int>(
                          initialValue: selectedCategoryId,

                          decoration: const InputDecoration(
                            hintText: 'Pilih Kategori',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.category,
                              color: primaryColor,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: primaryColor,
                                width: 2,
                              ),
                            ),
                          ),

                          items: categories.map((cat) {
                            final id =
                                int.tryParse(cat['id']?.toString() ?? '') ?? 0;

                            final name = cat['name']?.toString() ?? '';

                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(name),
                            );
                          }).toList(),

                          onChanged: (val) {
                            setState(() {
                              selectedCategoryId = val;
                            });
                          },

                          validator: (val) {
                            if (val == null || val == 0) {
                              return 'Kategori wajib dipilih';
                            }

                            return null;
                          },
                        ),

                      const SizedBox(height: 16),

                      // DESKRIPSI
                      const Text(
                        'Deskripsi Survey',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      TextFormField(
                        controller: descriptionController,

                        maxLines: 3,

                        decoration: const InputDecoration(
                          hintText: 'Keterangan atau catatan survey...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.notes, color: primaryColor),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // KARTU FOTO
              // ==================================================
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),

                child: Padding(
                  padding: const EdgeInsets.all(16),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'Foto Survey',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (selectedImageBytes != null ||
                          existingImageBytes != null)
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),

                              child: Image.memory(
                                selectedImageBytes ?? existingImageBytes!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: showImageSourceDialog,

                                    icon: const Icon(
                                      Icons.photo_library,
                                      color: primaryColor,
                                    ),

                                    label: const Text('Ganti Foto'),

                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: const BorderSide(
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                OutlinedButton.icon(
                                  onPressed: removeSelectedImage,

                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                  ),

                                  icon: const Icon(Icons.delete),

                                  label: const Text('Hapus'),
                                ),
                              ],
                            ),
                          ],
                        )
                      else
                        InkWell(
                          onTap: showImageSourceDialog,

                          borderRadius: BorderRadius.circular(8),

                          child: Container(
                            height: 120,
                            width: double.infinity,

                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),

                              borderRadius: BorderRadius.circular(8),

                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),

                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,

                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 36,
                                  color: primaryColor,
                                ),

                                SizedBox(height: 8),

                                Text(
                                  'Ketuk untuk memilih foto',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // KARTU LOKASI
              // ==================================================
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),

                child: Padding(
                  padding: const EdgeInsets.all(16),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Text(
                        'Lokasi Survey (Koordinat)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: latitudeController,

                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),

                              decoration: const InputDecoration(
                                labelText: 'Latitude',
                                hintText: '-7.3274000',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.my_location,
                                  color: primaryColor,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: TextFormField(
                              controller: longitudeController,

                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),

                              decoration: const InputDecoration(
                                labelText: 'Longitude',
                                hintText: '108.2207000',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.explore,
                                  color: primaryColor,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // TOMBOL SIMPAN
              // ==================================================
              SizedBox(
                height: 48,

                child: ElevatedButton(
                  onPressed: isSubmitting ? null : saveSurvey,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,

                    foregroundColor: Colors.white,

                    disabledBackgroundColor: primaryColor.withOpacity(0.6),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,

                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEdit ? 'Simpan Perubahan' : 'Simpan Survey',

                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
