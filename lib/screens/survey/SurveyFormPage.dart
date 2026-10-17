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
  LatLng selectedLocation = const LatLng(-7.360680900582117, 108.1057978585817);
  int? selectedCategoryId;
  List<Map<String, dynamic>> categories = [];
  bool isLoadingCategories = true;
  XFile? selectedImage;
  Uint8List? selectedImageBytes;
  Uint8List? existingImageBytes;
  bool isSubmitting = false;
  bool get isEdit => widget.survey != null;

  // THEME BURGUNDY
  static const primaryColor = Color(0xFF800020);
  static const darkBurgundy = Color(0xFF4A0E12);
  static const lightBurgundy = Color(0xFFFDF2F4);
  static const backgroundColor = Color(0xFFFFF4F5);
  static const textColor = Color(0xFF2D1215);
  static const borderColor = Color(0xFFE8D0D5);
  static const secondaryTextColor = Color(0xFF8A6A6D);
  static const successColor = Color(0xFF2E7D32);
  static const errorColor = Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final s = widget.survey!;
      titleController.text = s['title']?.toString() ?? '';
      descriptionController.text = s['description']?.toString() ?? '';
      latitudeController.text = s['latitude']?.toString() ?? '';
      longitudeController.text = s['longitude']?.toString() ?? '';
      selectedCategoryId = int.tryParse(s['category_id']?.toString() ?? '');
      final oldLat = double.tryParse(latitudeController.text.trim());
      final oldLng = double.tryParse(longitudeController.text.trim());
      if (oldLat != null && oldLng != null)
        selectedLocation = LatLng(oldLat, oldLng);
      final photoName = s['photo']?.toString();
      if (photoName != null &&
          photoName.isNotEmpty &&
          photoName != 'placeholder.jpg')
        fetchExistingImage(photoName);
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
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            isLoadingCategories = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => isLoadingCategories = false);
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
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (!mounted) return;
        setState(() => existingImageBytes = response.bodyBytes);
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
      showSnack('Gagal memilih foto.', errorColor, Icons.error_outline);
    }
  }

  void selectMapLocation(LatLng point) {
    setState(() {
      selectedLocation = point;
      latitudeController.text = point.latitude.toStringAsFixed(7);
      longitudeController.text = point.longitude.toStringAsFixed(7);
    });
    showSnack(
      'Lokasi berhasil dipilih dari peta.',
      primaryColor,
      Icons.location_on,
    );
  }

  Future<void> openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      if (await canLaunchUrl(url))
        await launchUrl(url, mode: LaunchMode.externalApplication);
      else
        showSnack(
          'Tidak dapat membuka Google Maps.',
          errorColor,
          Icons.map_outlined,
        );
    } catch (e) {
      showSnack('Gagal membuka Google Maps.', errorColor, Icons.error_outline);
    }
  }

  void removeSelectedImage() => setState(() {
    selectedImage = null;
    selectedImageBytes = null;
    existingImageBytes = null;
  });

  void showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Pilih Sumber Foto',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: darkBurgundy,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: lightBurgundy,
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                title: const Text('Galeri', style: TextStyle(fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: lightBurgundy,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                title: const Text('Kamera', style: TextStyle(fontSize: 14)),
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
      showSnack(
        'Lengkapi data wajib dengan benar.',
        errorColor,
        Icons.warning_amber_rounded,
      );
      return;
    }
    if (selectedCategoryId == null || selectedCategoryId == 0) {
      showSnack('Kategori wajib dipilih.', errorColor, Icons.category_outlined);
      return;
    }
    if (selectedImageBytes == null && existingImageBytes == null) {
      showSnack('Foto survey wajib diisi.', errorColor, Icons.image_outlined);
      return;
    }
    setState(() => isSubmitting = true);
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
      final uri = Uri.parse('https://sijala.biz.id/api/v1/surveys/save');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['title'] = titleController.text.trim();
      request.fields['category_id'] = selectedCategoryId.toString();
      request.fields['description'] = descriptionController.text.trim();
      if (latitudeController.text.trim().isNotEmpty)
        request.fields['latitude'] = latitudeController.text.trim();
      if (longitudeController.text.trim().isNotEmpty)
        request.fields['longitude'] = longitudeController.text.trim();
      if (isEdit) {
        request.fields['id'] = widget.survey!['id'].toString();
        request.fields['_method'] = 'PUT';
      }
      if (selectedImage != null && selectedImageBytes != null)
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            selectedImageBytes!,
            filename: selectedImage!.name,
          ),
        );
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        showSnack(
          isEdit ? 'Survey berhasil diperbarui!' : 'Survey berhasil disimpan!',
          successColor,
          Icons.check_circle,
        );
        Navigator.pop(context, true);
        return;
      }
      if (response.statusCode == 422) {
        final decoded = jsonDecode(response.body);
        throw Exception(decoded['message'] ?? 'Data tidak valid.');
      }
      throw Exception('Gagal menyimpan survey (Kode: ${response.statusCode})');
    } catch (e) {
      if (!mounted) return;
      showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        errorColor,
        Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void showSnack(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(14),
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
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: errorColor),
      ),
    );
  }

  Widget sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: lightBurgundy,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: darkBurgundy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: darkBurgundy,
      ),
    ),
  );

  Widget buildLocationMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 260,
            width: double.infinity,
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: selectedLocation,
                initialZoom: 15,
                onTap: (tap, point) => selectMapLocation(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.field_survey',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLocation,
                      width: 44,
                      height: 50,
                      child: const Icon(
                        Icons.location_pin,
                        color: primaryColor,
                        size: 44,
                      ),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                        mode: LaunchMode.externalApplication,
                      ),
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
            onPressed: () => openGoogleMaps(
              selectedLocation.latitude,
              selectedLocation.longitude,
            ),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text(
              'Buka di Google Maps',
              style: TextStyle(fontSize: 13),
            ),
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
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
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
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Judul wajib diisi';
                        if (v.trim().length < 3) return 'Minimal 3 karakter';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    fieldLabel('Kategori Survey *'),
                    if (isLoadingCategories)
                      const LinearProgressIndicator(
                        color: primaryColor,
                        backgroundColor: lightBurgundy,
                      )
                    else
                      DropdownButtonFormField<int>(
                        value:
                            categories.any(
                              (cat) =>
                                  int.tryParse(cat['id']?.toString() ?? '') ==
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
                          final id =
                              int.tryParse(cat['id']?.toString() ?? '') ?? 0;
                          final name = cat['name']?.toString() ?? '';
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13.5),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => selectedCategoryId = val),
                        validator: (val) => val == null || val == 0
                            ? 'Kategori wajib dipilih'
                            : null,
                      ),
                    const SizedBox(height: 14),
                    fieldLabel('Deskripsi Survey *'),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: fieldDecoration(
                        hint: 'Keterangan atau catatan...',
                        icon: Icons.notes_outlined,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Deskripsi wajib diisi'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              sectionCard(
                icon: Icons.photo_camera_outlined,
                title: 'Foto Survey *',
                child: Column(
                  children: [
                    if (selectedImageBytes != null ||
                        existingImageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
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
                                Icons.photo_library_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                'Ganti',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: const BorderSide(color: primaryColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: removeSelectedImage,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text(
                              'Hapus',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: errorColor,
                              side: BorderSide(
                                color: errorColor.withOpacity(0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      InkWell(
                        onTap: showImageSourceDialog,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: lightBurgundy,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 32,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ketuk untuk memilih foto *',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Galeri atau kamera',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              sectionCard(
                icon: Icons.location_on_outlined,
                title: 'Lokasi Survey',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih lokasi langsung melalui peta.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildLocationMap(),
                    const SizedBox(height: 16),
                    fieldLabel('Latitude *'),
                    TextFormField(
                      controller: latitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: fieldDecoration(
                        hint: '-7.3274000',
                        icon: Icons.my_location_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Latitude wajib diisi';
                        final val = double.tryParse(v.trim());
                        if (val == null || val < -90 || val > 90)
                          return 'Harus -90 sampai 90';
                        return null;
                      },
                      onChanged: (val) {
                        final lat = double.tryParse(val.trim());
                        final lng = double.tryParse(
                          longitudeController.text.trim(),
                        );
                        if (lat != null && lng != null)
                          setState(() => selectedLocation = LatLng(lat, lng));
                      },
                    ),
                    const SizedBox(height: 12),
                    fieldLabel('Longitude *'),
                    TextFormField(
                      controller: longitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: fieldDecoration(
                        hint: '108.2207000',
                        icon: Icons.explore_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Longitude wajib diisi';
                        final val = double.tryParse(v.trim());
                        if (val == null || val < -180 || val > 180)
                          return 'Harus -180 sampai 180';
                        return null;
                      },
                      onChanged: (val) {
                        final lat = double.tryParse(
                          latitudeController.text.trim(),
                        );
                        final lng = double.tryParse(val.trim());
                        if (lat != null && lng != null)
                          setState(() => selectedLocation = LatLng(lat, lng));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting ? null : saveSurvey,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          isEdit
                              ? Icons.save_outlined
                              : Icons.check_circle_outline,
                          size: 20,
                        ),
                  label: Text(
                    isSubmitting
                        ? 'Menyimpan...'
                        : isEdit
                        ? 'Simpan Perubahan'
                        : 'Simpan Survey',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primaryColor.withOpacity(0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
