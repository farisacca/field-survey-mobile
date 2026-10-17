import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:field_survey/screens/auth/login.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SurveyFormPage extends StatefulWidget {
  final Map<String, dynamic>? survey;

  const SurveyFormPage({super.key, this.survey});

  @override
  State<SurveyFormPage> createState() => _SurveyFormPageState();
}

class _SurveyFormPageState extends State<SurveyFormPage> {
  final formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  
  final MapController mapController = MapController();

  
  LatLng selectedLocation = const LatLng(
    -7.360680900582117,
    108.1057978585817,
  );

  int? selectedCategoryId;
  List<Map<String, dynamic>> categories = [];
  bool isLoadingCategories = true;

  XFile? selectedImage;
  Uint8List? selectedImageBytes;
  Uint8List? existingImageBytes;

  bool isSubmitting = false;

  bool get isEdit => widget.survey != null;

  static const Color primaryColor = Color(0xFF1976D2);
  static const Color lightBlue = Color(0xFFE3F0FF);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color textColor = Color(0xFF1E293B);
  static const Color borderColor = Color(0xFFD6E6F8);
  static const Color secondaryTextColor = Color(0xFF64748B);
  static const Color dangerColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();

    if (isEdit) {
      final s = widget.survey!;

      titleController.text = s['title']?.toString() ?? '';
      descriptionController.text = s['description']?.toString() ?? '';
      latitudeController.text = s['latitude']?.toString() ?? '';
      longitudeController.text = s['longitude']?.toString() ?? '';

      selectedCategoryId =
          int.tryParse(s['category_id']?.toString() ?? '');


      final oldLatitude = double.tryParse(
        latitudeController.text.trim(),
      );
      final oldLongitude = double.tryParse(
        longitudeController.text.trim(),
      );

      if (oldLatitude != null &&
          oldLongitude != null &&
          oldLatitude >= -90 &&
          oldLatitude <= 90 &&
          oldLongitude >= -180 &&
          oldLongitude <= 180) {
        selectedLocation = LatLng(oldLatitude, oldLongitude);
      }

      final photoName = s['photo']?.toString();

      if (photoName != null &&
          photoName.isNotEmpty &&
          photoName != 'placeholder.jpg') {
        fetchExistingImage(photoName);
      }
    }

    fetchCategories();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    mapController.dispose();
    super.dispose();
  }

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

      if (response.statusCode == 200 &&
          response.bodyBytes.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          existingImageBytes = response.bodyBytes;
        });
      }
    } catch (_) {}
  }

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
    } catch (_) {
      showErrorSnackBar('Gagal memilih foto.');
    }
  }


  void selectMapLocation(LatLng point) {
    setState(() {
      selectedLocation = point;

      latitudeController.text = point.latitude.toStringAsFixed(7);
      longitudeController.text = point.longitude.toStringAsFixed(7);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lokasi berhasil dipilih dari peta.'),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  
  Future<void> openGoogleMaps(
    double latitude,
    double longitude,
  ) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    try {
      final canOpen = await canLaunchUrl(url);

      if (canOpen) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka Google Maps.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('GOOGLE MAP ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membuka Google Maps.'),
        ),
      );
    }
  }

  
  void removeSelectedImage() {
    setState(() {
      selectedImage = null;
      selectedImageBytes = null;
      existingImageBytes = null;
    });
  }

  
  void showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih Sumber Foto',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: lightBlue,
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: primaryColor,
                  ),
                ),
                title: const Text('Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: lightBlue,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: primaryColor,
                  ),
                ),
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


  Future<void> saveSurvey() async {
    if (!formKey.currentState!.validate()) {
      showErrorSnackBar(
        'Lengkapi data yang wajib diisi dengan benar.',
      );
      return;
    }

    if (selectedCategoryId == null || selectedCategoryId == 0) {
      showErrorSnackBar('Kategori survey wajib dipilih.');
      return;
    }

    if (selectedImageBytes == null && existingImageBytes == null) {
      showErrorSnackBar('Foto survey wajib diisi.');
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
          MaterialPageRoute(
            builder: (context) => const LoginPage(),
          ),
          (route) => false,
        );

        return;
      }

      final uri = Uri.parse(
        'https://sijala.biz.id/api/v1/surveys/save',
      );

      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['title'] = titleController.text.trim();
      request.fields['category_id'] =
          selectedCategoryId.toString();
      request.fields['description'] =
          descriptionController.text.trim();

      if (latitudeController.text.trim().isNotEmpty) {
        request.fields['latitude'] =
            latitudeController.text.trim();
      }

      if (longitudeController.text.trim().isNotEmpty) {
        request.fields['longitude'] =
            longitudeController.text.trim();
      }

      if (isEdit) {
        request.fields['id'] = widget.survey!['id'].toString();
        request.fields['_method'] = 'PUT';
      }

      if (selectedImage != null && selectedImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            selectedImageBytes!,
            filename: selectedImage!.name,
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Survey berhasil diperbarui!'
                  : 'Survey berhasil disimpan!',
            ),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context, true);
        return;
      }

      if (response.statusCode == 422) {
        final decoded = jsonDecode(response.body);
        final message =
            decoded['message'] ?? 'Data yang dikirim tidak valid.';

        throw Exception(message);
      }

      throw Exception(
        'Gagal menyimpan survey (Kode: ${response.statusCode})',
      );
    } catch (e) {
      if (!mounted) return;

      showErrorSnackBar(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  
  void showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: dangerColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  InputDecoration fieldDecoration({
    required String hint,
    required IconData icon,
    String? label,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(icon, color: primaryColor),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: primaryColor,
          width: 1.8,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: dangerColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: dangerColor,
          width: 1.5,
        ),
      ),
    );
  }


  Widget sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: lightBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }


  Widget fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget buildLocationMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 280,
            width: double.infinity,
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: selectedLocation,
                initialZoom: 15,

                
                onTap: (tapPosition, point) {
                  selectMapLocation(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.field_survey',
                ),

                
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLocation,
                      width: 46,
                      height: 54,
                      child: const Icon(
                        Icons.location_pin,
                        color: primaryColor,
                        size: 46,
                      ),
                    ),
                  ],
                ),


                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () {
                        launchUrl(
                          Uri.parse(
                            'https://www.openstreetmap.org/copyright',
                          ),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

  
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              openGoogleMaps(
                selectedLocation.latitude,
                selectedLocation.longitude,
              );
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Buka di Google Maps'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: const BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Survey' : 'Tambah Survey',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
  
              sectionCard(
                icon: Icons.assignment_outlined,
                title: 'Data Utama Survey',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    fieldLabel('Judul Survey *'),
                    TextFormField(
                      controller: titleController,
                      decoration: fieldDecoration(
                        hint: 'Masukkan judul survey',
                        icon: Icons.title,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Judul survey wajib diisi';
                        }
                        if (val.trim().length < 3) {
                          return 'Judul minimal harus 3 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    fieldLabel('Kategori Survey *'),
                    if (isLoadingCategories)
                      const LinearProgressIndicator(
                        color: primaryColor,
                        backgroundColor: lightBlue,
                      )
                    else
                      DropdownButtonFormField<int>(
                        value: categories.any(
                          (cat) =>
                              int.tryParse(
                                cat['id']?.toString() ?? '',
                              ) ==
                              selectedCategoryId,
                        )
                            ? selectedCategoryId
                            : null,
                        isExpanded: true,
                        decoration: fieldDecoration(
                          hint: 'Pilih Kategori',
                          icon: Icons.category_outlined,
                        ),
                        items: categories.map((cat) {
                          final id = int.tryParse(
                                cat['id']?.toString() ?? '',
                              ) ??
                              0;
                          final name = cat['name']?.toString() ?? '';

                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedCategoryId = val;
                          });
                        },
                        validator: (val) {
                          if (val == null || val == 0) {
                            return 'Kategori survey wajib dipilih';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),

                    fieldLabel('Deskripsi Survey *'),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: fieldDecoration(
                        hint: 'Keterangan atau catatan survey...',
                        icon: Icons.notes_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Deskripsi survey wajib diisi';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              sectionCard(
                icon: Icons.photo_camera_outlined,
                title: 'Foto Survey *',
                child: Column(
                  children: [
                    if (selectedImageBytes != null ||
                        existingImageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          selectedImageBytes ?? existingImageBytes!,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: showImageSourceDialog,
                              icon: const Icon(
                                Icons.photo_library_outlined,
                              ),
                              label: const Text('Ganti Foto'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: const BorderSide(
                                  color: primaryColor,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: removeSelectedImage,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Hapus'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: dangerColor,
                              side: const BorderSide(
                                color: Color(0xFFFECACA),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      InkWell(
                        onTap: showImageSourceDialog,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: borderColor,
                              width: 1.3,
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 38,
                                color: primaryColor,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Ketuk untuk memilih foto *',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Galeri atau kamera',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

        
              sectionCard(
                icon: Icons.location_on_outlined,
                title: 'Lokasi Survey',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih lokasi survey langsung melalui peta.',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 14),

                
                    buildLocationMap(),

                    const SizedBox(height: 18),

                    fieldLabel('Latitude *'),
                    TextFormField(
                      controller: latitudeController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: fieldDecoration(
                        hint: '-7.3274000',
                        icon: Icons.my_location_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Latitude wajib diisi';
                        }

                        final value = double.tryParse(val.trim());

                        if (value == null ||
                            value < -90 ||
                            value > 90) {
                          return 'Latitude harus antara -90 dan 90';
                        }

                        return null;
                      },
                      onChanged: (value) {
                        final latitude =
                            double.tryParse(value.trim());
                        final longitude = double.tryParse(
                          longitudeController.text.trim(),
                        );

                        if (latitude != null &&
                            longitude != null &&
                            latitude >= -90 &&
                            latitude <= 90 &&
                            longitude >= -180 &&
                            longitude <= 180) {
                          setState(() {
                            selectedLocation = LatLng(
                              latitude,
                              longitude,
                            );
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    fieldLabel('Longitude *'),
                    TextFormField(
                      controller: longitudeController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: fieldDecoration(
                        hint: '108.2207000',
                        icon: Icons.explore_outlined,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Longitude wajib diisi';
                        }

                        final value = double.tryParse(val.trim());

                        if (value == null ||
                            value < -180 ||
                            value > 180) {
                          return 'Longitude harus antara -180 dan 180';
                        }

                        return null;
                      },
                      onChanged: (value) {
                        final latitude = double.tryParse(
                          latitudeController.text.trim(),
                        );
                        final longitude =
                            double.tryParse(value.trim());

                        if (latitude != null &&
                            longitude != null &&
                            latitude >= -90 &&
                            latitude <= 90 &&
                            longitude >= -180 &&
                            longitude <= 180) {
                          setState(() {
                            selectedLocation = LatLng(
                              latitude,
                              longitude,
                            );
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

            
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : saveSurvey,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          isEdit
                              ? Icons.save_outlined
                              : Icons.check_circle_outline,
                        ),
                  label: Text(
                    isSubmitting
                        ? 'Menyimpan...'
                        : isEdit
                            ? 'Simpan Perubahan'
                            : 'Simpan Survey',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        primaryColor.withOpacity(0.6),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
