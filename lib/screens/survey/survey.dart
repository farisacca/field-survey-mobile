
import 'dart:convert';

import 'package:field_survey/screens/survey/SurveyFormPage.dart';
import 'package:field_survey/screens/survey/survey_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color lightBlue = Color(0xFFE3F0FF);
  static const Color backgroundColor = Color(0xFFF5F9FF);
  static const Color borderColor = Color(0xFFDCE6F1);
  static const Color textColor = Color(0xFF172033);
  static const Color greyColor = Color(0xFF64748B);

  List<Map<String, dynamic>> surveys = [];

  bool isLoading = true;
  String? errorMessage;

  final String apiUrl = 'https://sijala.biz.id/api/v1/surveys';

  @override
  void initState() {
    super.initState();
    fetchSurveys();
  }

  
  Future<void> fetchSurveys() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
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

      final response = await http.get(
        Uri.parse(apiUrl),
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
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == true && data['data'] is List) {
          final List<dynamic> listData = data['data'];

          if (!mounted) return;

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

        if (!mounted) return;

        setState(() {
          surveys = [];
          isLoading = false;
        });

        return;
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Gagal mengambil data survey.';
      });
    } catch (e) {
      debugPrint('ERROR FETCH SURVEY: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Tidak dapat terhubung ke server. Periksa koneksi Anda.';
      });
    }
  }

  // DETAIL SURVEY
  Future<void> openSurveyDetail(Map<String, dynamic> survey) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SurveyDetailPage(
          surveyId: survey['id'],
        ),
      ),
    );

    if (result == true && mounted) {
      fetchSurveys();
    }
  }

  // TAMBAH SURVEY
  Future<void> openSurveyForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SurveyFormPage(),
      ),
    );

    if (result == true && mounted) {
      fetchSurveys();
    }
  }

  // KATEGORI SURVEY
  String getSurveyCategory(Map<String, dynamic> survey) {
    if (survey['category'] != null &&
        survey['category'].toString().isNotEmpty) {
      return survey['category'].toString();
    }

    if (survey['survey'] is Map &&
        survey['survey']['category'] != null) {
      return survey['survey']['category'].toString();
    }

    return 'Tipe Survey';
  }

  // FORMAT TANGGAL
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      // APP BAR
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali ke Dashboard',
          onPressed: () {
            context.go(AppRoutes.dashboard);
          },
        ),

        title: const Text(
          'Survey',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Tombol refresh sengaja dihilangkan.
      ),

      // BODY
      body: RefreshIndicator(
        color: primaryColor,
        backgroundColor: Colors.white,
        onRefresh: fetchSurveys,
        child: _buildBody(),
      ),

      // TOMBOL TAMBAH
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openSurveyForm,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add),
        label: const Text(
          'Tambah Survey',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ISI BODY
  Widget _buildBody() {
    if (isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(
            child: CircularProgressIndicator(
              color: primaryColor,
            ),
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              'Memuat data survey...',
              style: TextStyle(color: greyColor),
            ),
          ),
        ],
      );
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    if (surveys.isEmpty) {
      return _buildEmptyState();
    }

    return _buildSurveyList();
  }

  // DAFTAR SURVEY
  Widget _buildSurveyList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
      itemCount: surveys.length,
      itemBuilder: (context, index) {
        final survey = surveys[index];

        final String title =
            survey['title']?.toString() ??
            survey['name']?.toString() ??
            'Survey';

        final String description =
            survey['description']?.toString() ?? '';

        final String category = getSurveyCategory(survey);

        final String date = formatDate(
          survey['created_at'] ?? survey['createdAt'],
        );

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 14),
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: borderColor),
          ),
          child: InkWell(
            onTap: () => openSurveyDetail(survey),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: lightBlue,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.assignment_outlined,
                          color: primaryColor,
                          size: 25,
                        ),
                      ),

                      const SizedBox(width: 13),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: primaryColor,
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // KATEGORI
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: lightBlue,
                      borderRadius: BorderRadius.circular(8),
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

                  // DESKRIPSI
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: greyColor,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  const Divider(height: 1, color: borderColor),
                  const SizedBox(height: 12),

                  // TANGGAL
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_today_outlined,
                          size: 15,
                          color: primaryColor,
                        ),
                      ),

                      const SizedBox(width: 9),

                      const Text(
                        'Dibuat pada',
                        style: TextStyle(
                          fontSize: 12,
                          color: greyColor,
                        ),
                      ),

                      const Spacer(),

                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textColor,
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

  // KONDISI ERROR
  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(25),
      children: [
        const SizedBox(height: 120),

        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 45,
              color: primaryColor,
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Center(
          child: Text(
            'Gagal Memuat Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),

        const SizedBox(height: 10),

        Text(
          errorMessage ?? 'Terjadi kesalahan.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: greyColor,
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Tarik layar ke bawah untuk mencoba kembali.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: primaryColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // KONDISI DATA KOSONG
  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(25),
      children: [
        const SizedBox(height: 100),

        Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: lightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              size: 50,
              color: primaryColor,
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Center(
          child: Text(
            'Belum Ada Data Survey',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          'Belum ada survey yang tersedia saat ini. '
          'Silakan tambahkan survey baru.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: greyColor,
            fontSize: 13,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 22),

        Center(
          child: ElevatedButton.icon(
            onPressed: openSurveyForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Survey'),
          ),
        ),
      ],
    );
  }
}
