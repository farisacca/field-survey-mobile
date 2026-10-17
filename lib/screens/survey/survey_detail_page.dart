import 'dart:convert';
import 'dart:typed_data';
import 'package:field_survey/screens/auth/login.dart';
import 'package:field_survey/screens/survey/SurveyFormPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SurveyDetailPage extends StatefulWidget {
  final int surveyId;
  const SurveyDetailPage({super.key, required this.surveyId});
  @override
  State<SurveyDetailPage> createState() => _SurveyDetailPageState();
}

class _SurveyDetailPageState extends State<SurveyDetailPage> {
  // THEME BURGUNDY
  static const primaryColor = Color(0xFF800020);
  static const darkBurgundy = Color(0xFF4A0E12);
  static const lightBurgundy = Color(0xFFFDF2F4);
  static const backgroundColor = Color(0xFFFFF4F5);
  static const borderColor = Color(0xFFE8D0D5);
  static const textColor = Color(0xFF2D1215);
  static const greyColor = Color(0xFF8A6A6D);
  static const successColor = Color(0xFF2E7D32);
  static const errorColor = Color(0xFFC62828);

  Map<String, dynamic>? survey;
  bool isLoading = true;
  bool isLoadingImage = false;
  String? errorMessage;
  Uint8List? imageBytes;

  @override
  void initState() {
    super.initState();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    if (mounted)
      setState(() {
        isLoading = true;
        errorMessage = null;
        imageBytes = null;
        isLoadingImage = false;
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
      final url = Uri.parse(
        'https://sijala.biz.id/api/v1/surveys/${widget.surveyId}',
      );
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
        return;
      }
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result is Map &&
            result['status'] == true &&
            result['data'] != null) {
          final data = Map<String, dynamic>.from(result['data']);
          if (!mounted) return;
          setState(() {
            survey = data;
            isLoading = false;
          });
          final photo = data['photo']?.toString();
          if (photo != null &&
              photo.isNotEmpty &&
              photo != 'null' &&
              photo != 'placeholder.jpg')
            await fetchImage(photo, token);
          return;
        }
        if (!mounted) return;
        setState(() {
          isLoading = false;
          errorMessage =
              result['message']?.toString() ?? 'Data survey tidak ditemukan.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Survey tidak ditemukan (Kode: ${response.statusCode})';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage =
            'Gagal memuat detail survey.\nPeriksa koneksi internet Anda.';
      });
    }
  }

  Future<void> fetchImage(String photoName, String token) async {
    if (!mounted) return;
    setState(() => isLoadingImage = true);
    try {
      final fileName = photoName.contains('/')
          ? photoName.split('/').last
          : photoName;
      final url = Uri.parse('https://sijala.biz.id/api/image/$fileName');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty)
        setState(() {
          imageBytes = response.bodyBytes;
          isLoadingImage = false;
        });
      else
        setState(() => isLoadingImage = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingImage = false);
    }
  }

  Future<void> deleteSurvey() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Hapus Survey?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: darkBurgundy,
              fontSize: 16,
            ),
          ),
          content: const Text(
            'Apakah kamu yakin ingin menghapus survey ini?',
            style: TextStyle(fontSize: 13.5),
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
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        showSnack(
          'Token tidak ditemukan. Login kembali.',
          errorColor,
          Icons.error_outline,
        );
        return;
      }
      final url = Uri.parse(
        'https://sijala.biz.id/api/v1/surveys/${widget.surveyId}/delete',
      );
      final response = await http.post(
        url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({}),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        String message = 'Survey berhasil dihapus';
        if (response.body.isNotEmpty) {
          try {
            final r = jsonDecode(response.body);
            if (r is Map && r['message'] != null)
              message = r['message'].toString();
          } catch (_) {}
        }
        if (!mounted) return;
        showSnack(message, successColor, Icons.check_circle);
        Navigator.pop(context, true);
        return;
      }
      if (response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
        return;
      }
      String message = 'Gagal menghapus survey';
      if (response.body.isNotEmpty) {
        try {
          final r = jsonDecode(response.body);
          if (r is Map && r['message'] != null)
            message = r['message'].toString();
        } catch (_) {}
      }
      showSnack(
        '$message (Kode: ${response.statusCode})',
        errorColor,
        Icons.error_outline,
      );
    } catch (e) {
      showSnack(
        'Terjadi kesalahan saat menghapus survey.',
        errorColor,
        Icons.error_outline,
      );
    }
  }

  Future<void> editSurvey() async {
    if (survey == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SurveyFormPage(survey: survey!)),
    );
    if (result == true && mounted) fetchDetail();
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

  void copyCoordinates(double lat, double lng) {
    Clipboard.setData(ClipboardData(text: '$lat, $lng'));
    showSnack('Koordinat berhasil disalin!', primaryColor, Icons.copy_rounded);
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

  void showFullImageDialog(Uint8List bytes) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(15),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Detail Survey',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (survey != null)
            IconButton(
              onPressed: editSurvey,
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
            ),
          if (survey != null)
            IconButton(
              onPressed: deleteSurvey,
              icon: const Icon(Icons.delete_outline, color: Colors.white),
            ),
        ],
      ),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    if (isLoading)
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            SizedBox(height: 12),
            Text(
              'Memuat detail survey...',
              style: TextStyle(color: greyColor, fontSize: 13),
            ),
          ],
        ),
      );
    if (errorMessage != null || survey == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: lightBurgundy,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: primaryColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                errorMessage ?? 'Data survey tidak ditemukan.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final String title =
        survey!['title']?.toString() ?? survey!['name']?.toString() ?? '-';
    final String description = survey!['description']?.toString() ?? '-';
    final String category =
        survey!['category_name']?.toString() ??
        survey!['category']?['name']?.toString() ??
        'Tanpa Kategori';
    final String createdAt = survey!['created_at']?.toString() ?? '-';
    final double? latitude = double.tryParse(
      survey!['latitude']?.toString() ?? '',
    );
    final double? longitude = double.tryParse(
      survey!['longitude']?.toString() ?? '',
    );
    final bool hasValidCoords = latitude != null && longitude != null;

    return RefreshIndicator(
      color: primaryColor,
      backgroundColor: Colors.white,
      onRefresh: fetchDetail,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: lightBurgundy,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkBurgundy,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        createdAt,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: greyColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Text(
                    'Foto Survey',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: darkBurgundy,
                    ),
                  ),
                ),
                if (isLoadingImage)
                  const SizedBox(
                    height: 180,
                    child: Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  )
                else if (imageBytes != null)
                  GestureDetector(
                    onTap: () => showFullImageDialog(imageBytes!),
                    child: Image.memory(
                      imageBytes!,
                      width: double.infinity,
                      height: 210,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 130,
                    color: lightBurgundy,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          size: 36,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tidak ada foto survey',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deskripsi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: darkBurgundy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF4A2A2E),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: lightBurgundy,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.location_on_outlined,
                          color: primaryColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Lokasi Survey',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: darkBurgundy,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasValidCoords) ...[
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(latitude!, longitude!),
                        initialZoom: 15,
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
                              point: LatLng(latitude, longitude),
                              width: 50,
                              height: 50,
                              child: const Icon(
                                Icons.location_on,
                                color: primaryColor,
                                size: 42,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: lightBurgundy,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.my_location,
                            color: primaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$latitude, $longitude',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                copyCoordinates(latitude, longitude),
                            icon: const Icon(
                              Icons.copy,
                              size: 16,
                              color: primaryColor,
                            ),
                            tooltip: 'Salin',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => openGoogleMaps(latitude, longitude),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text(
                          'Buka di Google Maps',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: lightBurgundy,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          color: Colors.grey.shade400,
                          size: 34,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lokasi tidak tersedia',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
