import 'dart:convert';

import 'package:field_survey/screens/survey/SurveyFormPage.dart';
import 'package:field_survey/screens/survey/survey_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:field_survey/routes/app_routes.dart';
import 'package:field_survey/screens/auth/login.dart';

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  // =========================================================
  // 1. STATE & VARIABLE HALAMAN
  // =========================================================

  // Menyimpan data survey yang berhasil diambil dari API
  List<Map<String, dynamic>> surveys = [];

  // Menandakan sedang loading saat mengambil data dari server
  bool isLoading = true;

  // Menyimpan pesan error jika gagal terhubung ke server
  String? errorMessage;

  // Endpoint API untuk mengambil daftar survey
  final String apiUrl = 'https://sijala.biz.id/api/v1/surveys';

  // Warna utama aplikasi
  static const Color primaryColor = Color(0xFF7B1E3A);

  // =========================================================
  // 2. LIFECYCLE
  // =========================================================

  @override
  void initState() {
    super.initState();

    // Ambil data survey ketika halaman pertama dibuka
    fetchSurveys();
  }

  // =========================================================
  // 3. REST API - MENGAMBIL DAFTAR SURVEY
  // =========================================================

  Future<void> fetchSurveys() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Mengambil token dari SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // Jika token kosong, pengguna harus login kembali
      if (token.isEmpty) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );

        return;
      }

      // Request GET ke API
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Jika token sudah tidak valid / expired
      if (response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );

        return;
      }

      // Jika request berhasil
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Mengecek status dari API
        if (data['status'] == true && data['data'] is List) {
          final List<dynamic> listData = data['data'];

          setState(() {
            surveys = listData
                .map<Map<String, dynamic>>(
                  (item) => Map<String, dynamic>.from(item),
                )
                .toList();

            isLoading = false;
          });

          return;
        }

        // Jika data kosong
        setState(() {
          surveys = [];
          isLoading = false;
        });

        return;
      }

      // Jika response bukan 200
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal mengambil data survey.';
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Tidak dapat terhubung ke server. Periksa koneksi Anda.';
      });
    }
  }

  // =========================================================
  // 4. NAVIGASI DETAIL SURVEY
  // =========================================================

  Future<void> openSurveyDetail(Map<String, dynamic> survey) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SurveyDetailPage(surveyId: survey['id']),
      ),
    );

    // Jika kembali dari halaman detail
    // dan ada perubahan data survey
    if (result == true && mounted) {
      fetchSurveys();
    }
  }

  // =========================================================
  // 5. NAVIGASI FORM TAMBAH SURVEY
  // =========================================================

  Future<void> openSurveyForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SurveyFormPage()),
    );

    // Jika berhasil menambahkan survey,
    // ambil ulang data dari API
    if (result == true && mounted) {
      fetchSurveys();
    }
  }

  // =========================================================
  // 6. HELPER FORMAT DATA
  // =========================================================

  String getSurveyCategory(Map<String, dynamic> survey) {
    if (survey['category'] != null &&
        survey['category'].toString().isNotEmpty) {
      return survey['category'].toString();
    }

    if (survey['survey'] is Map && survey['survey']['category'] != null) {
      return survey['survey']['category'].toString();
    }

    return 'Tipe Survey';
  }

  String formatDate(dynamic date) {
    if (date == null || date.toString().isEmpty) {
      return '-';
    }

    try {
      final parsed = DateTime.parse(date.toString());

      return '${parsed.day.toString().padLeft(2, '0')}/'
          '${parsed.month.toString().padLeft(2, '0')}/'
          '${parsed.year}';
    } catch (e) {
      return date.toString();
    }
  }

  // =========================================================
  // 7. BUILD TAMPILAN
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),

      // =====================================================
      // APP BAR
      // =====================================================
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,

        title: const Text(
          'Survey',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),

        centerTitle: false,

        actions: [
          IconButton(
            onPressed: fetchSurveys,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),

      // =====================================================
      // BODY
      // =====================================================
      body: RefreshIndicator(
        color: primaryColor,

        onRefresh: fetchSurveys,

        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryColor),
              )
            : errorMessage != null
            ? _buildErrorState()
            : surveys.isEmpty
            ? _buildEmptyState()
            : _buildSurveyList(),
      ),

      // =====================================================
      // FLOATING ACTION BUTTON
      // =====================================================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openSurveyForm,

        backgroundColor: primaryColor,

        icon: const Icon(Icons.add, color: Colors.white),

        label: const Text(
          'Tambah Survey',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // =========================================================
  // 8. TAMPILAN LIST SURVEY
  // =========================================================

  Widget _buildSurveyList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),

      itemCount: surveys.length,

      itemBuilder: (context, index) {
        final survey = surveys[index];

        final String title =
            survey['title']?.toString() ??
            survey['name']?.toString() ??
            'Survey';

        final String description = survey['description']?.toString() ?? '';

        final String category = getSurveyCategory(survey);

        final String date = formatDate(
          survey['created_at'] ?? survey['createdAt'],
        );

        return GestureDetector(
          onTap: () {
            openSurveyDetail(survey);
          },

          child: Card(
            elevation: 4,

            shadowColor: Colors.black12,

            margin: const EdgeInsets.only(bottom: 15),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),

            child: Padding(
              padding: const EdgeInsets.all(18),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // =================================================
                  // HEADER CARD
                  // =================================================
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,

                        backgroundColor: const Color(0xFFF7E7EB),

                        child: const Icon(
                          Icons.assignment_outlined,
                          color: primaryColor,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Text(
                          title,

                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // =================================================
                  // CATEGORY
                  // =================================================
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: const Color(0xFFF7E7EB),

                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Text(
                      category,

                      style: const TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // =================================================
                  // DESCRIPTION
                  // =================================================
                  if (description.isNotEmpty)
                    Text(
                      description,

                      maxLines: 2,

                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),

                  const SizedBox(height: 12),

                  // =================================================
                  // DATE
                  // =================================================
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: primaryColor,
                      ),

                      const SizedBox(width: 7),

                      Text(
                        date,

                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // 9. KONDISI ERROR
  // =========================================================

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Container(
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: const Color(0xFFF7E7EB),

                shape: BoxShape.circle,
              ),

              child: const Icon(Icons.wifi_off, size: 45, color: primaryColor),
            ),

            const SizedBox(height: 20),

            const Text(
              'Gagal Memuat Data',

              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(
              errorMessage ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,

              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed: fetchSurveys,

              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,

                foregroundColor: Colors.white,

                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              icon: const Icon(Icons.refresh),

              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // 10. KONDISI DATA KOSONG
  // =========================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Container(
              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(
                color: const Color(0xFFF7E7EB),

                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.assignment_outlined,
                size: 50,
                color: primaryColor,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Belum Ada Data Survey',

              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              'Belum ada survey yang tersedia saat ini.',

              textAlign: TextAlign.center,

              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed: openSurveyForm,

              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,

                foregroundColor: Colors.white,

                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              icon: const Icon(Icons.add),

              label: const Text('Tambah Survey'),
            ),
          ],
        ),
      ),
    );
  }
}
