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
  // =========================================================
  // WARNA
  // =========================================================

  static const Color primaryColor = Color(0xFF7B1E3A);
  static const Color lightMaroon = Color(0xFFF7E7EB);
  static const Color backgroundColor = Color(0xFFF8F8F8);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color textColor = Color(0xFF172033);
  static const Color greyColor = Color(0xFF64748B);

  // =========================================================
  // VARIABLE
  // =========================================================

  Map<String, dynamic>? survey;

  bool isLoading = true;
  bool isLoadingImage = false;

  String? errorMessage;

  Uint8List? imageBytes;

  // =========================================================
  // LIFECYCLE
  // =========================================================

  @override
  void initState() {
    super.initState();

    fetchDetail();
  }

  // =========================================================
  // GET DETAIL SURVEY
  // =========================================================

  Future<void> fetchDetail() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
        imageBytes = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token') ?? '';

      // -------------------------------------------------------
      // TOKEN KOSONG
      // -------------------------------------------------------

      if (token.isEmpty) {
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );

        return;
      }

      // -------------------------------------------------------
      // URL API
      // -------------------------------------------------------

      final url = Uri.parse(
        'https://sijala.biz.id/api/v1/surveys/${widget.surveyId}',
      );

      debugPrint('====================================');
      debugPrint('DETAIL SURVEY');
      debugPrint('ID  : ${widget.surveyId}');
      debugPrint('URL : $url');
      debugPrint('====================================');

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('DETAIL SURVEY STATUS: ${response.statusCode}');

      debugPrint('DETAIL SURVEY RESPONSE: ${response.body}');

      // -------------------------------------------------------
      // TOKEN TIDAK VALID
      // -------------------------------------------------------

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

      // -------------------------------------------------------
      // BERHASIL
      // -------------------------------------------------------

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

          // ---------------------------------------------------
          // FOTO
          // ---------------------------------------------------

          final photo = data['photo']?.toString();

          if (photo != null &&
              photo.isNotEmpty &&
              photo != 'null' &&
              photo != 'placeholder.jpg') {
            fetchImage(photo, token);
          }

          return;
        }

        if (mounted) {
          setState(() {
            isLoading = false;

            errorMessage =
                result['message']?.toString() ?? 'Data survey tidak ditemukan.';
          });
        }

        return;
      }

      // -------------------------------------------------------
      // RESPONSE LAIN
      // -------------------------------------------------------

      if (mounted) {
        setState(() {
          isLoading = false;

          errorMessage =
              'Survey tidak ditemukan '
              '(Kode: ${response.statusCode})';
        });
      }
    } catch (e) {
      debugPrint('ERROR DETAIL SURVEY: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;

        errorMessage =
            'Gagal memuat detail survey.\n'
            'Periksa koneksi internet Anda.';
      });
    }
  }

  // =========================================================
  // GET FOTO SURVEY
  // =========================================================

  Future<void> fetchImage(String photoName, String token) async {
    if (!mounted) return;

    setState(() {
      isLoadingImage = true;
    });

    try {
      String fileName;

      if (photoName.contains('/')) {
        fileName = photoName.split('/').last;
      } else {
        fileName = photoName;
      }

      final url = Uri.parse('https://sijala.biz.id/api/image/$fileName');

      debugPrint('FOTO SURVEY URL: $url');

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('FOTO STATUS: ${response.statusCode}');

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (!mounted) return;

        setState(() {
          imageBytes = response.bodyBytes;
          isLoadingImage = false;
        });

        return;
      }
    } catch (e) {
      debugPrint('ERROR FOTO SURVEY: $e');
    }

    if (!mounted) return;

    setState(() {
      isLoadingImage = false;
    });
  }

  // =========================================================
  // DELETE SURVEY
  // =========================================================

  Future<void> deleteSurvey() async {
    // =======================================================
    // DIALOG KONFIRMASI
    // =======================================================

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),

          title: const Text(
            'Hapus Survey?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          content: const Text('Apakah kamu yakin ingin menghapus survey ini?'),

          actions: [
            // -------------------------------------------------
            // BATAL
            // -------------------------------------------------
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },

              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),

            // -------------------------------------------------
            // HAPUS
            // -------------------------------------------------
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

              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    // =======================================================
    // JIKA BATAL
    // =======================================================

    if (confirm != true) {
      return;
    }

    // =======================================================
    // TRY CATCH
    // =======================================================

    try {
      // -------------------------------------------------------
      // SHARED PREFERENCES
      // -------------------------------------------------------

      final prefs = await SharedPreferences.getInstance();

      // -------------------------------------------------------
      // TOKEN
      // -------------------------------------------------------

      final String token = prefs.getString('token') ?? '';

      // -------------------------------------------------------
      // CEK TOKEN
      // -------------------------------------------------------

      if (token.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Token tidak ditemukan. Silakan login kembali.'),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      // -------------------------------------------------------
      // URL DELETE
      // -------------------------------------------------------
      // INI YANG SUDAH DIBENERIN
      //
      // SEBELUM:
      // /surveys/{id}
      //
      // SEKARANG:
      // /surveys/{id}/delete
      // -------------------------------------------------------

      final url = Uri.parse(
        'https://sijala.biz.id/api/v1/surveys/${widget.surveyId}/delete',
      );

      debugPrint('====================================');
      debugPrint('DELETE SURVEY');
      debugPrint('SURVEY ID : ${widget.surveyId}');
      debugPrint('URL       : $url');
      debugPrint('METHOD    : POST');
      debugPrint('====================================');

      // -------------------------------------------------------
      // REQUEST POST
      // -------------------------------------------------------

      final response = await http.post(
        url,

        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },

        body: jsonEncode({}),
      );

      // -------------------------------------------------------
      // DEBUG RESPONSE
      // -------------------------------------------------------

      debugPrint('====================================');
      debugPrint('DELETE STATUS : ${response.statusCode}');
      debugPrint('DELETE BODY   : ${response.body}');
      debugPrint('====================================');

      // =======================================================
      // BERHASIL
      // =======================================================

      if (response.statusCode == 200 || response.statusCode == 204) {
        String message = 'Survey berhasil dihapus';

        // -----------------------------------------------------
        // BACA RESPONSE JSON JIKA ADA
        // -----------------------------------------------------

        if (response.body.isNotEmpty) {
          try {
            final result = jsonDecode(response.body);

            if (result is Map && result['message'] != null) {
              message = result['message'].toString();
            }
          } catch (e) {
            debugPrint('RESPONSE DELETE BUKAN JSON: $e');
          }
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );

        // -----------------------------------------------------
        // KEMBALI KE HALAMAN SURVEY
        // -----------------------------------------------------

        Navigator.pop(context, true);

        return;
      }

      // =======================================================
      // TOKEN TIDAK VALID
      // =======================================================

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

      // =======================================================
      // GAGAL
      // =======================================================

      String errorMessage = 'Gagal menghapus survey';

      // -------------------------------------------------------
      // AMBIL MESSAGE DARI API
      // -------------------------------------------------------

      if (response.body.isNotEmpty) {
        try {
          final result = jsonDecode(response.body);

          if (result is Map && result['message'] != null) {
            errorMessage = result['message'].toString();
          }
        } catch (e) {
          debugPrint('ERROR PARSE RESPONSE DELETE: $e');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$errorMessage '
            '(Kode: ${response.statusCode})',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // =======================================================
      // ERROR
      // =======================================================

      debugPrint('ERROR DELETE SURVEY: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan saat menghapus survey.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =========================================================
  // EDIT SURVEY
  // =========================================================

  Future<void> editSurvey() async {
    if (survey == null) {
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SurveyFormPage(survey: survey!)),
    );

    if (result == true && mounted) {
      fetchDetail();
    }
  }

  // =========================================================
  // GOOGLE MAPS
  // =========================================================

  Future<void> openGoogleMaps(double latitude, double longitude) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    try {
      final canOpen = await canLaunchUrl(url);

      if (canOpen) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka Google Maps.')),
        );
      }
    } catch (e) {
      debugPrint('GOOGLE MAP ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka Google Maps.')),
      );
    }
  }

  // =========================================================
  // COPY KOORDINAT
  // =========================================================

  void copyCoordinates(double latitude, double longitude) {
    Clipboard.setData(ClipboardData(text: '$latitude, $longitude'));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Koordinat berhasil disalin!'),
        backgroundColor: primaryColor,
      ),
    );
  }

  // =========================================================
  // FULL SCREEN FOTO
  // =========================================================

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
                    borderRadius: BorderRadius.circular(15),

                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),

              Positioned(
                top: 5,
                right: 5,

                child: IconButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },

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

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      // =====================================================
      // APP BAR
      // =====================================================
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,

        title: const Text(
          'Detail Survey',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: [
          // =================================================
          // EDIT
          // =================================================
          if (survey != null)
            IconButton(
              onPressed: editSurvey,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Survey',
            ),

          // =================================================
          // DELETE
          // =================================================
          if (survey != null)
            IconButton(
              onPressed: deleteSurvey,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus Survey',
            ),
        ],
      ),

      body: buildBody(),
    );
  }

  // =========================================================
  // BUILD BODY
  // =========================================================

  Widget buildBody() {
    // =======================================================
    // LOADING
    // =======================================================

    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            CircularProgressIndicator(color: primaryColor),

            SizedBox(height: 15),

            Text('Memuat detail survey...', style: TextStyle(color: greyColor)),
          ],
        ),
      );
    }

    // =======================================================
    // ERROR
    // =======================================================

    if (errorMessage != null || survey == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(25),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Container(
                padding: const EdgeInsets.all(18),

                decoration: const BoxDecoration(
                  color: lightMaroon,
                  shape: BoxShape.circle,
                ),

                child: const Icon(
                  Icons.error_outline,
                  color: primaryColor,
                  size: 50,
                ),
              ),

              const SizedBox(height: 18),

              Text(
                errorMessage ?? 'Data survey tidak ditemukan.',

                textAlign: TextAlign.center,

                style: const TextStyle(
                  fontSize: 15,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: fetchDetail,

                icon: const Icon(Icons.refresh),

                label: const Text('Coba Lagi'),

                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,

                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // =======================================================
    // DATA SURVEY
    // =======================================================

    final String title =
        survey!['title']?.toString() ?? survey!['name']?.toString() ?? '-';

    final String description = survey!['description']?.toString() ?? '-';

    final String category =
        survey!['category_name']?.toString() ??
        survey!['category']?['name']?.toString() ??
        'Tanpa Kategori';

    final String createdAt =
        survey!['created_at']?.toString() ??
        survey!['createdAt']?.toString() ??
        '-';

    // =======================================================
    // LATITUDE
    // =======================================================

    final double? latitude = double.tryParse(
      survey!['latitude']?.toString() ?? '',
    );

    // =======================================================
    // LONGITUDE
    // =======================================================

    final double? longitude = double.tryParse(
      survey!['longitude']?.toString() ?? '',
    );

    // =======================================================
    // CEK KOORDINAT
    // =======================================================

    final bool hasValidCoords = latitude != null && longitude != null;

    return RefreshIndicator(
      color: primaryColor,

      onRefresh: fetchDetail,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.all(16),

        children: [
          // =================================================
          // KARTU INFORMASI SURVEY
          // =================================================
          Card(
            elevation: 0,

            color: Colors.white,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),

              side: const BorderSide(color: borderColor),
            ),

            child: Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // CATEGORY
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: lightMaroon,

                      borderRadius: BorderRadius.circular(7),
                    ),

                    child: Text(
                      category,

                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // TITLE
                  Text(
                    title,

                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // DATE
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 15, color: greyColor),

                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          createdAt,

                          style: const TextStyle(
                            fontSize: 12,
                            color: greyColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // =================================================
          // KARTU FOTO
          // =================================================
          Card(
            elevation: 0,

            color: Colors.white,

            clipBehavior: Clip.antiAlias,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),

              side: const BorderSide(color: borderColor),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 10),

                  child: Text(
                    'Foto Survey',

                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),

                // FOTO LOADING
                if (isLoadingImage)
                  const SizedBox(
                    height: 200,

                    child: Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  )
                // FOTO ADA
                else if (imageBytes != null)
                  GestureDetector(
                    onTap: () {
                      showFullImageDialog(imageBytes!);
                    },

                    child: Image.memory(
                      imageBytes!,

                      width: double.infinity,

                      height: 220,

                      fit: BoxFit.cover,
                    ),
                  )
                // FOTO TIDAK ADA
                else
                  Container(
                    width: double.infinity,

                    height: 140,

                    color: const Color(0xFFF1F5F9),

                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          size: 40,
                          color: Color(0xFF94A3B8),
                        ),

                        SizedBox(height: 8),

                        Text(
                          'Tidak ada foto survey',

                          style: TextStyle(color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // =================================================
          // KARTU DESKRIPSI
          // =================================================
          Card(
            elevation: 0,

            color: Colors.white,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),

              side: const BorderSide(color: borderColor),
            ),

            child: Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Deskripsi',

                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    description,

                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF334155),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // =================================================
          // KARTU LOKASI
          // =================================================
          Card(
            elevation: 0,

            color: Colors.white,

            clipBehavior: Clip.antiAlias,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),

              side: const BorderSide(color: borderColor),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // HEADER LOKASI
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),

                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),

                        decoration: BoxDecoration(
                          color: lightMaroon,

                          borderRadius: BorderRadius.circular(10),
                        ),

                        child: const Icon(
                          Icons.location_on_outlined,

                          color: primaryColor,

                          size: 20,
                        ),
                      ),

                      const SizedBox(width: 10),

                      const Text(
                        'Lokasi Survey',

                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // =================================================
                // JIKA KOORDINAT ADA
                // =================================================
                if (hasValidCoords) ...[
                  SizedBox(
                    height: 210,

                    width: double.infinity,

                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(latitude!, longitude!),

                        initialZoom: 15.0,
                      ),

                      children: [
                        // OPEN STREET MAP
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                          userAgentPackageName: 'com.example.field_survey',
                        ),

                        // MARKER
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(latitude!, longitude!),

                              width: 50,

                              height: 50,

                              child: const Icon(
                                Icons.location_on,

                                color: primaryColor,

                                size: 45,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // =================================================
                  // KOORDINAT
                  // =================================================
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 5),

                    child: Container(
                      width: double.infinity,

                      padding: const EdgeInsets.all(12),

                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),

                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: Row(
                        children: [
                          const Icon(
                            Icons.my_location,

                            color: primaryColor,

                            size: 18,
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: Text(
                              '$latitude, $longitude',

                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ),

                          IconButton(
                            onPressed: () {
                              copyCoordinates(latitude!, longitude!);
                            },

                            icon: const Icon(
                              Icons.copy,

                              size: 18,

                              color: primaryColor,
                            ),

                            tooltip: 'Salin koordinat',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // =================================================
                  // BUTTON GOOGLE MAPS
                  // =================================================
                  Padding(
                    padding: const EdgeInsets.all(12),

                    child: SizedBox(
                      width: double.infinity,

                      height: 45,

                      child: ElevatedButton.icon(
                        onPressed: () {
                          openGoogleMaps(latitude!, longitude!);
                        },

                        icon: const Icon(Icons.map_outlined, size: 19),

                        label: const Text('Buka di Google Maps'),

                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,

                          foregroundColor: Colors.white,

                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]
                // =================================================
                // KOORDINAT TIDAK ADA
                // =================================================
                else
                  Container(
                    height: 130,

                    width: double.infinity,

                    color: const Color(0xFFF8FAFC),

                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Icon(
                          Icons.location_off_outlined,

                          color: Color(0xFF94A3B8),

                          size: 38,
                        ),

                        SizedBox(height: 8),

                        Text(
                          'Lokasi tidak tersedia',

                          style: TextStyle(
                            color: Color(0xFF64748B),

                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 25),
        ],
      ),
    );
  }
}
